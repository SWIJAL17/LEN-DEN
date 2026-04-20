-- ============================================================
-- MULTI-TIERED MICRO-LENDING PLATFORM
-- PostgreSQL Database Schema
-- Normalized to 3NF | ACID Compliant | Production-Ready
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. USERS TABLE
-- ============================================================
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name            VARCHAR(100) NOT NULL,
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255),               -- NULL for Google OAuth users
    google_id       VARCHAR(255) UNIQUE,         -- NULL for email/password users
    role            VARCHAR(20) CHECK (role IN ('user', 'borrower', 'lender', 'admin')) DEFAULT 'user',
    phone           VARCHAR(20),
    avatar_url      TEXT,
    wallet_balance  DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    credit_score    INTEGER DEFAULT 650 CHECK (credit_score BETWEEN 300 AND 900),
    kyc_verified    BOOLEAN DEFAULT FALSE,
    is_active       BOOLEAN DEFAULT TRUE,
    otp             VARCHAR(10),
    otp_expires_at  TIMESTAMP WITH TIME ZONE,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_google_id ON users(google_id);

-- ============================================================
-- 2. LOANS TABLE
-- ============================================================
CREATE TABLE loans (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    borrower_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(200) NOT NULL,
    description     TEXT,
    amount          DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
    funded_amount   DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
    interest_rate   DECIMAL(5, 2) NOT NULL CHECK (interest_rate > 0 AND interest_rate <= 36),
    tenure_months   INTEGER NOT NULL CHECK (tenure_months BETWEEN 1 AND 60),
    purpose         VARCHAR(100),
    risk_score      VARCHAR(10) CHECK (risk_score IN ('low', 'medium', 'high')) DEFAULT 'medium',
    status          VARCHAR(20) CHECK (status IN (
                        'pending',       -- Awaiting admin approval
                        'approved',      -- Approved, open for funding
                        'fully_funded',  -- Fully funded by lenders
                        'active',        -- Disbursed, repayment in progress
                        'completed',     -- All repayments done
                        'defaulted',     -- Borrower defaulted
                        'rejected'       -- Rejected by admin
                    )) DEFAULT 'pending',
    approved_by     UUID REFERENCES users(id),
    approved_at     TIMESTAMP WITH TIME ZONE,
    funded_at       TIMESTAMP WITH TIME ZONE,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_loans_borrower ON loans(borrower_id);
CREATE INDEX idx_loans_status ON loans(status);
CREATE INDEX idx_loans_risk ON loans(risk_score);
CREATE INDEX idx_loans_created ON loans(created_at DESC);

-- ============================================================
-- 3. LOAN CONTRIBUTIONS (Fractional Funding)
-- ============================================================
CREATE TABLE loan_contributions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_id         UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    lender_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount          DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
    expected_return DECIMAL(15, 2),      -- Pre-calculated return with interest
    actual_return   DECIMAL(15, 2) DEFAULT 0.00,
    status          VARCHAR(20) CHECK (status IN ('active', 'completed', 'defaulted')) DEFAULT 'active',
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Prevent same lender from funding same loan twice (they can increase via new contribution)
    CONSTRAINT unique_lender_loan UNIQUE (loan_id, lender_id)
);

CREATE INDEX idx_contributions_loan ON loan_contributions(loan_id);
CREATE INDEX idx_contributions_lender ON loan_contributions(lender_id);

-- ============================================================
-- 4. REPAYMENTS TABLE
-- ============================================================
CREATE TABLE repayments (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_id         UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    installment_no  INTEGER NOT NULL,
    amount_due      DECIMAL(15, 2) NOT NULL,
    amount_paid     DECIMAL(15, 2) DEFAULT 0.00,
    principal       DECIMAL(15, 2) NOT NULL,
    interest        DECIMAL(15, 2) NOT NULL,
    penalty         DECIMAL(15, 2) DEFAULT 0.00,
    due_date        DATE NOT NULL,
    paid_date       TIMESTAMP WITH TIME ZONE,
    status          VARCHAR(20) CHECK (status IN ('upcoming', 'paid', 'overdue', 'partial')) DEFAULT 'upcoming',
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT unique_installment UNIQUE (loan_id, installment_no)
);

CREATE INDEX idx_repayments_loan ON repayments(loan_id);
CREATE INDEX idx_repayments_due ON repayments(due_date);
CREATE INDEX idx_repayments_status ON repayments(status);

-- ============================================================
-- 5. TRANSACTIONS TABLE (Wallet Ledger)
-- ============================================================
CREATE TABLE transactions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type            VARCHAR(30) CHECK (type IN (
                        'deposit',
                        'withdrawal',
                        'loan_funding',      -- Lender funds a loan
                        'loan_disbursement', -- Borrower receives funds
                        'repayment_out',     -- Borrower pays installment
                        'repayment_in',      -- Lender receives repayment
                        'penalty',
                        'refund'
                    )) NOT NULL,
    amount          DECIMAL(15, 2) NOT NULL,
    balance_after   DECIMAL(15, 2) NOT NULL,
    reference_id    UUID,                      -- Links to loan/repayment ID
    description     TEXT,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_transactions_user ON transactions(user_id);
CREATE INDEX idx_transactions_type ON transactions(type);
CREATE INDEX idx_transactions_created ON transactions(created_at DESC);

-- ============================================================
-- 6. NOTIFICATIONS TABLE
-- ============================================================
CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(200) NOT NULL,
    message         TEXT NOT NULL,
    type            VARCHAR(30) CHECK (type IN ('info', 'success', 'warning', 'error')) DEFAULT 'info',
    is_read         BOOLEAN DEFAULT FALSE,
    reference_id    UUID,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_notifications_user ON notifications(user_id, is_read);

-- ============================================================
-- 7. AUDIT LOG TABLE (Shadow Table for Financial Events)
-- ============================================================
CREATE TABLE audit_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name      VARCHAR(50) NOT NULL,
    record_id       UUID NOT NULL,
    action          VARCHAR(10) NOT NULL,   -- INSERT, UPDATE, DELETE
    old_data        JSONB,
    new_data        JSONB,
    changed_by      UUID,
    created_at      TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_audit_table ON audit_log(table_name, record_id);

-- ============================================================
-- STORED PROCEDURE: Calculate Compound Interest
-- Returns total repayable amount with monthly compound interest
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_compound_interest(
    p_principal DECIMAL,
    p_annual_rate DECIMAL,    -- Annual interest rate (e.g., 12 for 12%)
    p_months INTEGER
)
RETURNS TABLE (
    total_amount DECIMAL,
    total_interest DECIMAL,
    monthly_emi DECIMAL
) AS $$
DECLARE
    v_monthly_rate DECIMAL;
    v_total DECIMAL;
    v_emi DECIMAL;
BEGIN
    v_monthly_rate := p_annual_rate / 12 / 100;
    
    -- Compound interest formula: A = P * (1 + r)^n
    v_total := p_principal * POWER(1 + v_monthly_rate, p_months);
    
    -- EMI formula: EMI = P * r * (1+r)^n / ((1+r)^n - 1)
    IF v_monthly_rate > 0 THEN
        v_emi := p_principal * v_monthly_rate * POWER(1 + v_monthly_rate, p_months) 
                 / (POWER(1 + v_monthly_rate, p_months) - 1);
    ELSE
        v_emi := p_principal / p_months;
    END IF;
    
    total_amount := ROUND(v_total, 2);
    total_interest := ROUND(v_total - p_principal, 2);
    monthly_emi := ROUND(v_emi, 2);
    
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- STORED PROCEDURE: Generate Repayment Schedule
-- Creates all installment rows for a loan after it's fully funded
-- ============================================================
CREATE OR REPLACE FUNCTION generate_repayment_schedule(p_loan_id UUID)
RETURNS VOID AS $$
DECLARE
    v_loan RECORD;
    v_emi DECIMAL;
    v_balance DECIMAL;
    v_monthly_rate DECIMAL;
    v_interest_part DECIMAL;
    v_principal_part DECIMAL;
    i INTEGER;
BEGIN
    -- Get loan details
    SELECT amount, interest_rate, tenure_months INTO v_loan
    FROM loans WHERE id = p_loan_id;
    
    v_monthly_rate := v_loan.interest_rate / 12 / 100;
    v_balance := v_loan.amount;
    
    -- Calculate EMI
    IF v_monthly_rate > 0 THEN
        v_emi := v_loan.amount * v_monthly_rate * POWER(1 + v_monthly_rate, v_loan.tenure_months) 
                 / (POWER(1 + v_monthly_rate, v_loan.tenure_months) - 1);
    ELSE
        v_emi := v_loan.amount / v_loan.tenure_months;
    END IF;
    
    v_emi := ROUND(v_emi, 2);
    
    -- Generate each installment
    FOR i IN 1..v_loan.tenure_months LOOP
        v_interest_part := ROUND(v_balance * v_monthly_rate, 2);
        v_principal_part := v_emi - v_interest_part;
        
        -- Last installment adjusts for rounding
        IF i = v_loan.tenure_months THEN
            v_principal_part := v_balance;
            v_emi := v_principal_part + v_interest_part;
        END IF;
        
        INSERT INTO repayments (loan_id, installment_no, amount_due, principal, interest, due_date)
        VALUES (
            p_loan_id,
            i,
            v_emi,
            v_principal_part,
            v_interest_part,
            CURRENT_DATE + (i * INTERVAL '1 month')
        );
        
        v_balance := v_balance - v_principal_part;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TRIGGER: Auto-update loan status when fully funded
-- ============================================================
CREATE OR REPLACE FUNCTION trg_check_loan_fully_funded()
RETURNS TRIGGER AS $$
BEGIN
    -- After a new contribution, check if loan is fully funded
    UPDATE loans 
    SET status = 'fully_funded',
        funded_at = NOW(),
        updated_at = NOW()
    WHERE id = NEW.loan_id 
      AND funded_amount >= amount 
      AND status = 'approved';
    
    -- If loan just became fully funded, generate repayment schedule
    IF FOUND THEN
        PERFORM generate_repayment_schedule(NEW.loan_id);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_loan_status_update
AFTER INSERT ON loan_contributions
FOR EACH ROW
EXECUTE FUNCTION trg_check_loan_fully_funded();

-- ============================================================
-- TRIGGER: Apply late payment penalty (5% of overdue amount)
-- Runs daily via scheduled job or on repayment check
-- ============================================================
CREATE OR REPLACE FUNCTION trg_apply_late_penalty()
RETURNS TRIGGER AS $$
BEGIN
    -- When a repayment is marked as paid, check if it was late
    IF NEW.status = 'paid' AND NEW.paid_date > (NEW.due_date + INTERVAL '1 day') THEN
        -- Calculate penalty: 2% of amount_due per day late, max 25%
        NEW.penalty := LEAST(
            ROUND(NEW.amount_due * 0.02 * EXTRACT(DAY FROM (NEW.paid_date - NEW.due_date::timestamp)), 2),
            ROUND(NEW.amount_due * 0.25, 2)
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_late_payment_penalty
BEFORE UPDATE ON repayments
FOR EACH ROW
WHEN (NEW.status = 'paid' AND OLD.status != 'paid')
EXECUTE FUNCTION trg_apply_late_penalty();

-- ============================================================
-- TRIGGER: Audit log for loans table changes
-- ============================================================
CREATE OR REPLACE FUNCTION trg_audit_loans()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, record_id, action, new_data)
        VALUES ('loans', NEW.id, 'INSERT', row_to_json(NEW)::jsonb);
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_data, new_data)
        VALUES ('loans', NEW.id, 'UPDATE', row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, record_id, action, old_data)
        VALUES ('loans', OLD.id, 'DELETE', row_to_json(OLD)::jsonb);
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_loans
AFTER INSERT OR UPDATE OR DELETE ON loans
FOR EACH ROW
EXECUTE FUNCTION trg_audit_loans();

-- ============================================================
-- TRIGGER: Update updated_at timestamp automatically
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_loans_updated_at BEFORE UPDATE ON loans
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- SEED DATA: Admin user
-- ============================================================
-- Password: admin123 (bcrypt hash)
INSERT INTO users (name, email, password_hash, role, wallet_balance, kyc_verified)
VALUES (
    'Platform Admin',
    'admin@lenden.com',
    '$2a$12$LJ3m4ys3Lkz8nXhAeCMwYOmKk3GUq3Rx8MqR8rJ5J8KvQa9DIjbOi',
    'admin',
    0.00,
    TRUE
);

-- ============================================================
-- ADVANCED HARDENING PROCEDURES & TRIGGERS
-- ============================================================

-- 1. Concurrency & Funding Validation
CREATE OR REPLACE FUNCTION trg_validate_loan_funding()
RETURNS TRIGGER AS $$
DECLARE
    v_loan_amount DECIMAL;
    v_current_funded DECIMAL;
    v_borrower_id UUID;
    v_lender_balance DECIMAL;
BEGIN
    SELECT amount, funded_amount, borrower_id INTO v_loan_amount, v_current_funded, v_borrower_id
    FROM loans WHERE id = NEW.loan_id FOR UPDATE;

    IF v_borrower_id = NEW.lender_id THEN RAISE EXCEPTION 'Borrowers cannot fund their own loans.'; END IF;
    IF v_current_funded + NEW.amount > v_loan_amount THEN RAISE EXCEPTION 'Contribution exceeds remaining loan amount.'; END IF;

    SELECT wallet_balance INTO v_lender_balance FROM users WHERE id = NEW.lender_id FOR UPDATE;
    IF v_lender_balance < NEW.amount THEN RAISE EXCEPTION 'Insufficient wallet balance to fund this loan.'; END IF;

    SELECT total_amount INTO NEW.expected_return 
    FROM calculate_compound_interest(NEW.amount, (SELECT interest_rate FROM loans WHERE id = NEW.loan_id), (SELECT tenure_months FROM loans WHERE id = NEW.loan_id));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_loan_funding_trigger ON loan_contributions;
CREATE TRIGGER trg_validate_loan_funding_trigger BEFORE INSERT ON loan_contributions FOR EACH ROW EXECUTE FUNCTION trg_validate_loan_funding();

-- 2. Automated Ledger & Wallet Deduction
CREATE OR REPLACE FUNCTION trg_execute_loan_funding()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE users SET wallet_balance = wallet_balance - NEW.amount WHERE id = NEW.lender_id;
    INSERT INTO transactions (user_id, type, amount, balance_after, reference_id, description)
    VALUES (NEW.lender_id, 'loan_funding', NEW.amount, (SELECT wallet_balance FROM users WHERE id = NEW.lender_id), NEW.loan_id, 'Funded loan ' || NEW.loan_id);
    UPDATE loans SET funded_amount = funded_amount + NEW.amount WHERE id = NEW.loan_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_execute_loan_funding_trigger ON loan_contributions;
CREATE TRIGGER trg_execute_loan_funding_trigger AFTER INSERT ON loan_contributions FOR EACH ROW EXECUTE FUNCTION trg_execute_loan_funding();

-- 3. Automated Loan Disbursement
CREATE OR REPLACE FUNCTION trg_disburse_loan()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status IN ('fully_funded', 'active') AND OLD.status NOT IN ('fully_funded', 'active') THEN
        UPDATE users SET wallet_balance = wallet_balance + NEW.amount WHERE id = NEW.borrower_id;
        INSERT INTO transactions (user_id, type, amount, balance_after, reference_id, description)
        VALUES (NEW.borrower_id, 'loan_disbursement', NEW.amount, (SELECT wallet_balance FROM users WHERE id = NEW.borrower_id), NEW.id, 'Loan disbursement');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_disburse_loan_trigger ON loans;
CREATE TRIGGER trg_disburse_loan_trigger AFTER UPDATE ON loans FOR EACH ROW EXECUTE FUNCTION trg_disburse_loan();

-- 4. Automated Repayment Distribution
CREATE OR REPLACE FUNCTION trg_process_repayment()
RETURNS TRIGGER AS $$
DECLARE
    v_borrower_id UUID;
    v_borrower_balance DECIMAL;
    v_contribution RECORD;
    v_lender_share DECIMAL;
    v_loan_amount DECIMAL;
BEGIN
    IF NEW.status = 'paid' AND OLD.status != 'paid' THEN
        SELECT borrower_id, amount INTO v_borrower_id, v_loan_amount FROM loans WHERE id = NEW.loan_id;
        SELECT wallet_balance INTO v_borrower_balance FROM users WHERE id = v_borrower_id FOR UPDATE;

        IF v_borrower_balance < NEW.amount_due THEN RAISE EXCEPTION 'Insufficient wallet balance for repayment. Required: %', NEW.amount_due; END IF;

        UPDATE users SET wallet_balance = wallet_balance - NEW.amount_due WHERE id = v_borrower_id;
        INSERT INTO transactions (user_id, type, amount, balance_after, reference_id, description)
        VALUES (v_borrower_id, 'repayment_out', NEW.amount_due, (SELECT wallet_balance FROM users WHERE id = v_borrower_id), NEW.id, 'Paid installment ' || NEW.installment_no);

        FOR v_contribution IN (SELECT id, lender_id, amount FROM loan_contributions WHERE loan_id = NEW.loan_id) LOOP
            v_lender_share := ROUND(NEW.amount_due * (v_contribution.amount / v_loan_amount), 2);
            UPDATE users SET wallet_balance = wallet_balance + v_lender_share WHERE id = v_contribution.lender_id;
            UPDATE loan_contributions SET actual_return = COALESCE(actual_return, 0) + v_lender_share WHERE id = v_contribution.id;
            INSERT INTO transactions (user_id, type, amount, balance_after, reference_id, description)
            VALUES (v_contribution.lender_id, 'repayment_in', v_lender_share, (SELECT wallet_balance FROM users WHERE id = v_contribution.lender_id), NEW.id, 'Received repayment for loan');
        END LOOP;

        NEW.paid_date := NOW();
        NEW.amount_paid := NEW.amount_due;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_process_repayment_trigger ON repayments;
CREATE TRIGGER trg_process_repayment_trigger BEFORE UPDATE ON repayments FOR EACH ROW EXECUTE FUNCTION trg_process_repayment();

-- 5. Automated Loan Completion
CREATE OR REPLACE FUNCTION trg_check_loan_completion()
RETURNS TRIGGER AS $$
DECLARE
    v_unpaid_count INTEGER;
BEGIN
    IF NEW.status = 'paid' THEN
        SELECT COUNT(*) INTO v_unpaid_count FROM repayments WHERE loan_id = NEW.loan_id AND status != 'paid';
        IF v_unpaid_count = 0 THEN
            UPDATE loans SET status = 'completed' WHERE id = NEW.loan_id;
            UPDATE loan_contributions SET status = 'completed' WHERE loan_id = NEW.loan_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_loan_completion_trigger ON repayments;
CREATE TRIGGER trg_check_loan_completion_trigger AFTER UPDATE ON repayments FOR EACH ROW EXECUTE FUNCTION trg_check_loan_completion();
