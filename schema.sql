-- ============================================================================
--  Multi-Tiered Micro-Lending Platform
--  schema.sql  |  Group ID: 13  |  PostgreSQL 16
-- ============================================================================
--
--  Table creation order (respects all FK dependencies)
--  ────────────────────────────────────────────────────
--   1.  users
--   2.  loans
--   3.  loan_contributions
--   4.  escrow_ledger
--   5.  repayment_schedule
--   6.  emi_distributions
--   7.  wallet_transactions
--   8.  platform_revenue
--   9.  audit_log
--
--  Constraint enforcement note
--  ───────────────────────────
--  Constraints that require cross-table aggregation cannot be expressed as
--  column-level CHECKs in PostgreSQL.  The following rules are enforced
--  exclusively by triggers (see triggers.sql):
--
--    • Wallet balance sufficiency before pledge           [T-BALANCE]
--    • 50 % max single-lender exposure per loan          [T-EXPOSURE]
--    • Max 3 concurrent active lending positions         [T-POSITIONS]
--    • KYC = VERIFIED gate for borrow / lend             [T-KYC]
--    • Cooling-off period enforcement                    [T-COOLOFF]
--    • 24-hour pledge retraction window                  [T-RETRACT]
--    • No self-funding (lender ≠ borrower)               [T-SELFFUND]
--    • Role-state machine transitions                    [T-ROLE]
--    • Credit score updates on repayment events          [T-SCORE]
-- ============================================================================


-- ── Extensions ───────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pg_trgm";    -- trigram search on loan titles


-- ============================================================================
--  1.  USERS
--
--  Role-state machine
--  ──────────────────
--   NEUTRAL ──[opens loan]────────────────→ BORROWER
--   BORROWER ──[loan fully repaid]────────→ NEUTRAL  (+48 h cooling-off)
--   NEUTRAL ──[pledges funds]─────────────→ LENDER
--   LENDER ──[all principal returned]─────→ NEUTRAL
--
--  KYC gate
--  ────────
--   UNVERIFIED : registered; cannot borrow or lend
--   VERIFIED   : cleared for all financial activity
--   SUSPENDED  : fully locked out (fraud / default / admin action)
--
--  Credit score: 300 (floor) – 850 (ceiling)
--   +5  per on-time EMI payment
--   −20 per installment that becomes OVERDUE
-- ============================================================================
CREATE TABLE users (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    email               VARCHAR(255)    NOT NULL,
    password_hash       TEXT            NOT NULL,
    full_name           VARCHAR(255)    NOT NULL,

    wallet_balance      NUMERIC(15, 2)  NOT NULL DEFAULT 0.00,

    kyc_status          VARCHAR(12)     NOT NULL DEFAULT 'UNVERIFIED',
    role_state          VARCHAR(10)     NOT NULL DEFAULT 'NEUTRAL',
    cooling_off_until   TIMESTAMPTZ     DEFAULT NULL,
    -- NULL  = no active restriction
    -- set   = user must wait until this timestamp before becoming BORROWER/LENDER

    credit_score        SMALLINT        NOT NULL DEFAULT 650,

    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_users_email
        UNIQUE (email),

    CONSTRAINT chk_wallet_non_negative
        CHECK (wallet_balance >= 0),

    CONSTRAINT chk_kyc_status
        CHECK (kyc_status IN ('UNVERIFIED', 'VERIFIED', 'SUSPENDED')),

    CONSTRAINT chk_role_state
        CHECK (role_state IN ('NEUTRAL', 'BORROWER', 'LENDER')),

    CONSTRAINT chk_credit_score_range
        CHECK (credit_score BETWEEN 300 AND 850),

    -- cooling_off_until is only meaningful when role = NEUTRAL
    CONSTRAINT chk_cooling_off_only_when_neutral
        CHECK (cooling_off_until IS NULL OR role_state = 'NEUTRAL')
);


-- ============================================================================
--  2.  LOANS
--
--  Status machine
--  ──────────────
--   UNDER_REVIEW ──[admin approves]────────────────────→ OPEN
--   UNDER_REVIEW ──[admin rejects]─────────────────────→ CANCELLED
--   OPEN ──[deadline passes, funded < min_funding_pct]─→ CANCELLED
--   OPEN ──[deadline passes, funded ≥ min_funding_pct]─→ ACTIVE  (partial ok)
--   OPEN ──[funded_amount = requested_amount]───────────→ ACTIVE  (fully funded)
--   ACTIVE ──[all EMIs paid]────────────────────────────→ COMPLETED
--
--  Partial funding behaviour
--  ─────────────────────────
--  If a loan closes with (min_funding_pct ≤ funded < requested), the
--  disbursed_amount is set to funded_amount and the repayment schedule is
--  regenerated from that smaller principal.
--
--  Per-loan rule snapshot (stored at creation for historical accuracy)
--  ──────────────────────────────────────────────────────────────────
--  min_funding_pct   = 20 %  — below this → CANCELLED, escrow refunded
--  max_lender_pct    = 50 %  — hard cap on single lender's share
--  grace_period_days = 3     — buffer before PENDING → OVERDUE
--  late_penalty_pct  = 2 %   — surcharge on overdue EMI amount
--  platform_fee_pct  = 1 %   — withheld from lender interest per EMI
-- ============================================================================
CREATE TABLE loans (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    borrower_id             UUID            NOT NULL REFERENCES users(id),

    title                   VARCHAR(255)    NOT NULL,
    description             TEXT,
    category                VARCHAR(12)     NOT NULL DEFAULT 'PERSONAL',
    -- PERSONAL | BUSINESS | EDUCATION | MEDICAL | EMERGENCY

    requested_amount        NUMERIC(15, 2)  NOT NULL,
    funded_amount           NUMERIC(15, 2)  NOT NULL DEFAULT 0.00,
    disbursed_amount        NUMERIC(15, 2)  DEFAULT NULL,
    -- Set at disbursement; may be < requested_amount on partial funding

    interest_rate_annual    NUMERIC(5, 2)   NOT NULL,
    -- Reducing-balance rate; e.g. 12.00 = 12 % p.a.
    tenure_months           SMALLINT        NOT NULL,
    funding_deadline        TIMESTAMPTZ     NOT NULL,

    -- Platform rule snapshot ──────────────────────────────────────────────────
    min_funding_pct         NUMERIC(5, 2)   NOT NULL DEFAULT 20.00,
    max_lender_pct          NUMERIC(5, 2)   NOT NULL DEFAULT 50.00,
    grace_period_days       SMALLINT        NOT NULL DEFAULT 3,
    late_penalty_pct        NUMERIC(5, 2)   NOT NULL DEFAULT 2.00,
    platform_fee_pct        NUMERIC(5, 2)   NOT NULL DEFAULT 1.00,

    -- Review metadata ─────────────────────────────────────────────────────────
    reviewed_by             UUID            DEFAULT NULL REFERENCES users(id),
    reviewed_at             TIMESTAMPTZ     DEFAULT NULL,
    rejection_reason        TEXT            DEFAULT NULL,

    status                  VARCHAR(14)     NOT NULL DEFAULT 'UNDER_REVIEW',

    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    -- ── Constraints ───────────────────────────────────────────────────────────
    CONSTRAINT chk_loan_category
        CHECK (category IN ('PERSONAL','BUSINESS','EDUCATION','MEDICAL','EMERGENCY')),

    CONSTRAINT chk_requested_positive
        CHECK (requested_amount > 0),

    CONSTRAINT chk_funded_within_requested
        CHECK (funded_amount >= 0 AND funded_amount <= requested_amount),

    CONSTRAINT chk_disbursed_positive
        CHECK (disbursed_amount IS NULL OR disbursed_amount > 0),

    CONSTRAINT chk_disbursed_lte_funded
        CHECK (disbursed_amount IS NULL OR disbursed_amount <= funded_amount),

    CONSTRAINT chk_interest_positive
        CHECK (interest_rate_annual > 0),

    CONSTRAINT chk_tenure_positive
        CHECK (tenure_months > 0),

    CONSTRAINT chk_deadline_after_creation
        CHECK (funding_deadline > created_at),

    CONSTRAINT chk_min_funding_pct_range
        CHECK (min_funding_pct > 0 AND min_funding_pct <= 100),

    CONSTRAINT chk_max_lender_pct_range
        CHECK (max_lender_pct > 0 AND max_lender_pct <= 100),

    CONSTRAINT chk_grace_non_negative
        CHECK (grace_period_days >= 0),

    CONSTRAINT chk_late_penalty_non_negative
        CHECK (late_penalty_pct >= 0),

    CONSTRAINT chk_platform_fee_non_negative
        CHECK (platform_fee_pct >= 0),

    CONSTRAINT chk_loan_status
        CHECK (status IN ('UNDER_REVIEW','OPEN','ACTIVE',
                          'COMPLETED','CANCELLED','EXPIRED')),

    -- disbursed_amount must be set once the loan goes ACTIVE or COMPLETED
    CONSTRAINT chk_disbursed_set_when_active
        CHECK (
            status NOT IN ('ACTIVE','COMPLETED')
            OR disbursed_amount IS NOT NULL
        ),

    CONSTRAINT chk_rejection_reason_only_on_cancel
        CHECK (rejection_reason IS NULL OR status = 'CANCELLED'),

    CONSTRAINT chk_review_fields_consistent
        CHECK (
            (reviewed_by IS NULL AND reviewed_at IS NULL)
         OR (reviewed_by IS NOT NULL AND reviewed_at IS NOT NULL)
        )
);

-- A borrower may only have ONE loan in UNDER_REVIEW or OPEN state at a time
CREATE UNIQUE INDEX uq_one_pending_loan_per_borrower
    ON loans (borrower_id)
    WHERE status IN ('UNDER_REVIEW', 'OPEN');


-- ============================================================================
--  3.  LOAN CONTRIBUTIONS  (Lender ↔ Loan  many-to-many)
--
--  One row per (lender, loan) pair — the UNIQUE constraint enforces this.
--
--  Status machine
--  ──────────────
--   ESCROWED  → funds locked; loan still OPEN
--   DISBURSED → funds released to borrower; repayment ongoing
--   RETURNED  → principal fully recovered via EMI distributions
--   RETRACTED → lender withdrew pledge within 24-hour window
--
--  Cross-table rules enforced by triggers:
--   [T-EXPOSURE]  pledged_amount ≤ loan.max_lender_pct % of requested_amount
--   [T-POSITIONS] lender has < 3 ESCROWED or DISBURSED contributions
--   [T-KYC]       lender.kyc_status = 'VERIFIED'
--   [T-COOLOFF]   lender not in cooling-off period
--   [T-SELFFUND]  lender_id ≠ loan.borrower_id
--   [T-BALANCE]   lender.wallet_balance ≥ pledged_amount
--   [T-RETRACT]   retraction only within 24 h of created_at, before DISBURSED
-- ============================================================================
CREATE TABLE loan_contributions (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id         UUID            NOT NULL REFERENCES loans(id),
    lender_id       UUID            NOT NULL REFERENCES users(id),

    pledged_amount  NUMERIC(15, 2)  NOT NULL,
    returned_amount NUMERIC(15, 2)  NOT NULL DEFAULT 0.00,
    -- Running principal recovered through EMI distributions

    status          VARCHAR(10)     NOT NULL DEFAULT 'ESCROWED',

    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    -- [T-RETRACT] compares NOW() against this timestamp

    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_one_contribution_per_lender_per_loan
        UNIQUE (loan_id, lender_id),

    CONSTRAINT chk_pledged_positive
        CHECK (pledged_amount > 0),

    CONSTRAINT chk_returned_within_pledged
        CHECK (returned_amount >= 0 AND returned_amount <= pledged_amount),

    CONSTRAINT chk_contribution_status
        CHECK (status IN ('ESCROWED','DISBURSED','RETURNED','RETRACTED')),

    CONSTRAINT chk_no_return_if_retracted
        CHECK (status != 'RETRACTED' OR returned_amount = 0)
);


-- ============================================================================
--  4.  ESCROW LEDGER
--
--  One LOCKED entry per loan_contribution.
--  Released in three scenarios:
--    DISBURSED        → loan met threshold; funds moved to borrower
--    LOAN_CANCELLED   → threshold not met or admin rejection
--    LENDER_RETRACTED → lender withdrew within 24-hour window
--
--  Once state = 'RELEASED', no further UPDATE is permitted
--  (enforced by trigger [T-ESCROW-IMMUTABLE] in triggers.sql).
-- ============================================================================
CREATE TABLE escrow_ledger (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    contribution_id     UUID            NOT NULL REFERENCES loan_contributions(id),
    loan_id             UUID            NOT NULL REFERENCES loans(id),
    lender_id           UUID            NOT NULL REFERENCES users(id),

    amount              NUMERIC(15, 2)  NOT NULL,

    state               VARCHAR(10)     NOT NULL DEFAULT 'LOCKED',
    -- LOCKED | RELEASED

    locked_at           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    released_at         TIMESTAMPTZ     DEFAULT NULL,
    release_reason      VARCHAR(20)     DEFAULT NULL,
    -- 'DISBURSED' | 'LOAN_CANCELLED' | 'LENDER_RETRACTED'

    CONSTRAINT chk_escrow_state
        CHECK (state IN ('LOCKED','RELEASED')),

    CONSTRAINT chk_escrow_amount_positive
        CHECK (amount > 0),

    CONSTRAINT chk_release_fields_consistent
        CHECK (
            (state = 'LOCKED'
                AND released_at IS NULL
                AND release_reason IS NULL)
         OR (state = 'RELEASED'
                AND released_at IS NOT NULL
                AND release_reason IS NOT NULL)
        ),

    CONSTRAINT chk_release_reason_values
        CHECK (release_reason IS NULL OR release_reason IN (
            'DISBURSED','LOAN_CANCELLED','LENDER_RETRACTED'
        ))
);


-- ============================================================================
--  5.  REPAYMENT SCHEDULE
--
--  Generated by proc_generate_repayment_schedule() at loan disbursal.
--
--  Reducing-balance EMI formula
--  ─────────────────────────────
--   r   = interest_rate_annual / 12 / 100
--   EMI = P × r × (1+r)^n  /  ((1+r)^n − 1)
--
--  Where P = disbursed_amount (NOT requested_amount — handles partial funding).
--  Each row stores the full amortisation breakdown for one installment.
--
--  penalty_amount starts at 0.00 and is set by
--  proc_mark_overdue_installments() when due_date + grace_period_days passes.
-- ============================================================================
CREATE TABLE repayment_schedule (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id             UUID            NOT NULL REFERENCES loans(id),

    installment_no      SMALLINT        NOT NULL,
    due_date            DATE            NOT NULL,

    emi_amount          NUMERIC(15, 2)  NOT NULL,
    principal_component NUMERIC(15, 2)  NOT NULL,
    interest_component  NUMERIC(15, 2)  NOT NULL,
    opening_balance     NUMERIC(15, 2)  NOT NULL,  -- outstanding before this EMI
    closing_balance     NUMERIC(15, 2)  NOT NULL,  -- outstanding after this EMI

    penalty_amount      NUMERIC(15, 2)  NOT NULL DEFAULT 0.00,
    -- Populated by proc_mark_overdue_installments

    status              VARCHAR(8)      NOT NULL DEFAULT 'PENDING',
    -- PENDING | PAID | OVERDUE

    paid_at             TIMESTAMPTZ     DEFAULT NULL,

    CONSTRAINT uq_installment_per_loan
        UNIQUE (loan_id, installment_no),

    CONSTRAINT chk_installment_positive
        CHECK (installment_no > 0),

    CONSTRAINT chk_emi_positive
        CHECK (emi_amount > 0),

    CONSTRAINT chk_components_add_up
        -- ±0.02 tolerance for floating-point rounding in EMI formula
        CHECK (ABS((principal_component + interest_component) - emi_amount) <= 0.02),

    CONSTRAINT chk_balances_positive
        CHECK (opening_balance > 0 AND closing_balance >= 0),

    CONSTRAINT chk_principal_reduces_balance
        CHECK (ABS((opening_balance - principal_component) - closing_balance) <= 0.02),

    CONSTRAINT chk_penalty_non_negative
        CHECK (penalty_amount >= 0),

    CONSTRAINT chk_schedule_status
        CHECK (status IN ('PENDING','PAID','OVERDUE')),

    CONSTRAINT chk_paid_at_iff_paid
        CHECK (
            (status = 'PAID'  AND paid_at IS NOT NULL)
         OR (status != 'PAID' AND paid_at IS NULL)
        )
);


-- ============================================================================
--  6.  EMI DISTRIBUTIONS  (pro-rata lender credit per installment)
--
--  One row per (installment, lender).
--  Populated atomically by proc_process_emi_payment().
--
--  Pro-rata formula
--  ────────────────
--   contribution_ratio  = pledged_amount / disbursed_amount
--   principal_share     = principal_component × ratio
--   gross_interest      = interest_component  × ratio
--   platform_fee_amount = gross_interest × platform_fee_pct / 100
--   net_interest_share  = gross_interest − platform_fee_amount
--   total_credited      = principal_share + net_interest_share
--
--  The lender's wallet_balance is incremented by total_credited.
--  platform_fee_amount is written to platform_revenue.
-- ============================================================================
CREATE TABLE emi_distributions (
    id                      UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    schedule_id             UUID            NOT NULL REFERENCES repayment_schedule(id),
    loan_id                 UUID            NOT NULL REFERENCES loans(id),
    contribution_id         UUID            NOT NULL REFERENCES loan_contributions(id),
    lender_id               UUID            NOT NULL REFERENCES users(id),

    contribution_ratio      NUMERIC(12, 10) NOT NULL,
    -- e.g. 0.3500000000 means this lender funded 35 % of the loan

    principal_share         NUMERIC(15, 2)  NOT NULL,
    gross_interest_share    NUMERIC(15, 2)  NOT NULL,
    platform_fee_amount     NUMERIC(15, 2)  NOT NULL DEFAULT 0.00,
    net_interest_share      NUMERIC(15, 2)  NOT NULL,
    total_credited          NUMERIC(15, 2)  NOT NULL,
    -- Amount actually credited to lender wallet
    -- = principal_share + net_interest_share

    distributed_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_distribution_per_lender_per_installment
        UNIQUE (schedule_id, lender_id),

    CONSTRAINT chk_ratio_valid
        CHECK (contribution_ratio > 0 AND contribution_ratio <= 1),

    CONSTRAINT chk_shares_non_negative
        CHECK (
            principal_share     >= 0
            AND gross_interest_share >= 0
            AND platform_fee_amount  >= 0
            AND net_interest_share   >= 0
        ),

    CONSTRAINT chk_net_lte_gross
        CHECK (net_interest_share <= gross_interest_share),

    CONSTRAINT chk_total_credited_consistent
        CHECK (ABS((principal_share + net_interest_share) - total_credited) <= 0.02)
);


-- ============================================================================
--  7.  WALLET TRANSACTIONS  (immutable double-entry ledger)
--
--  Every wallet_balance change produces exactly ONE row here.
--  No UPDATE or DELETE ever permitted — enforced by trigger
--  [T-WALLET-IMMUTABLE] in triggers.sql.
--
--  Signed amounts:
--   positive → credit (funds entered wallet)
--   negative → debit  (funds left wallet)
--
--  Invariant: balance_after = balance_before + amount  (±0.01 tolerance)
-- ============================================================================
CREATE TABLE wallet_transactions (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL REFERENCES users(id),

    transaction_type    VARCHAR(26)     NOT NULL,

    amount              NUMERIC(15, 2)  NOT NULL,
    -- Positive = credit, Negative = debit

    balance_before      NUMERIC(15, 2)  NOT NULL,
    balance_after       NUMERIC(15, 2)  NOT NULL,

    reference_id        UUID            DEFAULT NULL,
    -- loans.id | loan_contributions.id | repayment_schedule.id

    description         TEXT            DEFAULT NULL,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_tx_type CHECK (
        transaction_type IN (
            'DEPOSIT',                -- user tops up wallet
            'WITHDRAWAL',             -- user withdraws to bank
            'PLEDGE_TO_ESCROW',       -- lender pledges: wallet → escrow  (debit)
            'PLEDGE_RETRACTION',      -- lender retracts: escrow → wallet (credit)
            'ESCROW_REFUND',          -- refund on loan cancel / threshold fail
            'LOAN_DISBURSEMENT',      -- borrower receives disbursed_amount (credit)
            'EMI_PAYMENT',            -- borrower pays installment (debit)
            'EMI_PRINCIPAL_RECEIPT',  -- lender recovers principal share (credit)
            'EMI_INTEREST_RECEIPT',   -- lender receives net interest (credit)
            'PENALTY_CHARGE',         -- late penalty charged to borrower (debit)
            'PLATFORM_FEE'            -- platform fee deducted (debit from interest)
        )
    ),

    CONSTRAINT chk_amount_nonzero
        CHECK (amount != 0),

    CONSTRAINT chk_balance_arithmetic
        CHECK (ABS((balance_before + amount) - balance_after) <= 0.01)
);


-- ============================================================================
--  8.  PLATFORM REVENUE
--
--  Append-only record of every platform fee collected on EMI interest.
--  Aggregated by v_platform_revenue_summary in views.sql.
-- ============================================================================
CREATE TABLE platform_revenue (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    loan_id             UUID            NOT NULL REFERENCES loans(id),
    schedule_id         UUID            NOT NULL REFERENCES repayment_schedule(id),
    contribution_id     UUID            NOT NULL REFERENCES loan_contributions(id),
    lender_id           UUID            NOT NULL REFERENCES users(id),

    fee_amount          NUMERIC(15, 2)  NOT NULL,
    fee_pct_applied     NUMERIC(5, 2)   NOT NULL,
    -- Snapshot of loan.platform_fee_pct at time of collection

    collected_at        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_fee_amount_positive
        CHECK (fee_amount > 0),

    CONSTRAINT chk_fee_pct_valid
        CHECK (fee_pct_applied > 0 AND fee_pct_applied <= 100)
);


-- ============================================================================
--  9.  AUDIT LOG  (immutable shadow table)
--
--  Populated by row-level triggers on:
--    users, loans, loan_contributions, escrow_ledger
--
--  Every INSERT / UPDATE / DELETE on those tables writes one row here with
--  full JSONB snapshots of the old and new row states.
--
--  No UPDATE or DELETE ever permitted — enforced by trigger
--  [T-AUDIT-IMMUTABLE] in triggers.sql.
--
--  changed_by is resolved from the PostgreSQL session variable:
--    SET LOCAL app.current_user_id = '<uuid>';
--  The application layer sets this at the start of every transaction.
-- ============================================================================
CREATE TABLE audit_log (
    id              BIGSERIAL       PRIMARY KEY,
    table_name      VARCHAR(30)     NOT NULL,
    record_id       UUID            NOT NULL,
    operation       VARCHAR(6)      NOT NULL,   -- INSERT | UPDATE | DELETE

    changed_by      UUID            DEFAULT NULL REFERENCES users(id),
    old_data        JSONB           DEFAULT NULL,  -- NULL on INSERT
    new_data        JSONB           DEFAULT NULL,  -- NULL on DELETE

    changed_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    db_user         TEXT            NOT NULL DEFAULT SESSION_USER,
    client_addr     INET            DEFAULT INET_CLIENT_ADDR(),

    CONSTRAINT chk_audit_operation
        CHECK (operation IN ('INSERT','UPDATE','DELETE')),

    CONSTRAINT chk_audit_data_present
        CHECK (
            (operation = 'INSERT' AND new_data IS NOT NULL)
         OR (operation = 'DELETE' AND old_data IS NOT NULL)
         OR (operation = 'UPDATE'
                AND old_data IS NOT NULL
                AND new_data IS NOT NULL)
        )
);


-- ============================================================================
--  INDEXES
-- ============================================================================

-- users
CREATE INDEX idx_users_kyc_role
    ON users (kyc_status, role_state);
CREATE INDEX idx_users_cooling_off
    ON users (cooling_off_until)
    WHERE cooling_off_until IS NOT NULL;

-- loans
CREATE INDEX idx_loans_borrower        ON loans (borrower_id);
CREATE INDEX idx_loans_status          ON loans (status);
CREATE INDEX idx_loans_category_status ON loans (category, status);
CREATE INDEX idx_loans_open_deadline
    ON loans (funding_deadline)
    WHERE status = 'OPEN';
CREATE INDEX idx_loans_title_trgm
    ON loans USING GIN (title gin_trgm_ops);

-- loan_contributions
CREATE INDEX idx_contributions_loan    ON loan_contributions (loan_id);
CREATE INDEX idx_contributions_lender  ON loan_contributions (lender_id);
CREATE INDEX idx_contributions_active
    ON loan_contributions (lender_id, status)
    WHERE status IN ('ESCROWED','DISBURSED');
-- ^ used by [T-POSITIONS] to count concurrent active positions

-- escrow_ledger
CREATE INDEX idx_escrow_locked_loan
    ON escrow_ledger (loan_id)
    WHERE state = 'LOCKED';

-- repayment_schedule
CREATE INDEX idx_schedule_loan         ON repayment_schedule (loan_id);
CREATE INDEX idx_schedule_pending_due
    ON repayment_schedule (due_date, loan_id)
    WHERE status = 'PENDING';
-- ^ used by proc_mark_overdue_installments for efficient scanning

-- emi_distributions
CREATE INDEX idx_emi_dist_loan         ON emi_distributions (loan_id);
CREATE INDEX idx_emi_dist_lender       ON emi_distributions (lender_id);

-- wallet_transactions
CREATE INDEX idx_wallet_user_chrono
    ON wallet_transactions (user_id, created_at DESC);
CREATE INDEX idx_wallet_reference
    ON wallet_transactions (reference_id)
    WHERE reference_id IS NOT NULL;

-- platform_revenue
CREATE INDEX idx_platform_revenue_loan ON platform_revenue (loan_id);

-- audit_log
CREATE INDEX idx_audit_record          ON audit_log (table_name, record_id);
CREATE INDEX idx_audit_changed_at      ON audit_log (changed_at DESC);
CREATE INDEX idx_audit_changed_by
    ON audit_log (changed_by)
    WHERE changed_by IS NOT NULL;


-- ============================================================================
--  SHARED UTILITY  —  auto-update updated_at
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_set_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_loans_set_updated_at
    BEFORE UPDATE ON loans
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_contributions_set_updated_at
    BEFORE UPDATE ON loan_contributions
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
