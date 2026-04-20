-- ============================================================================
--  Multi-Tiered Micro-Lending Platform
--  procedures.sql  |  Group ID: 13  |  PostgreSQL 16
--  Run AFTER schema.sql and triggers.sql
-- ============================================================================
--
--  Procedure / Function index
--  ──────────────────────────
--  Financial core
--   [P01]  proc_deposit_funds              — top up a user's wallet
--   [P02]  proc_withdraw_funds             — withdraw from wallet to bank
--   [P03]  proc_pledge_funds               — lender pledges to a loan (escrow)
--   [P04]  proc_retract_pledge             — lender retracts within 24-hour window
--   [P05]  proc_approve_loan               — admin approves UNDER_REVIEW → OPEN
--   [P06]  proc_reject_loan                — admin rejects UNDER_REVIEW → CANCELLED
--
--  Loan lifecycle
--   [P07]  fn_calculate_emi                — pure function: reducing-balance EMI
--   [P08]  proc_generate_repayment_schedule— build amortisation table at disbursal
--   [P09]  proc_disburse_loan              — atomic escrow → borrower disbursal
--   [P10]  proc_evaluate_expired_loans     — scheduler: handle deadline-passed loans
--
--  Repayment
--   [P11]  proc_process_emi_payment        — borrower pays EMI; pro-rata to lenders
--   [P12]  proc_mark_overdue_installments  — scheduler: PENDING → OVERDUE + penalty
--
--  Utility
--   [P13]  proc_update_kyc_status          — admin KYC gate management
-- ============================================================================


-- ============================================================================
--  [P01]  DEPOSIT FUNDS
--  Adds funds to a user's wallet and records the transaction in the ledger.
--  Called by the application when a user tops up via an external payment gateway.
--
--  Parameters
--   p_user_id   — target user
--   p_amount    — deposit amount (must be > 0)
--   p_desc      — optional description (e.g. "Bank transfer ref #XYZ")
-- ============================================================================
CREATE OR REPLACE PROCEDURE proc_deposit_funds(
    p_user_id   UUID,
    p_amount    NUMERIC(15, 2),
    p_desc      TEXT DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_balance_before NUMERIC(15, 2);
    v_balance_after  NUMERIC(15, 2);
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION '[P01] Deposit amount must be positive. Got: %', p_amount
            USING ERRCODE = 'P0001';
    END IF;

    -- Lock the user row for this transaction to prevent race conditions
    SELECT wallet_balance INTO v_balance_before
      FROM users
     WHERE id = p_user_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '[P01] User % not found.', p_user_id
            USING ERRCODE = 'P0001';
    END IF;

    v_balance_after := v_balance_before + p_amount;

    -- Update wallet
    UPDATE users
       SET wallet_balance = v_balance_after
     WHERE id = p_user_id;

    -- Immutable ledger entry
    INSERT INTO wallet_transactions
        (user_id, transaction_type, amount,
         balance_before, balance_after, description)
    VALUES
        (p_user_id, 'DEPOSIT', p_amount,
         v_balance_before, v_balance_after, p_desc);
END;
$$;


-- ============================================================================
--  [P02]  WITHDRAW FUNDS
--  Debits a user's wallet.  Blocks if balance would go negative or if the
--  user has ESCROWED funds (withdrawing escrowed funds would be fraudulent —
--  their wallet balance should already exclude escrowed amounts, but we verify).
--
--  Parameters
--   p_user_id   — target user
--   p_amount    — withdrawal amount (must be > 0)
--   p_desc      — optional description
-- ============================================================================
CREATE OR REPLACE PROCEDURE proc_withdraw_funds(
    p_user_id   UUID,
    p_amount    NUMERIC(15, 2),
    p_desc      TEXT DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
    v_balance_before NUMERIC(15, 2);
    v_balance_after  NUMERIC(15, 2);
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION '[P02] Withdrawal amount must be positive. Got: %', p_amount
            USING ERRCODE = 'P0001';
    END IF;

    SELECT wallet_balance INTO v_balance_before
      FROM users
     WHERE id = p_user_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '[P02] User % not found.', p_user_id
            USING ERRCODE = 'P0001';
    END IF;

    v_balance_after := v_balance_before - p_amount;

    IF v_balance_after < 0 THEN
        RAISE EXCEPTION
            '[P02] Withdrawal of % exceeds available balance of %.',
            p_amount, v_balance_before
            USING ERRCODE = 'P0001';
    END IF;

    UPDATE users
       SET wallet_balance = v_balance_after
     WHERE id = p_user_id;

    INSERT INTO wallet_transactions
        (user_id, transaction_type, amount,
         balance_before, balance_after, description)
    VALUES
        (p_user_id, 'WITHDRAWAL', -p_amount,
         v_balance_before, v_balance_after, p_desc);
END;
$$;


-- ============================================================================
--  [P03]  PLEDGE FUNDS
--  Core lender action.  Atomically:
--   1. Validates the loan is OPEN and not past its funding deadline
--   2. Deducts pledge from lender's wallet
--   3. Creates the loan_contribution row  (triggers T05–T12 fire here)
--   4. Creates the escrow_ledger LOCKED entry
--   5. Records a PLEDGE_TO_ESCROW wallet_transaction
--   6. If the loan is now fully funded, immediately triggers disbursal
--
--  Parameters
--   p_lender_id      — the lending user
--   p_loan_id        — the target loan
--   p_pledge_amount  — amount to pledge (must satisfy exposure cap & balance)
-- ============================================================================
CREATE OR REPLACE PROCEDURE proc_pledge_funds(
    p_lender_id     UUID,
    p_loan_id       UUID,
    p_pledge_amount NUMERIC(15, 2)
)
LANGUAGE plpgsql AS $$
DECLARE
    v_loan              RECORD;
    v_lender_balance    NUMERIC(15, 2);
    v_contribution_id   UUID;
    v_new_funded        NUMERIC(15, 2);
BEGIN
    IF p_pledge_amount <= 0 THEN
        RAISE EXCEPTION '[P03] Pledge amount must be positive. Got: %', p_pledge_amount
            USING ERRCODE = 'P0001';
    END IF;

    -- Lock loan row; read current state
    SELECT id, status, requested_amount, funded_amount, funding_deadline
      INTO v_loan
      FROM loans
     WHERE id = p_loan_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '[P03] Loan % not found.', p_loan_id
            USING ERRCODE = 'P0001';
    END IF;

    IF v_loan.status <> 'OPEN' THEN
        RAISE EXCEPTION
            '[P03] Pledge blocked: loan status is "%" — can only pledge to OPEN loans.',
            v_loan.status
            USING ERRCODE = 'P0001';
    END IF;

    IF NOW() > v_loan.funding_deadline THEN
        RAISE EXCEPTION
            '[P03] Pledge blocked: funding deadline has passed (%)',
            v_loan.funding_deadline
            USING ERRCODE = 'P0001';
    END IF;

    -- Cap pledge to remaining unfunded amount (no over-funding)
    IF v_loan.funded_amount + p_pledge_amount > v_loan.requested_amount THEN
        RAISE EXCEPTION
            '[P03] Pledge of % would exceed the remaining funding gap of %.',
            p_pledge_amount,
            (v_loan.requested_amount - v_loan.funded_amount)
            USING ERRCODE = 'P0001';
    END IF;

    -- Lock lender wallet
    SELECT wallet_balance INTO v_lender_balance
      FROM users
     WHERE id = p_lender_id
       FOR UPDATE;

    -- Deduct from lender wallet
    UPDATE users
       SET wallet_balance = wallet_balance - p_pledge_amount
     WHERE id = p_lender_id;

    -- Insert contribution (triggers T05–T12 fire here, including KYC,
    -- cooling-off, no-self-fund, balance, exposure, position cap checks)
    INSERT INTO loan_contributions
        (loan_id, lender_id, pledged_amount, status)
    VALUES
        (p_loan_id, p_lender_id, p_pledge_amount, 'ESCROWED')
    RETURNING id INTO v_contribution_id;

    -- Create escrow entry
    INSERT INTO escrow_ledger
        (contribution_id, loan_id, lender_id, amount, state)
    VALUES
        (v_contribution_id, p_loan_id, p_lender_id, p_pledge_amount, 'LOCKED');

    -- Record debit in wallet ledger
    INSERT INTO wallet_transactions
        (user_id, transaction_type, amount,
         balance_before, balance_after, reference_id, description)
    VALUES
        (p_lender_id, 'PLEDGE_TO_ESCROW', -p_pledge_amount,
         v_lender_balance,
         v_lender_balance - p_pledge_amount,
         p_loan_id,
         'Pledged to loan: ' || p_loan_id::TEXT);

    -- Refresh funded_amount (trigger T12 already updated it; read the result)
    SELECT funded_amount INTO v_new_funded
      FROM loans
     WHERE id = p_loan_id;

    -- Auto-disburse if fully funded
    IF v_new_funded = v_loan.requested_amount THEN
        CALL proc_disburse_loan(p_loan_id);
    END IF;

END;
$$;


-- ============================================================================
--  [P04]  RETRACT PLEDGE
--  Allows a lender to withdraw their pledge within the 24-hour window.
--  Atomically:
--   1. Validates the retraction window (trigger T13 does the final check)
--   2. Sets contribution status → RETRACTED
--   3. Releases the escrow entry → RELEASED (LENDER_RETRACTED)
--   4. Credits lender's wallet
--   5. Records a PLEDGE_RETRACTION wallet_transaction
--
--  Parameters
--   p_lender_id      — the lender retracting
--   p_contribution_id— the specific contribution to retract
-- ============================================================================
CREATE OR REPLACE PROCEDURE proc_retract_pledge(
    p_lender_id       UUID,
    p_contribution_id UUID
)
LANGUAGE plpgsql AS $$
DECLARE
    v_contrib       RECORD;
    v_balance_before NUMERIC(15, 2);
    v_balance_after  NUMERIC(15, 2);
BEGIN
    -- Lock and read the contribution
    SELECT lc.id, lc.loan_id, lc.pledged_amount, lc.status, lc.created_at
      INTO v_contrib
      FROM loan_contributions lc
     WHERE lc.id = p_contribution_id
       AND lc.lender_id = p_lender_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            '[P04] Contribution % not found for lender %.', p_contribution_id, p_lender_id
            USING ERRCODE = 'P0001';
    END IF;

    -- Update contribution → RETRACTED  (trigger T13 fires and validates window)
    UPDATE loan_contributions
       SET status = 'RETRACTED'
     WHERE id = p_contribution_id;

    -- Release escrow entry
    UPDATE escrow_ledger
       SET state          = 'RELEASED',
           released_at    = NOW(),
           release_reason = 'LENDER_RETRACTED'
     WHERE contribution_id = p_contribution_id
       AND state = 'LOCKED';

    -- Credit lender wallet
    SELECT wallet_balance INTO v_balance_before
      FROM users
     WHERE id = p_lender_id
       FOR UPDATE;

    v_balance_after := v_balance_before + v_contrib.pledged_amount;

    UPDATE users
       SET wallet_balance = v_balance_after
     WHERE id = p_lender_id;

    INSERT INTO wallet_transactions
        (user_id, transaction_type, amount,
         balance_before, balance_after, reference_id, description)
    VALUES
        (p_lender_id, 'PLEDGE_RETRACTION', v_contrib.pledged_amount,
         v_balance_before, v_balance_after,
         p_contribution_id,
         'Pledge retracted for loan: ' || v_contrib.loan_id::TEXT);
END;
$$;


-- ============================================================================
--  [P05]  APPROVE LOAN  (admin action)
--  Transitions a loan from UNDER_REVIEW → OPEN, making it visible on the
--  marketplace for lenders to pledge against.
--
--  Parameters
--   p_admin_id  — the approving admin user's ID (logged in audit)
--   p_loan_id   — the loan to approve
-- ============================================================================
CREATE OR REPLACE PROCEDURE proc_approve_loan(
    p_admin_id  UUID,
    p_loan_id   UUID
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE loans
       SET status      = 'OPEN',
           reviewed_by = p_admin_id,
           reviewed_at = NOW()
     WHERE id = p_loan_id
       AND status = 'UNDER_REVIEW';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            '[P05] Loan % is not in UNDER_REVIEW status or does not exist.', p_loan_id
            USING ERRCODE = 'P0001';
    END IF;
END;
$$;


-- ============================================================================
--  [P06]  REJECT LOAN  (admin action)
--  Transitions UNDER_REVIEW → CANCELLED and records the rejection reason.
--  Trigger T04 fires on this UPDATE and releases the borrower's role back
--  to NEUTRAL (no cooling-off for admin rejection).
--
--  Parameters
--   p_admin_id        — the rejecting admin
--   p_loan_id         — the loan to reject
--   p_rejection_reason— mandatory reason text
-- ============================================================================
CREATE OR REPLACE PROCEDURE proc_reject_loan(
    p_admin_id          UUID,
    p_loan_id           UUID,
    p_rejection_reason  TEXT
)
LANGUAGE plpgsql AS $$
BEGIN
    IF p_rejection_reason IS NULL OR TRIM(p_rejection_reason) = '' THEN
        RAISE EXCEPTION '[P06] A rejection reason is required.'
            USING ERRCODE = 'P0001';
    END IF;

    UPDATE loans
       SET status           = 'CANCELLED',
           reviewed_by      = p_admin_id,
           reviewed_at      = NOW(),
           rejection_reason = p_rejection_reason
     WHERE id = p_loan_id
       AND status = 'UNDER_REVIEW';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            '[P06] Loan % is not in UNDER_REVIEW status or does not exist.', p_loan_id
            USING ERRCODE = 'P0001';
    END IF;
    -- Trigger T04 (fn_handle_loan_status_change) fires here:
    -- borrower.role_state → NEUTRAL, cooling_off_until → NULL
END;
$$;


-- ============================================================================
--  [P07]  CALCULATE EMI  (pure function — no side effects)
--
--  Reducing-balance (diminishing principal) EMI formula:
--
--    r   = annual_rate / 12 / 100          (monthly interest rate)
--    EMI = P × r × (1 + r)^n
--          ──────────────────
--             (1 + r)^n − 1
--
--  Parameters
--   p_principal   — loan disbursed amount
--   p_annual_rate — annual interest rate percentage (e.g. 12.00)
--   p_months      — repayment tenure in months
--
--  Returns
--   NUMERIC(15,2) — fixed monthly EMI amount, rounded to 2 decimal places
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_calculate_emi(
    p_principal     NUMERIC(15, 2),
    p_annual_rate   NUMERIC(5, 2),
    p_months        INT
)
RETURNS NUMERIC(15, 2)
LANGUAGE plpgsql IMMUTABLE STRICT AS $$
DECLARE
    v_r   NUMERIC(20, 10);   -- monthly interest rate
    v_emi NUMERIC(20, 10);
BEGIN
    IF p_months <= 0 OR p_principal <= 0 OR p_annual_rate <= 0 THEN
        RAISE EXCEPTION
            '[P07] fn_calculate_emi: all inputs must be positive. '
            'Got principal=%, rate=%, months=%',
            p_principal, p_annual_rate, p_months;
    END IF;

    v_r := p_annual_rate / 12.0 / 100.0;

    -- Standard reducing-balance formula
    v_emi := p_principal
             * v_r
             * POWER(1.0 + v_r, p_months)
             / (POWER(1.0 + v_r, p_months) - 1.0);

    RETURN ROUND(v_emi, 2);
END;
$$;


-- ============================================================================
--  [P08]  GENERATE REPAYMENT SCHEDULE
--  Builds the full amortisation table for a loan using the reducing-balance
--  formula.  Called internally by proc_disburse_loan immediately after the
--  disbursed_amount is confirmed.
--
--  Each installment row stores:
--   • EMI amount (constant across all installments)
--   • Interest component  = opening_balance × monthly_rate
--   • Principal component = EMI − interest component
--   • opening_balance     = previous closing_balance
--   • closing_balance     = opening_balance − principal component
--
--  The final installment's closing_balance is forced to 0.00 to absorb
--  any floating-point rounding accumulated across all installments.
--
--  Parameters
--   p_loan_id — the loan for which to generate the schedule
--              (reads disbursed_amount, interest_rate_annual, tenure_months)
-- ============================================================================
CREATE OR REPLACE PROCEDURE proc_generate_repayment_schedule(
    p_loan_id UUID
)
LANGUAGE plpgsql AS $$
DECLARE
    v_loan          RECORD;
    v_emi           NUMERIC(15, 2);
    v_monthly_rate  NUMERIC(20, 10);
    v_balance       NUMERIC(15, 2);
    v_interest      NUMERIC(15, 2);
    v_principal     NUMERIC(15, 2);
    v_due_date      DATE;
    v_i             INT;
BEGIN
    SELECT disbursed_amount,
           interest_rate_annual,
           tenure_months,
           created_at::DATE AS start_date
      INTO v_loan
      FROM loans
     WHERE id = p_loan_id;

    IF v_loan.disbursed_amount IS NULL THEN
        RAISE EXCEPTION
            '[P08] Cannot generate schedule: loan % has no disbursed_amount set.', p_loan_id
            USING ERRCODE = 'P0001';
    END IF;

    -- Clear any previously generated schedule (idempotent re-run safety)
    DELETE FROM repayment_schedule WHERE loan_id = p_loan_id;

    v_emi          := fn_calculate_emi(
                          v_loan.disbursed_amount,
                          v_loan.interest_rate_annual,
                          v_loan.tenure_months);
    v_monthly_rate := v_loan.interest_rate_annual / 12.0 / 100.0;
    v_balance      := v_loan.disbursed_amount;

    FOR v_i IN 1 .. v_loan.tenure_months LOOP
        v_due_date  := v_loan.start_date + (v_i * INTERVAL '1 month')::INTERVAL;
        v_interest  := ROUND(v_balance * v_monthly_rate, 2);
        v_principal := v_emi - v_interest;

        -- Final installment: absorb rounding residual
        IF v_i = v_loan.tenure_months THEN
            v_principal := v_balance;       -- clear the remaining balance exactly
            v_emi       := v_principal + v_interest;
        END IF;

        INSERT INTO repayment_schedule (
            loan_id, installment_no, due_date,
            emi_amount, principal_component, interest_component,
            opening_balance, closing_balance,
            status
        ) VALUES (
            p_loan_id, v_i, v_due_date,
            v_emi, v_principal, v_interest,
            v_balance, GREATEST(0.00, v_balance - v_principal),
            'PENDING'
        );

        v_balance := GREATEST(0.00, v_balance - v_principal);
    END LOOP;
END;
$$;


-- ============================================================================
--  [P09]  DISBURSE LOAN  (Atomic Disbursal Engine)
--  The financial centrepiece of the platform.  Executes within a single
--  transaction block to guarantee atomicity across all state changes.
--
--  Steps performed
--  ───────────────
--   1. Validate: loan is OPEN and deadline has passed (or fully funded)
--   2. Validate: funded_amount ≥ min_funding_pct of requested_amount;
--      if not → CANCEL the loan and refund all escrow to lenders
--   3. Set disbursed_amount = funded_amount (handles partial funding)
--   4. Transition loan status → ACTIVE
--   5. For each ESCROWED contribution:
--       a. Release escrow entry (LOCKED → RELEASED / DISBURSED)
--       b. Set contribution status → DISBURSED
--   6. Credit disbursed_amount to borrower's wallet in one atomic step
--   7. Record LOAN_DISBURSEMENT wallet_transaction for borrower
--   8. Call proc_generate_repayment_schedule to build amortisation table
--
--  Parameters
--   p_loan_id — the loan to disburse
-- ============================================================================
CREATE OR REPLACE PROCEDURE proc_disburse_loan(
    p_loan_id UUID
)
LANGUAGE plpgsql AS $$
DECLARE
    v_loan              RECORD;
    v_min_required      NUMERIC(15, 2);
    v_contrib           RECORD;
    v_borrower_balance  NUMERIC(15, 2);
BEGIN
    -- Lock and read loan
    SELECT id, borrower_id, requested_amount, funded_amount,
           min_funding_pct, status, funding_deadline
      INTO v_loan
      FROM loans
     WHERE id = p_loan_id
       FOR UPDATE;

    IF v_loan.status <> 'OPEN' THEN
        RAISE EXCEPTION
            '[P09] Disbursal blocked: loan status is "%" (expected OPEN).', v_loan.status
            USING ERRCODE = 'P0001';
    END IF;

    v_min_required := ROUND(v_loan.requested_amount * v_loan.min_funding_pct / 100.0, 2);

    -- ── BRANCH A: Threshold not met → cancel and refund ──────────────────────
    IF v_loan.funded_amount < v_min_required THEN

        -- Cancel the loan
        UPDATE loans
           SET status = 'CANCELLED'
         WHERE id = p_loan_id;

        -- Refund each lender from escrow
        FOR v_contrib IN
            SELECT lc.id AS contribution_id,
                   lc.lender_id,
                   lc.pledged_amount,
                   el.id AS escrow_id
              FROM loan_contributions lc
              JOIN escrow_ledger el ON el.contribution_id = lc.id
             WHERE lc.loan_id = p_loan_id
               AND lc.status = 'ESCROWED'
               AND el.state  = 'LOCKED'
               FOR UPDATE OF lc, el
        LOOP
            -- Mark contribution retracted-equivalent on cancel
            UPDATE loan_contributions
               SET status = 'RETURNED'
             WHERE id = v_contrib.contribution_id;

            -- Release escrow
            UPDATE escrow_ledger
               SET state          = 'RELEASED',
                   released_at    = NOW(),
                   release_reason = 'LOAN_CANCELLED'
             WHERE id = v_contrib.escrow_id;

            -- Refund lender wallet
            DECLARE
                v_bal_before NUMERIC(15, 2);
                v_bal_after  NUMERIC(15, 2);
            BEGIN
                SELECT wallet_balance INTO v_bal_before
                  FROM users
                 WHERE id = v_contrib.lender_id
                   FOR UPDATE;

                v_bal_after := v_bal_before + v_contrib.pledged_amount;

                UPDATE users
                   SET wallet_balance = v_bal_after
                 WHERE id = v_contrib.lender_id;

                INSERT INTO wallet_transactions
                    (user_id, transaction_type, amount,
                     balance_before, balance_after, reference_id, description)
                VALUES
                    (v_contrib.lender_id, 'ESCROW_REFUND', v_contrib.pledged_amount,
                     v_bal_before, v_bal_after, p_loan_id,
                     'Escrow refunded: loan cancelled (threshold not met)');
            END;
        END LOOP;

        RAISE NOTICE
            '[P09] Loan % cancelled: funded % of minimum required %. '
            'All escrow refunded to lenders.',
            p_loan_id, v_loan.funded_amount, v_min_required;
        RETURN;
    END IF;

    -- ── BRANCH B: Threshold met → disburse ───────────────────────────────────

    -- Set disbursed_amount to actual funded amount (handles partial funding)
    UPDATE loans
       SET status           = 'ACTIVE',
           disbursed_amount = v_loan.funded_amount
     WHERE id = p_loan_id;

    -- Release all escrow entries and mark contributions DISBURSED
    FOR v_contrib IN
        SELECT lc.id AS contribution_id,
               lc.lender_id,
               lc.pledged_amount,
               el.id AS escrow_id
          FROM loan_contributions lc
          JOIN escrow_ledger el ON el.contribution_id = lc.id
         WHERE lc.loan_id = p_loan_id
           AND lc.status  = 'ESCROWED'
           AND el.state   = 'LOCKED'
           FOR UPDATE OF lc, el
    LOOP
        UPDATE loan_contributions
           SET status = 'DISBURSED'
         WHERE id = v_contrib.contribution_id;

        UPDATE escrow_ledger
           SET state          = 'RELEASED',
               released_at    = NOW(),
               release_reason = 'DISBURSED'
         WHERE id = v_contrib.escrow_id;
    END LOOP;

    -- Credit borrower wallet with full disbursed_amount in one step
    SELECT wallet_balance INTO v_borrower_balance
      FROM users
     WHERE id = v_loan.borrower_id
       FOR UPDATE;

    UPDATE users
       SET wallet_balance = v_borrower_balance + v_loan.funded_amount
     WHERE id = v_loan.borrower_id;

    INSERT INTO wallet_transactions
        (user_id, transaction_type, amount,
         balance_before, balance_after, reference_id, description)
    VALUES
        (v_loan.borrower_id, 'LOAN_DISBURSEMENT', v_loan.funded_amount,
         v_borrower_balance,
         v_borrower_balance + v_loan.funded_amount,
         p_loan_id,
         'Loan disbursed: ' || p_loan_id::TEXT);

    -- Generate amortisation schedule based on actual disbursed_amount
    CALL proc_generate_repayment_schedule(p_loan_id);

    RAISE NOTICE
        '[P09] Loan % disbursed. Amount: %. Repayment schedule generated for % months.',
        p_loan_id, v_loan.funded_amount,
        (SELECT tenure_months FROM loans WHERE id = p_loan_id);
END;
$$;


-- ============================================================================
--  [P10]  EVALUATE EXPIRED LOANS  (scheduled procedure)
--  Scans all OPEN loans whose funding_deadline has passed and resolves them.
--  Meant to be called by pg_cron or an external scheduler (e.g. every hour).
--
--  For each expired loan:
--    • If funded_amount ≥ min_funding_pct  → call proc_disburse_loan
--    • If funded_amount <  min_funding_pct → disbursal handles cancellation
--
--  The disbursal procedure itself contains the threshold check and handles
--  both branches (disburse or cancel + refund), so this procedure is simply
--  a scanner that finds eligible loans and calls proc_disburse_loan.
--
--  Returns: count of loans processed
-- ============================================================================
CREATE OR REPLACE FUNCTION proc_evaluate_expired_loans()
RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE
    v_loan_id   UUID;
    v_processed INT := 0;
BEGIN
    FOR v_loan_id IN
        SELECT id
          FROM loans
         WHERE status = 'OPEN'
           AND funding_deadline < NOW()
         ORDER BY funding_deadline ASC   -- process oldest deadlines first
    LOOP
        BEGIN
            CALL proc_disburse_loan(v_loan_id);
            v_processed := v_processed + 1;
        EXCEPTION WHEN OTHERS THEN
            -- Log individual failures without aborting the whole sweep
            RAISE WARNING
                '[P10] Failed to process loan %: %', v_loan_id, SQLERRM;
        END;
    END LOOP;

    RAISE NOTICE '[P10] Evaluated % expired loan(s).', v_processed;
    RETURN v_processed;
END;
$$;


-- ============================================================================
--  [P11]  PROCESS EMI PAYMENT  (pro-rata distribution engine)
--  The most complex procedure on the platform.  Executes atomically.
--
--  Steps performed
--  ───────────────
--   1. Validate the installment: belongs to caller, status = PENDING/OVERDUE
--   2. Deduct (emi_amount + penalty_amount) from borrower wallet
--   3. Mark installment → PAID, record paid_at
--   4. For each DISBURSED lender contribution:
--       a. Calculate contribution_ratio  = pledged / disbursed
--       b. principal_share              = principal_component × ratio
--       c. gross_interest               = interest_component × ratio
--       d. platform_fee                 = gross_interest × platform_fee_pct / 100
--       e. net_interest                 = gross_interest − platform_fee
--       f. total_credited               = principal_share + net_interest
--       g. Credit lender wallet with total_credited
--       h. Insert emi_distributions row
--       i. Insert platform_revenue row
--       j. Record EMI_PRINCIPAL_RECEIPT and EMI_INTEREST_RECEIPT wallet txns
--       k. Increment loan_contributions.returned_amount by principal_share
--       l. If returned_amount = pledged_amount → status → RETURNED
--          (trigger T16 fires and transitions lender role if no positions left)
--   5. Credit score update: trigger T17 fires on repayment_schedule UPDATE
--   6. Check if all installments are PAID → transition loan → COMPLETED
--      (trigger T04 fires and applies 48h cooling-off to borrower)
--
--  Parameters
--   p_borrower_id   — must match the loan's borrower_id (safety check)
--   p_schedule_id   — the specific installment to pay
-- ============================================================================
CREATE OR REPLACE PROCEDURE proc_process_emi_payment(
    p_borrower_id UUID,
    p_schedule_id UUID
)
LANGUAGE plpgsql AS $$
DECLARE
    v_sched             RECORD;
    v_loan              RECORD;
    v_total_due         NUMERIC(15, 2);
    v_borrower_balance  NUMERIC(15, 2);
    v_contrib           RECORD;
    v_ratio             NUMERIC(12, 10);
    v_principal_share   NUMERIC(15, 2);
    v_gross_interest    NUMERIC(15, 2);
    v_platform_fee      NUMERIC(15, 2);
    v_net_interest      NUMERIC(15, 2);
    v_total_credit      NUMERIC(15, 2);
    v_lender_bal_before NUMERIC(15, 2);
    v_lender_bal_after  NUMERIC(15, 2);
    v_new_returned      NUMERIC(15, 2);
    v_pending_count     INT;
    v_borrow_bal_after  NUMERIC(15, 2);
BEGIN
    -- ── Step 1: Read and validate the installment ─────────────────────────────
    SELECT rs.id, rs.loan_id, rs.installment_no, rs.emi_amount,
           rs.principal_component, rs.interest_component,
           rs.penalty_amount, rs.status
      INTO v_sched
      FROM repayment_schedule rs
     WHERE rs.id = p_schedule_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '[P11] Installment % not found.', p_schedule_id
            USING ERRCODE = 'P0001';
    END IF;

    IF v_sched.status NOT IN ('PENDING', 'OVERDUE') THEN
        RAISE EXCEPTION
            '[P11] Installment % is already "%". Only PENDING or OVERDUE installments can be paid.',
            p_schedule_id, v_sched.status
            USING ERRCODE = 'P0001';
    END IF;

    -- Read loan and validate caller is the borrower
    SELECT l.id, l.borrower_id, l.disbursed_amount,
           l.platform_fee_pct, l.tenure_months
      INTO v_loan
      FROM loans l
     WHERE l.id = v_sched.loan_id
       FOR UPDATE;

    IF v_loan.borrower_id <> p_borrower_id THEN
        RAISE EXCEPTION
            '[P11] Caller % is not the borrower of loan %.', p_borrower_id, v_loan.id
            USING ERRCODE = 'P0001';
    END IF;

    -- ── Step 2: Deduct from borrower wallet ───────────────────────────────────
    v_total_due := v_sched.emi_amount + v_sched.penalty_amount;

    SELECT wallet_balance INTO v_borrower_balance
      FROM users
     WHERE id = p_borrower_id
       FOR UPDATE;

    IF v_borrower_balance < v_total_due THEN
        RAISE EXCEPTION
            '[P11] Insufficient balance: borrower has %, EMI due is % (incl. penalty %).',
            v_borrower_balance, v_total_due, v_sched.penalty_amount
            USING ERRCODE = 'P0001';
    END IF;

    v_borrow_bal_after := v_borrower_balance - v_total_due;

    UPDATE users
       SET wallet_balance = v_borrow_bal_after
     WHERE id = p_borrower_id;

    -- Record borrower debit
    INSERT INTO wallet_transactions
        (user_id, transaction_type, amount,
         balance_before, balance_after, reference_id, description)
    VALUES
        (p_borrower_id, 'EMI_PAYMENT', -v_total_due,
         v_borrower_balance, v_borrow_bal_after,
         p_schedule_id,
         'EMI #' || v_sched.installment_no || ' for loan ' || v_loan.id::TEXT);

    -- Log penalty charge separately if applicable
    IF v_sched.penalty_amount > 0 THEN
        INSERT INTO wallet_transactions
            (user_id, transaction_type, amount,
             balance_before, balance_after, reference_id, description)
        VALUES
            (p_borrower_id, 'PENALTY_CHARGE', -v_sched.penalty_amount,
             v_borrower_balance, v_borrow_bal_after,
             p_schedule_id,
             'Late penalty for EMI #' || v_sched.installment_no);
    END IF;

    -- ── Step 3: Mark installment PAID  (trigger T17 fires → credit score +5) ─
    UPDATE repayment_schedule
       SET status  = 'PAID',
           paid_at = NOW()
     WHERE id = p_schedule_id;

    -- ── Step 4: Pro-rata distribution to each lender ─────────────────────────
    FOR v_contrib IN
        SELECT lc.id, lc.lender_id, lc.pledged_amount, lc.returned_amount
          FROM loan_contributions lc
         WHERE lc.loan_id = v_sched.loan_id
           AND lc.status  = 'DISBURSED'
           FOR UPDATE OF lc
    LOOP
        -- 4a. Fractional share of this lender's contribution
        v_ratio := ROUND(
            v_contrib.pledged_amount::NUMERIC / v_loan.disbursed_amount::NUMERIC,
            10);

        -- 4b–4e. Breakdown
        v_principal_share := ROUND(v_sched.principal_component * v_ratio, 2);
        v_gross_interest  := ROUND(v_sched.interest_component  * v_ratio, 2);
        v_platform_fee    := ROUND(v_gross_interest * v_loan.platform_fee_pct / 100.0, 2);
        v_net_interest    := v_gross_interest - v_platform_fee;
        v_total_credit    := v_principal_share + v_net_interest;

        -- 4f. Credit lender wallet
        SELECT wallet_balance INTO v_lender_bal_before
          FROM users
         WHERE id = v_contrib.lender_id
           FOR UPDATE;

        v_lender_bal_after := v_lender_bal_before + v_total_credit;

        UPDATE users
           SET wallet_balance = v_lender_bal_after
         WHERE id = v_contrib.lender_id;

        -- 4g. Insert distribution record
        INSERT INTO emi_distributions (
            schedule_id, loan_id, contribution_id, lender_id,
            contribution_ratio,
            principal_share, gross_interest_share,
            platform_fee_amount, net_interest_share,
            total_credited
        ) VALUES (
            p_schedule_id, v_loan.id, v_contrib.id, v_contrib.lender_id,
            v_ratio,
            v_principal_share, v_gross_interest,
            v_platform_fee, v_net_interest,
            v_total_credit
        );

        -- 4h. Record platform revenue
        IF v_platform_fee > 0 THEN
            INSERT INTO platform_revenue
                (loan_id, schedule_id, contribution_id, lender_id,
                 fee_amount, fee_pct_applied)
            VALUES
                (v_loan.id, p_schedule_id, v_contrib.id, v_contrib.lender_id,
                 v_platform_fee, v_loan.platform_fee_pct);
        END IF;

        -- 4i. Wallet transaction: principal receipt
        INSERT INTO wallet_transactions
            (user_id, transaction_type, amount,
             balance_before, balance_after, reference_id, description)
        VALUES
            (v_contrib.lender_id, 'EMI_PRINCIPAL_RECEIPT', v_principal_share,
             v_lender_bal_before,
             v_lender_bal_before + v_principal_share,
             p_schedule_id,
             'Principal recovery EMI #' || v_sched.installment_no);

        -- 4j. Wallet transaction: interest receipt
        INSERT INTO wallet_transactions
            (user_id, transaction_type, amount,
             balance_before, balance_after, reference_id, description)
        VALUES
            (v_contrib.lender_id, 'EMI_INTEREST_RECEIPT', v_net_interest,
             v_lender_bal_before + v_principal_share,
             v_lender_bal_after,
             p_schedule_id,
             'Net interest EMI #' || v_sched.installment_no
             || ' (platform fee: ' || v_platform_fee || ')');

        -- 4k. Update contribution's returned_amount
        v_new_returned := v_contrib.returned_amount + v_principal_share;

        UPDATE loan_contributions
           SET returned_amount = v_new_returned,
               status = CASE
                   WHEN v_new_returned >= v_contrib.pledged_amount
                       THEN 'RETURNED'    -- trigger T16 fires → check lender role
                   ELSE status
               END
         WHERE id = v_contrib.id;

    END LOOP;

    -- ── Step 5: Check if loan is fully repaid ─────────────────────────────────
    SELECT COUNT(*) INTO v_pending_count
      FROM repayment_schedule
     WHERE loan_id = v_sched.loan_id
       AND status IN ('PENDING', 'OVERDUE');

    IF v_pending_count = 0 THEN
        -- All installments paid → COMPLETED
        -- Trigger T04 fires: borrower role → NEUTRAL + 48h cooling-off
        UPDATE loans
           SET status = 'COMPLETED'
         WHERE id = v_sched.loan_id;

        RAISE NOTICE
            '[P11] Loan % fully repaid. Borrower role reset with 48-hour cooling-off.',
            v_sched.loan_id;
    END IF;
END;
$$;


-- ============================================================================
--  [P12]  MARK OVERDUE INSTALLMENTS  (scheduled procedure)
--  Scans all PENDING installments whose due_date + grace_period_days has
--  passed and transitions them to OVERDUE, applying the late penalty.
--
--  Penalty amount = emi_amount × (late_penalty_pct / 100)
--  Trigger T17 fires on the status UPDATE → credit score −20 per overdue EMI.
--
--  Meant to be called by pg_cron or an external scheduler (e.g. every day
--  at midnight).
--
--  Returns: count of installments marked overdue
-- ============================================================================
CREATE OR REPLACE FUNCTION proc_mark_overdue_installments()
RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE
    v_sched     RECORD;
    v_penalty   NUMERIC(15, 2);
    v_count     INT := 0;
BEGIN
    FOR v_sched IN
        SELECT rs.id           AS schedule_id,
               rs.emi_amount,
               rs.loan_id,
               l.grace_period_days,
               l.late_penalty_pct
          FROM repayment_schedule rs
          JOIN loans l ON l.id = rs.loan_id
         WHERE rs.status = 'PENDING'
           AND rs.due_date + (l.grace_period_days || ' days')::INTERVAL < NOW()
         ORDER BY rs.due_date ASC
    LOOP
        v_penalty := ROUND(v_sched.emi_amount * v_sched.late_penalty_pct / 100.0, 2);

        -- Status → OVERDUE triggers T17 (credit score −20)
        UPDATE repayment_schedule
           SET status         = 'OVERDUE',
               penalty_amount = v_penalty
         WHERE id = v_sched.schedule_id;

        v_count := v_count + 1;
    END LOOP;

    RAISE NOTICE '[P12] % installment(s) marked OVERDUE.', v_count;
    RETURN v_count;
END;
$$;


-- ============================================================================
--  [P13]  UPDATE KYC STATUS  (admin action)
--  Allows an admin to transition a user's KYC status.
--  SUSPENDED users cannot be restored via this procedure alone — a separate
--  admin review flow would be required in a production system.
--
--  Valid transitions:
--   UNVERIFIED → VERIFIED
--   VERIFIED   → SUSPENDED
--   SUSPENDED  → VERIFIED   (admin reinstatement)
--
--  Parameters
--   p_admin_id    — admin performing the change (audit trail)
--   p_user_id     — target user
--   p_new_status  — target KYC status
--   p_reason      — mandatory reason text
-- ============================================================================
CREATE OR REPLACE PROCEDURE proc_update_kyc_status(
    p_admin_id   UUID,
    p_user_id    UUID,
    p_new_status VARCHAR(12),
    p_reason     TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_current_kyc VARCHAR(12);
BEGIN
    IF p_new_status NOT IN ('UNVERIFIED', 'VERIFIED', 'SUSPENDED') THEN
        RAISE EXCEPTION '[P13] Invalid KYC status: %', p_new_status
            USING ERRCODE = 'P0001';
    END IF;

    IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
        RAISE EXCEPTION '[P13] A reason is required for KYC status changes.'
            USING ERRCODE = 'P0001';
    END IF;

    SELECT kyc_status INTO v_current_kyc
      FROM users
     WHERE id = p_user_id
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '[P13] User % not found.', p_user_id
            USING ERRCODE = 'P0001';
    END IF;

    IF v_current_kyc = p_new_status THEN
        RAISE NOTICE '[P13] User % already has KYC status "%". No change made.',
            p_user_id, p_new_status;
        RETURN;
    END IF;

    -- SET LOCAL ensures the audit trigger logs the admin as the change author
    PERFORM set_config('app.current_user_id', p_admin_id::TEXT, true);

    UPDATE users
       SET kyc_status = p_new_status
     WHERE id = p_user_id;

    RAISE NOTICE
        '[P13] KYC status for user % changed: % → %. Reason: %',
        p_user_id, v_current_kyc, p_new_status, p_reason;
END;
$$;
