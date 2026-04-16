-- ============================================================================
--  Multi-Tiered Micro-Lending Platform
--  triggers.sql  |  Group ID: 13  |  PostgreSQL 16
--  Run AFTER schema.sql
-- ============================================================================
--
--  Trigger index (in firing order by table / event)
--  ─────────────────────────────────────────────────
--
--  ON loans (INSERT)
--   [T01]  trg_enforce_kyc_borrower          BEFORE  — KYC = VERIFIED gate
--   [T02]  trg_enforce_cooling_off_borrower  BEFORE  — 48-h cooldown check
--   [T03]  trg_set_borrower_role             AFTER   — NEUTRAL → BORROWER
--
--  ON loans (UPDATE)
--   [T04]  trg_handle_loan_status_change     AFTER   — drives role transitions
--                                                       and cooling-off on COMPLETED/CANCELLED
--
--  ON loan_contributions (INSERT)
--   [T05]  trg_enforce_kyc_lender            BEFORE  — KYC = VERIFIED gate
--   [T06]  trg_enforce_cooling_off_lender    BEFORE  — cooldown / BORROWER block
--   [T07]  trg_enforce_no_self_funding       BEFORE  — lender ≠ borrower
--   [T08]  trg_enforce_wallet_balance        BEFORE  — balance ≥ pledged_amount
--   [T09]  trg_enforce_max_exposure          BEFORE  — 50 % single-lender cap
--   [T10]  trg_enforce_max_positions         BEFORE  — max 3 concurrent positions
--   [T11]  trg_set_lender_role               AFTER   — NEUTRAL → LENDER
--   [T12]  trg_sync_loan_funded_amount       AFTER   — recalculate loans.funded_amount
--
--  ON loan_contributions (UPDATE)
--   [T13]  trg_enforce_retraction_window     BEFORE  — 24-h window + ESCROWED check
--   [T14]  trg_enforce_max_exposure          BEFORE  — re-check cap on pledge top-up
--   [T15]  trg_sync_loan_funded_amount       AFTER   — recalculate on retraction
--   [T16]  trg_check_lender_completion       AFTER   — LENDER → NEUTRAL when done
--
--  ON repayment_schedule (UPDATE)
--   [T17]  trg_update_credit_score           AFTER   — ±score on PAID / OVERDUE
--
--  ON escrow_ledger (UPDATE)
--   [T18]  trg_escrow_immutable_after_release BEFORE — block edits once RELEASED
--
--  ON wallet_transactions (UPDATE / DELETE)
--   [T19]  trg_wallet_immutable              BEFORE  — append-only ledger guard
--
--  ON audit_log (UPDATE / DELETE)
--   [T20]  trg_audit_log_immutable           BEFORE  — tamper-proof guard
--
--  Audit capture (AFTER INSERT / UPDATE / DELETE)
--   [T21]  trg_audit_users
--   [T22]  trg_audit_loans
--   [T23]  trg_audit_loan_contributions
--   [T24]  trg_audit_escrow_ledger
-- ============================================================================


-- ============================================================================
--  SHARED AUDIT HELPER
--  Single generic function reused by all four audit triggers.
--  Reads the application-set session variable app.current_user_id so every
--  audit row knows which user initiated the change.
--  Application must run:  SET LOCAL app.current_user_id = '<uuid>';
--  at the start of every transaction before modifying audited tables.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_audit_row()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_record_id   UUID;
    v_changed_by  UUID;
BEGIN
    -- Resolve calling user from session variable (NULL-safe)
    BEGIN
        v_changed_by := current_setting('app.current_user_id', true)::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_changed_by := NULL;
    END;

    IF TG_OP = 'INSERT' THEN
        v_record_id := NEW.id;
        INSERT INTO audit_log
            (table_name, record_id, operation, changed_by, old_data, new_data)
        VALUES
            (TG_TABLE_NAME, v_record_id, 'INSERT',
             v_changed_by, NULL, row_to_json(NEW)::JSONB);
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        v_record_id := NEW.id;
        INSERT INTO audit_log
            (table_name, record_id, operation, changed_by, old_data, new_data)
        VALUES
            (TG_TABLE_NAME, v_record_id, 'UPDATE',
             v_changed_by,
             row_to_json(OLD)::JSONB,
             row_to_json(NEW)::JSONB);
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        v_record_id := OLD.id;
        INSERT INTO audit_log
            (table_name, record_id, operation, changed_by, old_data, new_data)
        VALUES
            (TG_TABLE_NAME, v_record_id, 'DELETE',
             v_changed_by, row_to_json(OLD)::JSONB, NULL);
        RETURN OLD;
    END IF;
END;
$$;


-- ============================================================================
--  [T01]  ENFORCE KYC — BORROWER
--  Fires: BEFORE INSERT on loans
--  Blocks loan creation unless the borrower's KYC is VERIFIED.
--  SUSPENDED users are also blocked (kyc_status != 'VERIFIED' covers both).
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_enforce_kyc_borrower()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_kyc   VARCHAR(12);
BEGIN
    SELECT kyc_status INTO v_kyc
      FROM users
     WHERE id = NEW.borrower_id;

    IF v_kyc IS DISTINCT FROM 'VERIFIED' THEN
        RAISE EXCEPTION
            '[T01] Loan creation blocked: borrower KYC status is "%" — must be VERIFIED.',
            COALESCE(v_kyc, 'UNKNOWN')
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_kyc_borrower
    BEFORE INSERT ON loans
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_kyc_borrower();


-- ============================================================================
--  [T02]  ENFORCE COOLING-OFF PERIOD — BORROWER
--  Fires: BEFORE INSERT on loans
--  Blocks loan creation if:
--    a) user is not currently NEUTRAL (already BORROWER or LENDER), or
--    b) user's cooling_off_until is in the future (48-h post-repayment window)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_enforce_cooling_off_borrower()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_role          VARCHAR(10);
    v_cooling_until TIMESTAMPTZ;
BEGIN
    SELECT role_state, cooling_off_until
      INTO v_role, v_cooling_until
      FROM users
     WHERE id = NEW.borrower_id;

    IF v_role <> 'NEUTRAL' THEN
        RAISE EXCEPTION
            '[T02] Loan creation blocked: user role is "%" — must be NEUTRAL to open a loan.',
            v_role
            USING ERRCODE = 'P0001';
    END IF;

    IF v_cooling_until IS NOT NULL AND v_cooling_until > NOW() THEN
        RAISE EXCEPTION
            '[T02] Loan creation blocked: cooling-off period active until %.',
            v_cooling_until
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_cooling_off_borrower
    BEFORE INSERT ON loans
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_cooling_off_borrower();


-- ============================================================================
--  [T03]  SET BORROWER ROLE
--  Fires: AFTER INSERT on loans
--  Transitions the borrower from NEUTRAL → BORROWER once a loan row exists.
--  Clears any expired cooling_off_until at the same time.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_set_borrower_role()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE users
       SET role_state        = 'BORROWER',
           cooling_off_until = NULL
     WHERE id = NEW.borrower_id;

    RETURN NULL;  -- AFTER trigger; return value ignored
END;
$$;

CREATE TRIGGER trg_set_borrower_role
    AFTER INSERT ON loans
    FOR EACH ROW EXECUTE FUNCTION fn_set_borrower_role();


-- ============================================================================
--  [T04]  HANDLE LOAN STATUS TRANSITIONS
--  Fires: AFTER UPDATE on loans
--  Manages two exit paths from the loan lifecycle:
--
--  COMPLETED → NEUTRAL + 48-h cooling-off on the borrower
--    The borrower has fully repaid; they must wait 48 hours before they can
--    open another loan or pledge funds as a lender.
--
--  CANCELLED → NEUTRAL (no cooling-off) on the borrower
--    The loan was rejected or failed the funding threshold; the borrower is
--    immediately free to apply again.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_handle_loan_status_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Guard: only act when status actually changed
    IF NEW.status = OLD.status THEN
        RETURN NULL;
    END IF;

    -- ── Path 1: loan fully repaid ─────────────────────────────────────────────
    IF NEW.status = 'COMPLETED' THEN
        UPDATE users
           SET role_state        = 'NEUTRAL',
               cooling_off_until = NOW() + INTERVAL '48 hours'
         WHERE id = NEW.borrower_id
           AND role_state = 'BORROWER';
        RETURN NULL;
    END IF;

    -- ── Path 2: loan cancelled (admin rejection or threshold failure) ─────────
    IF NEW.status = 'CANCELLED' THEN
        UPDATE users
           SET role_state        = 'NEUTRAL',
               cooling_off_until = NULL
         WHERE id = NEW.borrower_id
           AND role_state = 'BORROWER';
        RETURN NULL;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_handle_loan_status_change
    AFTER UPDATE ON loans
    FOR EACH ROW EXECUTE FUNCTION fn_handle_loan_status_change();


-- ============================================================================
--  [T05]  ENFORCE KYC — LENDER
--  Fires: BEFORE INSERT on loan_contributions
--  Blocks pledging unless lender's KYC status is VERIFIED.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_enforce_kyc_lender()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_kyc VARCHAR(12);
BEGIN
    SELECT kyc_status INTO v_kyc
      FROM users
     WHERE id = NEW.lender_id;

    IF v_kyc IS DISTINCT FROM 'VERIFIED' THEN
        RAISE EXCEPTION
            '[T05] Pledge blocked: lender KYC status is "%" — must be VERIFIED.',
            COALESCE(v_kyc, 'UNKNOWN')
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_kyc_lender
    BEFORE INSERT ON loan_contributions
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_kyc_lender();


-- ============================================================================
--  [T06]  ENFORCE COOLING-OFF PERIOD — LENDER
--  Fires: BEFORE INSERT on loan_contributions
--  Blocks pledging if:
--    a) user's role is BORROWER (active loan pending repayment), or
--    b) user is in a cooling-off period (recently repaid as borrower)
--
--  A LENDER (funding multiple loans) or NEUTRAL user may pledge freely
--  subject to the position cap checked in [T10].
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_enforce_cooling_off_lender()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_role          VARCHAR(10);
    v_cooling_until TIMESTAMPTZ;
BEGIN
    SELECT role_state, cooling_off_until
      INTO v_role, v_cooling_until
      FROM users
     WHERE id = NEW.lender_id;

    -- Active borrowers cannot simultaneously lend
    IF v_role = 'BORROWER' THEN
        RAISE EXCEPTION
            '[T06] Pledge blocked: user is currently an active BORROWER and cannot lend simultaneously.'
            USING ERRCODE = 'P0001';
    END IF;

    -- Cooling-off period gate
    IF v_cooling_until IS NOT NULL AND v_cooling_until > NOW() THEN
        RAISE EXCEPTION
            '[T06] Pledge blocked: cooling-off period active until %. '
            'Please wait before participating as a lender.',
            v_cooling_until
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_cooling_off_lender
    BEFORE INSERT ON loan_contributions
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_cooling_off_lender();


-- ============================================================================
--  [T07]  ENFORCE NO SELF-FUNDING
--  Fires: BEFORE INSERT on loan_contributions
--  A user cannot fund their own loan — prevents circular money movement.
--  (Cannot be a column CHECK because it requires joining to loans.)
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_enforce_no_self_funding()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_borrower UUID;
BEGIN
    SELECT borrower_id INTO v_borrower
      FROM loans
     WHERE id = NEW.loan_id;

    IF v_borrower = NEW.lender_id THEN
        RAISE EXCEPTION
            '[T07] Pledge blocked: a borrower cannot fund their own loan.'
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_no_self_funding
    BEFORE INSERT ON loan_contributions
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_no_self_funding();


-- ============================================================================
--  [T08]  ENFORCE WALLET BALANCE SUFFICIENCY
--  Fires: BEFORE INSERT on loan_contributions
--  The lender must have enough wallet balance to cover their pledge.
--  Note: the actual debit (wallet_balance UPDATE + escrow INSERT + wallet_transaction
--  INSERT) is performed atomically by proc_pledge_funds() in procedures.sql.
--  This trigger is a pre-flight guard only.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_enforce_wallet_balance()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_balance NUMERIC(15, 2);
BEGIN
    SELECT wallet_balance INTO v_balance
      FROM users
     WHERE id = NEW.lender_id;

    IF v_balance < NEW.pledged_amount THEN
        RAISE EXCEPTION
            '[T08] Pledge blocked: wallet balance (%) is insufficient for pledge amount (%).',
            v_balance, NEW.pledged_amount
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_wallet_balance
    BEFORE INSERT ON loan_contributions
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_wallet_balance();


-- ============================================================================
--  [T09]  ENFORCE MAXIMUM LENDER EXPOSURE  (50 % cap)
--  Fires: BEFORE INSERT and BEFORE UPDATE on loan_contributions
--
--  On INSERT : checks that NEW.pledged_amount ≤ loan.max_lender_pct %
--              of loan.requested_amount.
--  On UPDATE : re-checks in case a top-up pushes the lender over the cap.
--              The existing row is being replaced, so only NEW.pledged_amount
--              needs to be validated (UNIQUE constraint ensures one row per
--              lender-loan pair).
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_enforce_max_exposure()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_requested   NUMERIC(15, 2);
    v_max_pct     NUMERIC(5, 2);
    v_max_allowed NUMERIC(15, 2);
    v_loan_status VARCHAR(14);
BEGIN
    SELECT requested_amount, max_lender_pct, status
      INTO v_requested, v_max_pct, v_loan_status
      FROM loans
     WHERE id = NEW.loan_id;

    -- Only enforce while the loan is still open for funding
    IF v_loan_status NOT IN ('OPEN', 'UNDER_REVIEW') THEN
        RETURN NEW;
    END IF;

    v_max_allowed := ROUND(v_requested * v_max_pct / 100.0, 2);

    IF NEW.pledged_amount > v_max_allowed THEN
        RAISE EXCEPTION
            '[T09] Pledge blocked: amount (%) exceeds the %.0%% single-lender cap '
            'of % for this loan.',
            NEW.pledged_amount, v_max_pct, v_max_allowed
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_max_exposure_insert
    BEFORE INSERT ON loan_contributions
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_max_exposure();

CREATE TRIGGER trg_enforce_max_exposure_update
    BEFORE UPDATE ON loan_contributions
    FOR EACH ROW
    WHEN (NEW.pledged_amount IS DISTINCT FROM OLD.pledged_amount)
    EXECUTE FUNCTION fn_enforce_max_exposure();


-- ============================================================================
--  [T10]  ENFORCE MAXIMUM CONCURRENT LENDING POSITIONS  (3-position cap)
--  Fires: BEFORE INSERT on loan_contributions
--  Counts the lender's currently active positions (ESCROWED or DISBURSED).
--  A new pledge is rejected if the count is already 3.
--  This uses the partial index idx_contributions_active for performance.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_enforce_max_positions()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_active_count INT;
BEGIN
    SELECT COUNT(*) INTO v_active_count
      FROM loan_contributions
     WHERE lender_id = NEW.lender_id
       AND status IN ('ESCROWED', 'DISBURSED');

    IF v_active_count >= 3 THEN
        RAISE EXCEPTION
            '[T10] Pledge blocked: lender already holds % concurrent active '
            'lending positions (maximum is 3). '
            'Wait for existing loans to complete before pledging further.',
            v_active_count
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_max_positions
    BEFORE INSERT ON loan_contributions
    FOR EACH ROW EXECUTE FUNCTION fn_enforce_max_positions();


-- ============================================================================
--  [T11]  SET LENDER ROLE
--  Fires: AFTER INSERT on loan_contributions
--  If the user is currently NEUTRAL, transitions them to LENDER.
--  If already LENDER (funding a second or third loan), this is a no-op.
--  Clears any expired cooling_off_until.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_set_lender_role()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    UPDATE users
       SET role_state        = 'LENDER',
           cooling_off_until = NULL
     WHERE id = NEW.lender_id
       AND role_state = 'NEUTRAL';
    -- WHERE clause is intentional: LENDER stays LENDER; no double-transition

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_set_lender_role
    AFTER INSERT ON loan_contributions
    FOR EACH ROW EXECUTE FUNCTION fn_set_lender_role();


-- ============================================================================
--  [T12]  SYNC LOAN FUNDED AMOUNT
--  Fires: AFTER INSERT and AFTER UPDATE on loan_contributions
--
--  Recomputes loans.funded_amount as the SUM of all ESCROWED and DISBURSED
--  contributions for the loan.  This keeps funded_amount always consistent
--  regardless of whether a pledge was added, topped up, or retracted.
--
--  Design note: funded_amount is a derived value stored for query performance.
--  This trigger is the single authoritative updater — no other code should
--  write loans.funded_amount directly.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_sync_loan_funded_amount()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_loan_id UUID;
    v_new_funded NUMERIC(15, 2);
BEGIN
    v_loan_id := COALESCE(NEW.loan_id, OLD.loan_id);

    SELECT COALESCE(SUM(pledged_amount), 0.00)
      INTO v_new_funded
      FROM loan_contributions
     WHERE loan_id = v_loan_id
       AND status IN ('ESCROWED', 'DISBURSED');

    UPDATE loans
       SET funded_amount = v_new_funded
     WHERE id = v_loan_id;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_sync_loan_funded_amount_insert
    AFTER INSERT ON loan_contributions
    FOR EACH ROW EXECUTE FUNCTION fn_sync_loan_funded_amount();

CREATE TRIGGER trg_sync_loan_funded_amount_update
    AFTER UPDATE ON loan_contributions
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status
       OR NEW.pledged_amount IS DISTINCT FROM OLD.pledged_amount)
    EXECUTE FUNCTION fn_sync_loan_funded_amount();


-- ============================================================================
--  [T13]  ENFORCE PLEDGE RETRACTION WINDOW
--  Fires: BEFORE UPDATE on loan_contributions
--  A lender may retract their pledge (set status = 'RETRACTED') only if:
--    a) The current status is 'ESCROWED' (funds not yet disbursed), AND
--    b) The pledge was made within the last 24 hours
--       (NOW() ≤ created_at + INTERVAL '24 hours')
--
--  Retractions after the window or on DISBURSED contributions are blocked.
--  The actual escrow release and wallet credit are performed by
--  proc_retract_pledge() in procedures.sql; this trigger validates preconditions.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_enforce_retraction_window()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- Only apply when the intent is to retract
    IF NEW.status <> 'RETRACTED' OR OLD.status = 'RETRACTED' THEN
        RETURN NEW;
    END IF;

    -- Must still be in ESCROWED state
    IF OLD.status <> 'ESCROWED' THEN
        RAISE EXCEPTION
            '[T13] Retraction blocked: contribution status is "%" — '
            'only ESCROWED pledges can be retracted.',
            OLD.status
            USING ERRCODE = 'P0001';
    END IF;

    -- Must be within the 24-hour window
    IF NOW() > OLD.created_at + INTERVAL '24 hours' THEN
        RAISE EXCEPTION
            '[T13] Retraction blocked: the 24-hour retraction window expired at %. '
            'Your pledge is now locked until loan resolution.',
            (OLD.created_at + INTERVAL '24 hours')::TIMESTAMPTZ
            USING ERRCODE = 'P0001';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_retraction_window
    BEFORE UPDATE ON loan_contributions
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status)
    EXECUTE FUNCTION fn_enforce_retraction_window();


-- ============================================================================
--  [T16]  CHECK LENDER COMPLETION  (LENDER → NEUTRAL)
--  Fires: AFTER UPDATE on loan_contributions
--  When a contribution transitions to RETURNED, checks whether this lender
--  has any remaining active (ESCROWED or DISBURSED) positions.
--  If none remain, the lender's role_state reverts to NEUTRAL.
--
--  Note: there is no cooling-off period for lenders — only for borrowers.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_check_lender_completion()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_remaining_active INT;
BEGIN
    -- Only act when a contribution becomes fully returned
    IF NEW.status <> 'RETURNED' OR OLD.status = 'RETURNED' THEN
        RETURN NULL;
    END IF;

    SELECT COUNT(*) INTO v_remaining_active
      FROM loan_contributions
     WHERE lender_id = NEW.lender_id
       AND status IN ('ESCROWED', 'DISBURSED');

    IF v_remaining_active = 0 THEN
        UPDATE users
           SET role_state = 'NEUTRAL'
         WHERE id = NEW.lender_id
           AND role_state = 'LENDER';
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_check_lender_completion
    AFTER UPDATE ON loan_contributions
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status)
    EXECUTE FUNCTION fn_check_lender_completion();


-- ============================================================================
--  [T17]  UPDATE CREDIT SCORE ON REPAYMENT EVENT
--  Fires: AFTER UPDATE on repayment_schedule
--
--  PENDING → PAID    : borrower credit score  +5   (capped at 850)
--  PENDING → OVERDUE : borrower credit score  −20  (floored at 300)
--
--  The floor and ceiling match the CHECK constraint on users.credit_score.
--  GREATEST / LEAST enforce them without a second query.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_update_credit_score()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_borrower_id UUID;
BEGIN
    -- Resolve borrower for this loan
    SELECT borrower_id INTO v_borrower_id
      FROM loans
     WHERE id = NEW.loan_id;

    IF NEW.status = 'PAID' AND OLD.status <> 'PAID' THEN
        UPDATE users
           SET credit_score = LEAST(850, credit_score + 5)
         WHERE id = v_borrower_id;

    ELSIF NEW.status = 'OVERDUE' AND OLD.status <> 'OVERDUE' THEN
        UPDATE users
           SET credit_score = GREATEST(300, credit_score - 20)
         WHERE id = v_borrower_id;
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_update_credit_score
    AFTER UPDATE ON repayment_schedule
    FOR EACH ROW
    WHEN (NEW.status IS DISTINCT FROM OLD.status)
    EXECUTE FUNCTION fn_update_credit_score();


-- ============================================================================
--  [T18]  ESCROW IMMUTABILITY AFTER RELEASE
--  Fires: BEFORE UPDATE on escrow_ledger
--  Once an escrow entry's state is set to 'RELEASED', no further UPDATE
--  is permitted on that row.  Prevents retroactive tampering with the
--  escrow history.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_escrow_immutable_after_release()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.state = 'RELEASED' THEN
        RAISE EXCEPTION
            '[T18] Escrow immutability violation: entry % was already RELEASED '
            'at % and cannot be modified.',
            OLD.id, OLD.released_at
            USING ERRCODE = 'P0002';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_escrow_immutable_after_release
    BEFORE UPDATE ON escrow_ledger
    FOR EACH ROW EXECUTE FUNCTION fn_escrow_immutable_after_release();


-- ============================================================================
--  [T19]  WALLET TRANSACTIONS — IMMUTABLE LEDGER
--  Fires: BEFORE UPDATE and BEFORE DELETE on wallet_transactions
--  wallet_transactions is an append-only double-entry ledger.
--  No modifications or deletions are ever permitted after insert.
--  Any attempt — regardless of the caller — raises an exception.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_wallet_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION
        '[T19] Immutability violation: wallet_transactions is an append-only '
        'ledger. UPDATE and DELETE are not permitted. '
        'Corrections must be made via a compensating transaction.'
        USING ERRCODE = 'P0002';
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_wallet_immutable
    BEFORE UPDATE OR DELETE ON wallet_transactions
    FOR EACH ROW EXECUTE FUNCTION fn_wallet_immutable();


-- ============================================================================
--  [T20]  AUDIT LOG — TAMPER-PROOF GUARD
--  Fires: BEFORE UPDATE and BEFORE DELETE on audit_log
--  The audit log is a regulatory-grade tamper-proof shadow table.
--  Once a row is written it can never be changed or removed.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_audit_log_immutable()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION
        '[T20] Immutability violation: audit_log is a tamper-proof ledger. '
        'UPDATE and DELETE are not permitted under any circumstance.'
        USING ERRCODE = 'P0002';
    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_audit_log_immutable
    BEFORE UPDATE OR DELETE ON audit_log
    FOR EACH ROW EXECUTE FUNCTION fn_audit_log_immutable();


-- ============================================================================
--  [T21 – T24]  ROW-LEVEL AUDIT CAPTURE
--  Fires: AFTER INSERT / UPDATE / DELETE on the four critical tables.
--  All four triggers share the single fn_audit_row() function defined at
--  the top of this file.  Each call writes one row to audit_log with a
--  full JSONB snapshot of old and/or new row state.
-- ============================================================================

-- [T21] users
CREATE TRIGGER trg_audit_users
    AFTER INSERT OR UPDATE OR DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

-- [T22] loans
CREATE TRIGGER trg_audit_loans
    AFTER INSERT OR UPDATE OR DELETE ON loans
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

-- [T23] loan_contributions
CREATE TRIGGER trg_audit_loan_contributions
    AFTER INSERT OR UPDATE OR DELETE ON loan_contributions
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row();

-- [T24] escrow_ledger
CREATE TRIGGER trg_audit_escrow_ledger
    AFTER INSERT OR UPDATE OR DELETE ON escrow_ledger
    FOR EACH ROW EXECUTE FUNCTION fn_audit_row();


-- ============================================================================
--  VERIFICATION QUERY  (run after applying this file to confirm all
--  triggers are registered — expected: 21 rows)
-- ============================================================================
-- SELECT trigger_name, event_manipulation, event_object_table, action_timing
--   FROM information_schema.triggers
--  WHERE trigger_schema = 'public'
--  ORDER BY event_object_table, action_timing, trigger_name;
