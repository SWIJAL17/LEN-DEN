-- ============================================================================
--  Multi-Tiered Micro-Lending Platform
--  views.sql  |  Group ID: 13  |  PostgreSQL 16
--  Run AFTER schema.sql, triggers.sql, and procedures.sql
-- ============================================================================
--
--  View index
--  ──────────
--  Marketplace & discovery
--   [V01]  v_loan_marketplace          — open loans visible to lenders
--   [V02]  v_loan_detail               — full loan snapshot (any status)
--
--  Borrower views
--   [V03]  v_borrower_dashboard        — active loan + repayment progress
--   [V04]  v_repayment_schedule_detail — full amortisation table per loan
--   [V05]  v_borrower_history          — all historical loans for a user
--
--  Lender views
--   [V06]  v_lender_portfolio          — all active/historical positions
--   [V07]  v_lender_returns            — per-contribution P&L breakdown
--   [V08]  v_emi_distribution_detail   — per-installment lender credit detail
--
--  Platform analytics
--   [V09]  v_platform_revenue_summary  — fee income aggregated by loan/month
--   [V10]  v_loan_funding_progress     — funding gap and lender breakdown
--   [V11]  v_credit_score_leaderboard  — borrower ranking by credit score
--   [V12]  v_overdue_watchlist         — all overdue installments + borrower info
--   [V13]  v_audit_trail               — human-readable audit log with diffs
--   [V14]  v_platform_health           — single-row executive summary
-- ============================================================================


-- ============================================================================
--  [V01]  LOAN MARKETPLACE
--  The primary read surface for lenders browsing investment opportunities.
--  Shows only OPEN loans that have not yet hit their funding deadline.
--  Excludes the borrower's identity to protect privacy (shows credit score only).
--  Ordered by funding completion percentage descending so nearly-funded loans
--  surface at the top (social-proof ordering).
-- ============================================================================
CREATE OR REPLACE VIEW v_loan_marketplace AS
SELECT
    l.id                                                        AS loan_id,
    l.title,
    l.category,
    l.description,

    -- Funding snapshot
    l.requested_amount,
    l.funded_amount,
    ROUND((l.funded_amount / l.requested_amount) * 100, 2)      AS funded_pct,
    l.requested_amount - l.funded_amount                        AS remaining_gap,

    -- Loan terms
    l.interest_rate_annual,
    l.tenure_months,
    l.funding_deadline,
    EXTRACT(EPOCH FROM (l.funding_deadline - NOW())) / 3600     AS hours_remaining,

    -- Platform rules visible to lenders
    l.min_funding_pct,
    l.max_lender_pct,
    l.platform_fee_pct,

    -- Borrower trust signal (no PII exposed)
    u.credit_score                                              AS borrower_credit_score,

    -- Lender count on this loan
    COUNT(lc.id)                                                AS lender_count,

    l.created_at                                                AS listed_at

FROM loans l
JOIN users u ON u.id = l.borrower_id
LEFT JOIN loan_contributions lc
       ON lc.loan_id = l.id
      AND lc.status  = 'ESCROWED'

WHERE l.status           = 'OPEN'
  AND l.funding_deadline > NOW()

GROUP BY
    l.id, l.title, l.category, l.description,
    l.requested_amount, l.funded_amount,
    l.interest_rate_annual, l.tenure_months,
    l.funding_deadline, l.min_funding_pct,
    l.max_lender_pct, l.platform_fee_pct,
    u.credit_score, l.created_at

ORDER BY funded_pct DESC, l.funding_deadline ASC;


-- ============================================================================
--  [V02]  LOAN DETAIL
--  Full loan snapshot used by both the borrower's detail page and the admin
--  review dashboard.  Includes reviewer identity and rejection reason.
-- ============================================================================
CREATE OR REPLACE VIEW v_loan_detail AS
SELECT
    l.id                                                        AS loan_id,
    l.status,
    l.category,
    l.title,
    l.description,

    -- Parties
    l.borrower_id,
    u_b.full_name                                               AS borrower_name,
    u_b.email                                                   AS borrower_email,
    u_b.credit_score                                            AS borrower_credit_score,
    u_b.kyc_status                                              AS borrower_kyc,

    -- Funding
    l.requested_amount,
    l.funded_amount,
    l.disbursed_amount,
    ROUND((l.funded_amount / NULLIF(l.requested_amount, 0)) * 100, 2)
                                                                AS funded_pct,

    -- Terms
    l.interest_rate_annual,
    l.tenure_months,
    l.funding_deadline,

    -- Platform rules
    l.min_funding_pct,
    l.max_lender_pct,
    l.grace_period_days,
    l.late_penalty_pct,
    l.platform_fee_pct,

    -- Review metadata
    l.reviewed_by,
    u_r.full_name                                               AS reviewer_name,
    l.reviewed_at,
    l.rejection_reason,

    -- Repayment progress (NULL for non-ACTIVE loans)
    (SELECT COUNT(*)
       FROM repayment_schedule rs
      WHERE rs.loan_id = l.id
        AND rs.status  = 'PAID')                                AS installments_paid,

    (SELECT COUNT(*)
       FROM repayment_schedule rs
      WHERE rs.loan_id = l.id
        AND rs.status  = 'PENDING')                             AS installments_pending,

    (SELECT COUNT(*)
       FROM repayment_schedule rs
      WHERE rs.loan_id = l.id
        AND rs.status  = 'OVERDUE')                             AS installments_overdue,

    l.created_at,
    l.updated_at

FROM loans l
JOIN  users u_b ON u_b.id = l.borrower_id
LEFT JOIN users u_r ON u_r.id = l.reviewed_by;


-- ============================================================================
--  [V03]  BORROWER DASHBOARD
--  One row per user, showing their current loan state and wallet summary.
--  Only surfaces users who are currently BORROWER or have an active loan.
-- ============================================================================
CREATE OR REPLACE VIEW v_borrower_dashboard AS
SELECT
    u.id                                                        AS user_id,
    u.full_name,
    u.email,
    u.wallet_balance,
    u.credit_score,
    u.cooling_off_until,

    -- Current loan
    l.id                                                        AS loan_id,
    l.status                                                    AS loan_status,
    l.title                                                     AS loan_title,
    l.requested_amount,
    l.disbursed_amount,
    l.funded_amount,
    l.interest_rate_annual,
    l.tenure_months,
    l.funding_deadline,

    -- Repayment summary
    (SELECT COUNT(*)
       FROM repayment_schedule rs
      WHERE rs.loan_id = l.id
        AND rs.status  = 'PAID')                                AS emis_paid,

    (SELECT COUNT(*)
       FROM repayment_schedule rs
      WHERE rs.loan_id = l.id)                                  AS emis_total,

    -- Next due installment
    (SELECT rs.installment_no
       FROM repayment_schedule rs
      WHERE rs.loan_id = l.id
        AND rs.status IN ('PENDING', 'OVERDUE')
      ORDER BY rs.due_date ASC
      LIMIT 1)                                                  AS next_installment_no,

    (SELECT rs.due_date
       FROM repayment_schedule rs
      WHERE rs.loan_id = l.id
        AND rs.status IN ('PENDING', 'OVERDUE')
      ORDER BY rs.due_date ASC
      LIMIT 1)                                                  AS next_due_date,

    (SELECT rs.emi_amount + rs.penalty_amount
       FROM repayment_schedule rs
      WHERE rs.loan_id = l.id
        AND rs.status IN ('PENDING', 'OVERDUE')
      ORDER BY rs.due_date ASC
      LIMIT 1)                                                  AS next_emi_due,

    -- Outstanding principal
    (SELECT rs.closing_balance
       FROM repayment_schedule rs
      WHERE rs.loan_id = l.id
        AND rs.status IN ('PENDING', 'OVERDUE')
      ORDER BY rs.due_date ASC
      LIMIT 1)                                                  AS outstanding_principal

FROM users u
JOIN loans l ON l.borrower_id = u.id
           AND l.status IN ('UNDER_REVIEW', 'OPEN', 'ACTIVE')

WHERE u.role_state = 'BORROWER';


-- ============================================================================
--  [V04]  REPAYMENT SCHEDULE DETAIL
--  Full amortisation table for a loan.  Designed to be filtered by loan_id
--  in application queries:
--    SELECT * FROM v_repayment_schedule_detail WHERE loan_id = $1;
-- ============================================================================
CREATE OR REPLACE VIEW v_repayment_schedule_detail AS
SELECT
    rs.loan_id,
    l.title                                                     AS loan_title,
    l.disbursed_amount,
    l.interest_rate_annual,

    rs.id                                                       AS schedule_id,
    rs.installment_no,
    rs.due_date,
    rs.status,
    rs.paid_at,

    -- EMI breakdown
    rs.emi_amount,
    rs.principal_component,
    rs.interest_component,
    rs.penalty_amount,
    rs.emi_amount + rs.penalty_amount                           AS total_due,

    -- Amortisation columns
    rs.opening_balance,
    rs.closing_balance,

    -- How many days overdue (NULL if not overdue)
    CASE
        WHEN rs.status = 'OVERDUE'
        THEN EXTRACT(DAY FROM NOW() - rs.due_date)::INT
        ELSE NULL
    END                                                         AS days_overdue,

    -- Cumulative principal recovered so far (across paid installments)
    SUM(rs.principal_component)
        FILTER (WHERE rs.status = 'PAID')
        OVER (PARTITION BY rs.loan_id
              ORDER BY rs.installment_no
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                                AS cumulative_principal_paid,

    -- Cumulative interest paid
    SUM(rs.interest_component)
        FILTER (WHERE rs.status = 'PAID')
        OVER (PARTITION BY rs.loan_id
              ORDER BY rs.installment_no
              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                                                                AS cumulative_interest_paid

FROM repayment_schedule rs
JOIN loans l ON l.id = rs.loan_id

ORDER BY rs.loan_id, rs.installment_no;


-- ============================================================================
--  [V05]  BORROWER HISTORY
--  All loans (any status) for every user, with repayment outcome summary.
--  Used by the admin user-detail page and borrower profile page.
-- ============================================================================
CREATE OR REPLACE VIEW v_borrower_history AS
SELECT
    u.id                                                        AS user_id,
    u.full_name,
    u.credit_score,
    u.kyc_status,

    l.id                                                        AS loan_id,
    l.status                                                    AS loan_status,
    l.category,
    l.title,
    l.requested_amount,
    l.disbursed_amount,
    l.interest_rate_annual,
    l.tenure_months,
    l.created_at                                                AS loan_created_at,

    -- Outcome statistics
    (SELECT COUNT(*) FROM repayment_schedule rs
      WHERE rs.loan_id = l.id AND rs.status = 'PAID')           AS emis_paid,

    (SELECT COUNT(*) FROM repayment_schedule rs
      WHERE rs.loan_id = l.id AND rs.status = 'OVERDUE')        AS emis_overdue,

    (SELECT SUM(rs.penalty_amount) FROM repayment_schedule rs
      WHERE rs.loan_id = l.id AND rs.penalty_amount > 0)        AS total_penalties_incurred,

    l.updated_at                                                AS last_updated

FROM users u
JOIN loans l ON l.borrower_id = u.id

ORDER BY u.id, l.created_at DESC;


-- ============================================================================
--  [V06]  LENDER PORTFOLIO
--  All active and historical lending positions for every user.
--  Filter by user_id in the application:
--    SELECT * FROM v_lender_portfolio WHERE lender_id = $1;
-- ============================================================================
CREATE OR REPLACE VIEW v_lender_portfolio AS
SELECT
    lc.lender_id,
    u.full_name                                                 AS lender_name,

    lc.id                                                       AS contribution_id,
    lc.loan_id,
    l.title                                                     AS loan_title,
    l.category,
    l.status                                                    AS loan_status,

    -- Position sizing
    lc.pledged_amount,
    l.disbursed_amount                                          AS loan_disbursed_amount,
    ROUND((lc.pledged_amount / NULLIF(l.disbursed_amount, 0)) * 100, 2)
                                                                AS pct_of_loan,

    -- Recovery
    lc.returned_amount                                          AS principal_recovered,
    lc.pledged_amount - lc.returned_amount                      AS principal_outstanding,
    lc.status                                                   AS contribution_status,

    -- Total interest earned to date
    COALESCE((
        SELECT SUM(ed.net_interest_share)
          FROM emi_distributions ed
         WHERE ed.contribution_id = lc.id
    ), 0.00)                                                    AS interest_earned,

    -- Total platform fees paid (informational)
    COALESCE((
        SELECT SUM(ed.platform_fee_amount)
          FROM emi_distributions ed
         WHERE ed.contribution_id = lc.id
    ), 0.00)                                                    AS platform_fees_paid,

    -- Loan terms for reference
    l.interest_rate_annual,
    l.tenure_months,
    l.funding_deadline,

    lc.created_at                                               AS pledged_at,
    lc.updated_at                                               AS last_updated

FROM loan_contributions lc
JOIN users u ON u.id = lc.lender_id
JOIN loans l ON l.id  = lc.loan_id

ORDER BY lc.lender_id, lc.created_at DESC;


-- ============================================================================
--  [V07]  LENDER RETURNS  (P&L per contribution)
--  Aggregated return analysis per contribution, showing gross yield,
--  platform fees, and net return on capital deployed.
-- ============================================================================
CREATE OR REPLACE VIEW v_lender_returns AS
SELECT
    lc.lender_id,
    u.full_name                                                 AS lender_name,
    lc.id                                                       AS contribution_id,
    lc.loan_id,
    l.title                                                     AS loan_title,
    l.category,
    l.status                                                    AS loan_status,
    l.interest_rate_annual,

    -- Capital
    lc.pledged_amount                                           AS capital_deployed,
    lc.returned_amount                                          AS principal_returned,

    -- Earnings
    COALESCE(agg.total_gross_interest, 0.00)                    AS gross_interest_earned,
    COALESCE(agg.total_platform_fees,  0.00)                    AS platform_fees_paid,
    COALESCE(agg.total_net_interest,   0.00)                    AS net_interest_earned,

    -- Net return on capital
    ROUND(
        COALESCE(agg.total_net_interest, 0.00)
        / NULLIF(lc.pledged_amount, 0) * 100,
    2)                                                          AS net_return_pct,

    -- EMI count
    COALESCE(agg.installments_received, 0)                      AS installments_received,

    lc.status                                                   AS position_status,
    lc.created_at                                               AS pledged_at

FROM loan_contributions lc
JOIN users u ON u.id = lc.lender_id
JOIN loans l  ON l.id = lc.loan_id
LEFT JOIN (
    SELECT
        ed.contribution_id,
        SUM(ed.gross_interest_share)    AS total_gross_interest,
        SUM(ed.platform_fee_amount)     AS total_platform_fees,
        SUM(ed.net_interest_share)      AS total_net_interest,
        COUNT(*)                        AS installments_received
    FROM emi_distributions ed
    GROUP BY ed.contribution_id
) agg ON agg.contribution_id = lc.id

ORDER BY lc.lender_id, net_interest_earned DESC;


-- ============================================================================
--  [V08]  EMI DISTRIBUTION DETAIL
--  Per-installment breakdown of what each lender received.
--  Provides a complete, auditable record of every credit event.
--  Filter by loan_id or lender_id in queries.
-- ============================================================================
CREATE OR REPLACE VIEW v_emi_distribution_detail AS
SELECT
    ed.loan_id,
    l.title                                                     AS loan_title,
    ed.lender_id,
    u.full_name                                                 AS lender_name,

    rs.installment_no,
    rs.due_date,
    rs.paid_at,
    rs.status                                                   AS installment_status,

    -- Lender's fractional share
    ROUND(ed.contribution_ratio * 100, 4)                       AS share_pct,

    -- Per-installment breakdown
    ed.principal_share,
    ed.gross_interest_share,
    ed.platform_fee_amount,
    ed.net_interest_share,
    ed.total_credited,

    ed.distributed_at

FROM emi_distributions ed
JOIN loans l               ON l.id  = ed.loan_id
JOIN users u               ON u.id  = ed.lender_id
JOIN repayment_schedule rs ON rs.id = ed.schedule_id

ORDER BY ed.loan_id, rs.installment_no, ed.lender_id;


-- ============================================================================
--  [V09]  PLATFORM REVENUE SUMMARY
--  Monthly fee income aggregation.  Used by the admin analytics dashboard.
-- ============================================================================
CREATE OR REPLACE VIEW v_platform_revenue_summary AS
SELECT
    DATE_TRUNC('month', pr.collected_at)::DATE                  AS revenue_month,
    l.category,
    COUNT(DISTINCT pr.loan_id)                                  AS loans_generating_revenue,
    COUNT(*)                                                    AS fee_events,
    SUM(pr.fee_amount)                                          AS total_fees_collected,
    ROUND(AVG(pr.fee_pct_applied), 2)                           AS avg_fee_pct,
    MIN(pr.fee_amount)                                          AS min_fee,
    MAX(pr.fee_amount)                                          AS max_fee

FROM platform_revenue pr
JOIN loans l ON l.id = pr.loan_id

GROUP BY DATE_TRUNC('month', pr.collected_at), l.category

ORDER BY revenue_month DESC, total_fees_collected DESC;


-- ============================================================================
--  [V10]  LOAN FUNDING PROGRESS
--  Shows the funding breakdown for each OPEN loan — which lenders have
--  pledged, how much, and what's left.  Used by the loan detail page
--  to show a funding bar and contributor list.
-- ============================================================================
CREATE OR REPLACE VIEW v_loan_funding_progress AS
SELECT
    l.id                                                        AS loan_id,
    l.title,
    l.status,
    l.requested_amount,
    l.funded_amount,
    l.requested_amount - l.funded_amount                        AS unfunded_gap,
    ROUND((l.funded_amount / NULLIF(l.requested_amount, 0)) * 100, 2)
                                                                AS funded_pct,
    l.funding_deadline,

    -- Per-lender breakdown (aggregated into JSON for easy API serialisation)
    COALESCE(
        JSON_AGG(
            JSON_BUILD_OBJECT(
                'lender_id',     lc.lender_id,
                'pledged',       lc.pledged_amount,
                'share_pct',     ROUND((lc.pledged_amount / NULLIF(l.funded_amount, 0)) * 100, 2),
                'status',        lc.status,
                'pledged_at',    lc.created_at
            )
            ORDER BY lc.pledged_amount DESC
        ) FILTER (WHERE lc.id IS NOT NULL),
        '[]'::JSON
    )                                                           AS contributors,

    COUNT(lc.id)                                                AS contributor_count

FROM loans l
LEFT JOIN loan_contributions lc
       ON lc.loan_id = l.id
      AND lc.status IN ('ESCROWED', 'DISBURSED')

WHERE l.status IN ('OPEN', 'ACTIVE')

GROUP BY l.id, l.title, l.status, l.requested_amount,
         l.funded_amount, l.funding_deadline

ORDER BY funded_pct DESC;


-- ============================================================================
--  [V11]  CREDIT SCORE LEADERBOARD
--  Borrower ranking by credit score.  Lenders can use this to gauge platform-
--  wide borrower quality.  PII is minimal — no email or wallet data exposed.
-- ============================================================================
CREATE OR REPLACE VIEW v_credit_score_leaderboard AS
SELECT
    RANK() OVER (ORDER BY u.credit_score DESC)                  AS rank,
    u.id                                                        AS user_id,
    u.full_name,
    u.credit_score,
    u.kyc_status,

    -- Loan history summary
    COUNT(l.id)                                                 AS total_loans,
    COUNT(l.id) FILTER (WHERE l.status = 'COMPLETED')           AS loans_completed,
    COUNT(l.id) FILTER (WHERE l.status = 'ACTIVE')              AS loans_active,
    COUNT(l.id) FILTER (WHERE l.status = 'CANCELLED')           AS loans_cancelled,

    -- Repayment discipline
    COALESCE(SUM(
        (SELECT COUNT(*) FROM repayment_schedule rs
          WHERE rs.loan_id = l.id AND rs.status = 'PAID')
    ), 0)                                                       AS total_emis_paid_on_time,

    COALESCE(SUM(
        (SELECT COUNT(*) FROM repayment_schedule rs
          WHERE rs.loan_id = l.id AND rs.status = 'OVERDUE')
    ), 0)                                                       AS total_emis_overdue,

    u.created_at                                                AS member_since

FROM users u
LEFT JOIN loans l ON l.borrower_id = u.id

WHERE u.kyc_status = 'VERIFIED'

GROUP BY u.id, u.full_name, u.credit_score, u.kyc_status, u.created_at

ORDER BY rank;


-- ============================================================================
--  [V12]  OVERDUE WATCHLIST
--  All OVERDUE installments with borrower contact info and outstanding amounts.
--  Used by the admin collections dashboard.
-- ============================================================================
CREATE OR REPLACE VIEW v_overdue_watchlist AS
SELECT
    rs.loan_id,
    l.title                                                     AS loan_title,
    l.borrower_id,
    u.full_name                                                 AS borrower_name,
    u.email                                                     AS borrower_email,
    u.credit_score,
    u.wallet_balance                                            AS borrower_wallet_balance,

    rs.id                                                       AS schedule_id,
    rs.installment_no,
    rs.due_date,
    EXTRACT(DAY FROM NOW() - rs.due_date)::INT                  AS days_overdue,
    rs.emi_amount,
    rs.penalty_amount,
    rs.emi_amount + rs.penalty_amount                           AS total_outstanding,

    -- Loan context
    l.disbursed_amount,
    rs.closing_balance                                          AS remaining_principal,

    -- Lender exposure at risk
    (SELECT COUNT(DISTINCT lc.lender_id)
       FROM loan_contributions lc
      WHERE lc.loan_id = rs.loan_id
        AND lc.status  = 'DISBURSED')                           AS affected_lenders

FROM repayment_schedule rs
JOIN loans l ON l.id  = rs.loan_id
JOIN users u ON u.id  = l.borrower_id

WHERE rs.status = 'OVERDUE'

ORDER BY days_overdue DESC, rs.loan_id;


-- ============================================================================
--  [V13]  AUDIT TRAIL  (human-readable)
--  Joins audit_log with users to show full_name instead of UUID for the
--  changed_by field.  Exposes a diff-style summary of what changed.
--  For security, this view should be restricted to admin roles in production.
-- ============================================================================
CREATE OR REPLACE VIEW v_audit_trail AS
SELECT
    al.id                                                       AS audit_id,
    al.changed_at,
    al.table_name,
    al.record_id,
    al.operation,

    -- Who made the change
    al.changed_by                                               AS changed_by_id,
    u.full_name                                                 AS changed_by_name,
    al.db_user,
    al.client_addr,

    -- Key fields extracted from JSONB for quick scanning
    CASE al.operation
        WHEN 'INSERT' THEN al.new_data
        WHEN 'DELETE' THEN al.old_data
        WHEN 'UPDATE' THEN al.new_data
    END                                                         AS current_state,

    -- Changed keys (UPDATE only) — shows which columns were modified
    CASE
        WHEN al.operation = 'UPDATE'
        THEN (
            SELECT JSON_OBJECT_AGG(
                key,
                JSON_BUILD_OBJECT(
                    'from', al.old_data -> key,
                    'to',   al.new_data -> key
                )
            )
            FROM JSONB_EACH(al.old_data) kv(key, val)
            WHERE al.old_data -> key IS DISTINCT FROM al.new_data -> key
        )::JSONB
        ELSE NULL
    END                                                         AS changed_fields

FROM audit_log al
LEFT JOIN users u ON u.id = al.changed_by

ORDER BY al.changed_at DESC;


-- ============================================================================
--  [V14]  PLATFORM HEALTH  (executive summary — single row)
--  A single-row snapshot of key platform metrics.
--  Useful for admin dashboards and monitoring endpoints.
-- ============================================================================
CREATE OR REPLACE VIEW v_platform_health AS
SELECT
    -- User base
    (SELECT COUNT(*) FROM users)                                AS total_users,
    (SELECT COUNT(*) FROM users WHERE kyc_status = 'VERIFIED')  AS verified_users,
    (SELECT COUNT(*) FROM users WHERE kyc_status = 'SUSPENDED') AS suspended_users,
    (SELECT COUNT(*) FROM users WHERE role_state = 'BORROWER')  AS active_borrowers,
    (SELECT COUNT(*) FROM users WHERE role_state = 'LENDER')    AS active_lenders,
    (SELECT ROUND(AVG(credit_score), 1) FROM users
      WHERE kyc_status = 'VERIFIED')                           AS avg_credit_score,

    -- Loan pipeline
    (SELECT COUNT(*) FROM loans WHERE status = 'UNDER_REVIEW')  AS loans_under_review,
    (SELECT COUNT(*) FROM loans WHERE status = 'OPEN')          AS loans_open,
    (SELECT COUNT(*) FROM loans WHERE status = 'ACTIVE')        AS loans_active,
    (SELECT COUNT(*) FROM loans WHERE status = 'COMPLETED')     AS loans_completed,
    (SELECT COUNT(*) FROM loans WHERE status = 'CANCELLED')     AS loans_cancelled,

    -- Capital
    (SELECT COALESCE(SUM(wallet_balance), 0) FROM users)        AS total_platform_liquidity,
    (SELECT COALESCE(SUM(amount), 0) FROM escrow_ledger
      WHERE state = 'LOCKED')                                   AS total_escrow_locked,
    (SELECT COALESCE(SUM(disbursed_amount), 0)
       FROM loans WHERE status IN ('ACTIVE', 'COMPLETED'))      AS total_disbursed_ever,

    -- Repayment health
    (SELECT COUNT(*) FROM repayment_schedule
      WHERE status = 'OVERDUE')                                 AS overdue_installments,
    (SELECT COUNT(*) FROM repayment_schedule
      WHERE status = 'PENDING')                                 AS pending_installments,
    (SELECT COALESCE(SUM(emi_amount + penalty_amount), 0.00)
       FROM repayment_schedule WHERE status = 'OVERDUE')        AS total_overdue_amount,

    -- Revenue
    (SELECT COALESCE(SUM(fee_amount), 0.00)
       FROM platform_revenue)                                   AS total_platform_revenue,
    (SELECT COALESCE(SUM(fee_amount), 0.00)
       FROM platform_revenue
      WHERE collected_at >= DATE_TRUNC('month', NOW()))         AS revenue_this_month,

    -- Audit activity
    (SELECT COUNT(*) FROM audit_log
      WHERE changed_at >= NOW() - INTERVAL '24 hours')          AS audit_events_last_24h,

    NOW()                                                       AS snapshot_at;
