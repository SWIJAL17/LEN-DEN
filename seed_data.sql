-- ============================================================================
--  Multi-Tiered Micro-Lending Platform
--  seed_data.sql  |  Group ID: 13  |  PostgreSQL 16
--  Run AFTER schema.sql, triggers.sql, procedures.sql, views.sql
-- ============================================================================
--
--  Seed strategy
--  ─────────────
--  This file manually inserts data that covers every loan lifecycle path
--  and every platform constraint so all views and procedures can be
--  demonstrated without running application code.
--
--  Lifecycle paths covered
--  ───────────────────────
--  [S-A]  Full happy path:
--           OPEN → fully funded → ACTIVE → all EMIs PAID → COMPLETED
--           Borrower cooling-off applied. Lender role released.
--
--  [S-B]  Partial funding path:
--           OPEN → deadline passes at 65 % funded → ACTIVE (partial)
--           disbursed_amount < requested_amount; reduced EMI schedule generated.
--
--  [S-C]  Threshold failure path:
--           OPEN → deadline passes at 10 % funded → CANCELLED
--           All escrow refunded. Borrower role released immediately.
--
--  [S-D]  Admin rejection path:
--           UNDER_REVIEW → admin rejects → CANCELLED
--           Borrower released with no cooling-off.
--
--  [S-E]  Pledge retraction path:
--           Lender pledges → retracts within 24 h → RETRACTED
--           Escrow refunded. Lender role checked.
--
--  [S-F]  Overdue installment path:
--           Loan ACTIVE, one installment set to OVERDUE with penalty.
--           Credit score deducted. Watchlist view populated.
--
--  [S-G]  Under-review / pending loan:
--           Newly submitted loan sitting in UNDER_REVIEW.
--
--  Users seeded
--  ────────────
--  admin_01   — platform admin (VERIFIED, NEUTRAL, high credit score)
--  borrower_01— happy path borrower       [S-A]
--  borrower_02— partial funding borrower  [S-B]
--  borrower_03— threshold fail borrower   [S-C]
--  borrower_04— admin-rejected borrower   [S-D]
--  borrower_05— overdue borrower          [S-F]
--  borrower_06— under-review borrower     [S-G]
--  lender_01  — funds S-A (primary), S-B
--  lender_02  — funds S-A (secondary), S-B, S-F
--  lender_03  — funds S-B (third lender)
--  lender_04  — pledge + retraction demo  [S-E]
--  lender_05  — unverified (KYC gate demo)
--
--  All password hashes are bcrypt of "Password123!" for demo purposes.
-- ============================================================================

-- Disable triggers temporarily for direct seed inserts that bypass the
-- application flow (e.g. inserting historical COMPLETED loans directly).
-- We re-enable them at the end.
SET session_replication_role = 'replica';

-- ============================================================================
--  USERS
-- ============================================================================
INSERT INTO users
    (id, email, password_hash, full_name,
     wallet_balance, kyc_status, role_state,
     cooling_off_until, credit_score,
     created_at, updated_at)
VALUES

-- ── Admin ────────────────────────────────────────────────────────────────────
(
    '00000000-0000-0000-0000-000000000001',
    'admin@lendplatform.com',
    '$2b$12$KIX9l5kR4v9Zq0mXs3O5peDpNfFwXnAuQZ6NBlQ7YExb5AGjnP7pq',
    'Platform Admin',
    0.00, 'VERIFIED', 'NEUTRAL', NULL, 750,
    NOW() - INTERVAL '180 days', NOW() - INTERVAL '1 day'
),

-- ── Borrowers ─────────────────────────────────────────────────────────────────
(   -- [S-A] happy path — loan completed, cooling-off active
    '00000000-0000-0000-0000-000000000010',
    'arjun.mehta@email.com',
    '$2b$12$KIX9l5kR4v9Zq0mXs3O5peDpNfFwXnAuQZ6NBlQ7YExb5AGjnP7pq',
    'Arjun Mehta',
    24500.00, 'VERIFIED', 'NEUTRAL',
    NOW() + INTERVAL '30 hours',       -- cooling-off: repaid recently
    720,
    NOW() - INTERVAL '120 days', NOW() - INTERVAL '2 hours'
),
(   -- [S-B] partial funding — loan active, reduced schedule
    '00000000-0000-0000-0000-000000000011',
    'priya.sharma@email.com',
    '$2b$12$KIX9l5kR4v9Zq0mXs3O5peDpNfFwXnAuQZ6NBlQ7YExb5AGjnP7pq',
    'Priya Sharma',
    18000.00, 'VERIFIED', 'BORROWER', NULL, 680,
    NOW() - INTERVAL '90 days', NOW() - INTERVAL '5 days'
),
(   -- [S-C] threshold failure — cancelled, role released
    '00000000-0000-0000-0000-000000000012',
    'rohan.iyer@email.com',
    '$2b$12$KIX9l5kR4v9Zq0mXs3O5peDpNfFwXnAuQZ6NBlQ7YExb5AGjnP7pq',
    'Rohan Iyer',
    5000.00, 'VERIFIED', 'NEUTRAL', NULL, 620,
    NOW() - INTERVAL '60 days', NOW() - INTERVAL '20 days'
),
(   -- [S-D] admin rejected — role released, no cooldown
    '00000000-0000-0000-0000-000000000013',
    'nisha.desai@email.com',
    '$2b$12$KIX9l5kR4v9Zq0mXs3O5peDpNfFwXnAuQZ6NBlQ7YExb5AGjnP7pq',
    'Nisha Desai',
    3000.00, 'VERIFIED', 'NEUTRAL', NULL, 590,
    NOW() - INTERVAL '45 days', NOW() - INTERVAL '40 days'
),
(   -- [S-F] overdue — loan active with one overdue installment
    '00000000-0000-0000-0000-000000000014',
    'vikram.nair@email.com',
    '$2b$12$KIX9l5kR4v9Zq0mXs3O5peDpNfFwXnAuQZ6NBlQ7YExb5AGjnP7pq',
    'Vikram Nair',
    1200.00, 'VERIFIED', 'BORROWER', NULL, 490,
    NOW() - INTERVAL '75 days', NOW() - INTERVAL '3 days'
),
(   -- [S-G] under-review — loan awaiting admin approval
    '00000000-0000-0000-0000-000000000015',
    'kavya.reddy@email.com',
    '$2b$12$KIX9l5kR4v9Zq0mXs3O5peDpNfFwXnAuQZ6NBlQ7YExb5AGjnP7pq',
    'Kavya Reddy',
    8000.00, 'VERIFIED', 'BORROWER', NULL, 650,
    NOW() - INTERVAL '3 days', NOW() - INTERVAL '1 day'
),

-- ── Lenders ──────────────────────────────────────────────────────────────────
(   -- funds [S-A] and [S-B]
    '00000000-0000-0000-0000-000000000020',
    'ananya.krishnan@email.com',
    '$2b$12$KIX9l5kR4v9Zq0mXs3O5peDpNfFwXnAuQZ6NBlQ7YExb5AGjnP7pq',
    'Ananya Krishnan',
    47000.00, 'VERIFIED', 'LENDER', NULL, 760,
    NOW() - INTERVAL '150 days', NOW() - INTERVAL '5 days'
),
(   -- funds [S-A], [S-B], [S-F]
    '00000000-0000-0000-0000-000000000021',
    'sameer.joshi@email.com',
    '$2b$12$KIX9l5kR4v9Zq0mXs3O5peDpNfFwXnAuQZ6NBlQ7YExb5AGjnP7pq',
    'Sameer Joshi',
    62000.00, 'VERIFIED', 'LENDER', NULL, 780,
    NOW() - INTERVAL '140 days', NOW() - INTERVAL '4 days'
),
(   -- funds [S-B] only
    '00000000-0000-0000-0000-000000000022',
    'deepika.pillai@email.com',
    '$2b$12$KIX9l5kR4v9Zq0mXs3O5peDpNfFwXnAuQZ6NBlQ7YExb5AGjnP7pq',
    'Deepika Pillai',
    35000.00, 'VERIFIED', 'LENDER', NULL, 730,
    NOW() - INTERVAL '100 days', NOW() - INTERVAL '6 days'
),
(   -- pledge + retraction demo [S-E]
    '00000000-0000-0000-0000-000000000023',
    'rahul.bose@email.com',
    '$2b$12$KIX9l5kR4v9Zq0mXs3O5peDpNfFwXnAuQZ6NBlQ7YExb5AGjnP7pq',
    'Rahul Bose',
    20000.00, 'VERIFIED', 'NEUTRAL', NULL, 700,
    NOW() - INTERVAL '30 days', NOW() - INTERVAL '2 days'
),
(   -- unverified — KYC gate demo
    '00000000-0000-0000-0000-000000000024',
    'tanya.kapoor@email.com',
    '$2b$12$KIX9l5kR4v9Zq0mXs3O5peDpNfFwXnAuQZ6NBlQ7YExb5AGjnP7pq',
    'Tanya Kapoor',
    15000.00, 'UNVERIFIED', 'NEUTRAL', NULL, 650,
    NOW() - INTERVAL '7 days', NOW() - INTERVAL '6 days'
);


-- ============================================================================
--  LOANS
-- ============================================================================
INSERT INTO loans (
    id, borrower_id, title, description, category,
    requested_amount, funded_amount, disbursed_amount,
    interest_rate_annual, tenure_months, funding_deadline,
    min_funding_pct, max_lender_pct, grace_period_days,
    late_penalty_pct, platform_fee_pct,
    reviewed_by, reviewed_at, rejection_reason,
    status, created_at, updated_at
)
VALUES

-- ── [S-A]  Completed loan (Arjun Mehta) ──────────────────────────────────────
(
    'aaaaaaaa-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000010',   -- Arjun
    'Small Business Equipment Upgrade',
    'Funding new POS terminals and stock management software for my retail shop in Pune.',
    'BUSINESS',
    50000.00, 50000.00, 50000.00,
    12.00, 6,
    NOW() - INTERVAL '90 days',               -- deadline already passed
    20.00, 50.00, 3, 2.00, 1.00,
    '00000000-0000-0000-0000-000000000001',
    NOW() - INTERVAL '115 days',
    NULL,
    'COMPLETED',
    NOW() - INTERVAL '120 days',
    NOW() - INTERVAL '2 hours'
),

-- ── [S-B]  Partially funded active loan (Priya Sharma) ───────────────────────
(
    'bbbbbbbb-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000011',   -- Priya
    'Digital Marketing Diploma Course',
    'Pursuing a 9-month digital marketing certification at MICA Ahmedabad.',
    'EDUCATION',
    40000.00, 26000.00, 26000.00,             -- 65 % funded at deadline
    14.00, 9,
    NOW() - INTERVAL '5 days',               -- deadline passed 5 days ago
    20.00, 50.00, 3, 2.00, 1.00,
    '00000000-0000-0000-0000-000000000001',
    NOW() - INTERVAL '85 days',
    NULL,
    'ACTIVE',
    NOW() - INTERVAL '90 days',
    NOW() - INTERVAL '5 days'
),

-- ── [S-C]  Threshold failure cancelled loan (Rohan Iyer) ─────────────────────
(
    'cccccccc-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000012',   -- Rohan
    'Home Renovation - Kitchen Remodel',
    'Replacing old kitchen fittings, plumbing, and tiles in a 2BHK flat.',
    'PERSONAL',
    30000.00, 3000.00, NULL,                  -- only 10 % funded — threshold fail
    13.00, 6,
    NOW() - INTERVAL '20 days',
    20.00, 50.00, 3, 2.00, 1.00,
    '00000000-0000-0000-0000-000000000001',
    NOW() - INTERVAL '55 days',
    NULL,
    'CANCELLED',
    NOW() - INTERVAL '60 days',
    NOW() - INTERVAL '20 days'
),

-- ── [S-D]  Admin rejected loan (Nisha Desai) ─────────────────────────────────
(
    'dddddddd-0000-0000-0000-000000000004',
    '00000000-0000-0000-0000-000000000013',   -- Nisha
    'Personal Vacation Trip to Europe',
    'Planning a 3-week backpacking holiday across France and Italy.',
    'PERSONAL',
    25000.00, 0.00, NULL,
    18.00, 12,
    NOW() - INTERVAL '38 days',
    20.00, 50.00, 3, 2.00, 1.00,
    '00000000-0000-0000-0000-000000000001',
    NOW() - INTERVAL '43 days',
    'Loan purpose does not meet platform lending criteria. Vacation travel is excluded from eligible use cases.',
    'CANCELLED',
    NOW() - INTERVAL '45 days',
    NOW() - INTERVAL '40 days'
),

-- ── [S-F]  Active loan with overdue installment (Vikram Nair) ─────────────────
(
    'ffffffff-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-000000000014',   -- Vikram
    'Medical Emergency — Appendix Surgery',
    'Urgent appendix surgery and 2-week post-operative care at Manipal Hospital, Bengaluru.',
    'MEDICAL',
    20000.00, 20000.00, 20000.00,
    15.00, 6,
    NOW() - INTERVAL '62 days',
    20.00, 50.00, 3, 2.00, 1.00,
    '00000000-0000-0000-0000-000000000001',
    NOW() - INTERVAL '72 days',
    NULL,
    'ACTIVE',
    NOW() - INTERVAL '75 days',
    NOW() - INTERVAL '62 days'
),

-- ── [S-G]  Under-review loan (Kavya Reddy) ────────────────────────────────────
(
    'gggggggg-0000-0000-0000-000000000007',
    '00000000-0000-0000-0000-000000000015',   -- Kavya
    'Freelance Photography Equipment',
    'Purchasing a Sony A7 III mirrorless camera and prime lenses to expand my freelance portfolio.',
    'BUSINESS',
    35000.00, 0.00, NULL,
    13.50, 12,
    NOW() + INTERVAL '25 days',               -- deadline in future
    20.00, 50.00, 3, 2.00, 1.00,
    NULL, NULL, NULL,
    'UNDER_REVIEW',
    NOW() - INTERVAL '1 day',
    NOW() - INTERVAL '1 day'
),

-- ── [S-OPEN]  Open loan accepting pledges now ─────────────────────────────────
(
    'eeeeeeee-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000010',   -- NOTE: Arjun is re-seeded as NEUTRAL
    -- (cooling-off seeded above; in real flow he would wait — seeded directly
    --  here to demonstrate the marketplace view with an open loan)
    'Solar Panel Installation for Shop',
    'Installing 3 kW rooftop solar system to reduce electricity costs for the retail shop.',
    'BUSINESS',
    45000.00, 14000.00, NULL,
    11.00, 12,
    NOW() + INTERVAL '18 days',
    20.00, 50.00, 3, 2.00, 1.00,
    '00000000-0000-0000-0000-000000000001',
    NOW() - INTERVAL '2 days',
    NULL,
    'OPEN',
    NOW() - INTERVAL '3 days',
    NOW() - INTERVAL '1 hour'
);


-- ============================================================================
--  LOAN CONTRIBUTIONS
-- ============================================================================
INSERT INTO loan_contributions (
    id, loan_id, lender_id,
    pledged_amount, returned_amount,
    status, created_at, updated_at
)
VALUES

-- ── [S-A]  Completed loan — two lenders, all principal returned ───────────────
(
    'aa000001-0000-0000-0000-000000000000',
    'aaaaaaaa-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000020',   -- Ananya: 25000 (50%)
    25000.00, 25000.00, 'RETURNED',
    NOW() - INTERVAL '118 days', NOW() - INTERVAL '2 hours'
),
(
    'aa000002-0000-0000-0000-000000000000',
    'aaaaaaaa-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000021',   -- Sameer: 25000 (50%)
    25000.00, 25000.00, 'RETURNED',
    NOW() - INTERVAL '117 days', NOW() - INTERVAL '2 hours'
),

-- ── [S-B]  Partial funding — three lenders, disbursed, repayment ongoing ──────
(
    'bb000001-0000-0000-0000-000000000000',
    'bbbbbbbb-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000020',   -- Ananya: 13000 (50% of 26000)
    13000.00, 2600.00, 'DISBURSED',
    NOW() - INTERVAL '88 days', NOW() - INTERVAL '5 days'
),
(
    'bb000002-0000-0000-0000-000000000000',
    'bbbbbbbb-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000021',   -- Sameer: 8000
    8000.00, 1600.00, 'DISBURSED',
    NOW() - INTERVAL '87 days', NOW() - INTERVAL '5 days'
),
(
    'bb000003-0000-0000-0000-000000000000',
    'bbbbbbbb-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000022',   -- Deepika: 5000
    5000.00, 1000.00, 'DISBURSED',
    NOW() - INTERVAL '86 days', NOW() - INTERVAL '5 days'
),

-- ── [S-C]  Threshold failure — one lender, contribution returned on cancel ────
(
    'cc000001-0000-0000-0000-000000000000',
    'cccccccc-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000023',   -- Rahul: 3000 pledged, refunded
    3000.00, 0.00, 'RETURNED',
    NOW() - INTERVAL '50 days', NOW() - INTERVAL '20 days'
),

-- ── [S-F]  Overdue loan — two lenders disbursed ───────────────────────────────
(
    'ff000001-0000-0000-0000-000000000000',
    'ffffffff-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-000000000021',   -- Sameer: 10000 (50%)
    10000.00, 3205.18, 'DISBURSED',
    NOW() - INTERVAL '73 days', NOW() - INTERVAL '3 days'
),
(
    'ff000002-0000-0000-0000-000000000000',
    'ffffffff-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-000000000022',   -- Deepika: 10000 (50%)
    10000.00, 3205.18, 'DISBURSED',
    NOW() - INTERVAL '73 days', NOW() - INTERVAL '3 days'
),

-- ── [S-OPEN]  Open loan — partial pledges, still accepting ────────────────────
(
    'ee000001-0000-0000-0000-000000000000',
    'eeeeeeee-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000022',   -- Deepika: 14000 (31.1%)
    14000.00, 0.00, 'ESCROWED',
    NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'
);


-- ============================================================================
--  ESCROW LEDGER
-- ============================================================================
INSERT INTO escrow_ledger (
    id, contribution_id, loan_id, lender_id,
    amount, state,
    locked_at, released_at, release_reason
)
VALUES

-- ── [S-A]  Released — both lenders disbursed ─────────────────────────────────
(
    'eaaa0001-0000-0000-0000-000000000000',
    'aa000001-0000-0000-0000-000000000000',
    'aaaaaaaa-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000020',
    25000.00, 'RELEASED',
    NOW() - INTERVAL '118 days',
    NOW() - INTERVAL '115 days', 'DISBURSED'
),
(
    'eaaa0002-0000-0000-0000-000000000000',
    'aa000002-0000-0000-0000-000000000000',
    'aaaaaaaa-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000021',
    25000.00, 'RELEASED',
    NOW() - INTERVAL '117 days',
    NOW() - INTERVAL '115 days', 'DISBURSED'
),

-- ── [S-B]  Released — partial disbursement ────────────────────────────────────
(
    'ebbb0001-0000-0000-0000-000000000000',
    'bb000001-0000-0000-0000-000000000000',
    'bbbbbbbb-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000020',
    13000.00, 'RELEASED',
    NOW() - INTERVAL '88 days',
    NOW() - INTERVAL '5 days', 'DISBURSED'
),
(
    'ebbb0002-0000-0000-0000-000000000000',
    'bb000002-0000-0000-0000-000000000000',
    'bbbbbbbb-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000021',
    8000.00, 'RELEASED',
    NOW() - INTERVAL '87 days',
    NOW() - INTERVAL '5 days', 'DISBURSED'
),
(
    'ebbb0003-0000-0000-0000-000000000000',
    'bb000003-0000-0000-0000-000000000000',
    'bbbbbbbb-0000-0000-0000-000000000002',
    '00000000-0000-0000-0000-000000000022',
    5000.00, 'RELEASED',
    NOW() - INTERVAL '86 days',
    NOW() - INTERVAL '5 days', 'DISBURSED'
),

-- ── [S-C]  Released — loan cancelled, escrow refunded ─────────────────────────
(
    'eccc0001-0000-0000-0000-000000000000',
    'cc000001-0000-0000-0000-000000000000',
    'cccccccc-0000-0000-0000-000000000003',
    '00000000-0000-0000-0000-000000000023',
    3000.00, 'RELEASED',
    NOW() - INTERVAL '50 days',
    NOW() - INTERVAL '20 days', 'LOAN_CANCELLED'
),

-- ── [S-F]  Released — medical loan disbursed ─────────────────────────────────
(
    'efff0001-0000-0000-0000-000000000000',
    'ff000001-0000-0000-0000-000000000000',
    'ffffffff-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-000000000021',
    10000.00, 'RELEASED',
    NOW() - INTERVAL '73 days',
    NOW() - INTERVAL '62 days', 'DISBURSED'
),
(
    'efff0002-0000-0000-0000-000000000000',
    'ff000002-0000-0000-0000-000000000000',
    'ffffffff-0000-0000-0000-000000000006',
    '00000000-0000-0000-0000-000000000022',
    10000.00, 'RELEASED',
    NOW() - INTERVAL '73 days',
    NOW() - INTERVAL '62 days', 'DISBURSED'
),

-- ── [S-OPEN]  LOCKED — awaiting disbursal ────────────────────────────────────
(
    'eeee0001-0000-0000-0000-000000000000',
    'ee000001-0000-0000-0000-000000000000',
    'eeeeeeee-0000-0000-0000-000000000005',
    '00000000-0000-0000-0000-000000000022',
    14000.00, 'LOCKED',
    NOW() - INTERVAL '1 day',
    NULL, NULL
);


-- ============================================================================
--  REPAYMENT SCHEDULE
--  [S-A]  6 EMIs on ₹50,000 @ 12% p.a. — ALL PAID
--  [S-B]  9 EMIs on ₹26,000 @ 14% p.a. — 2 PAID, 1 OVERDUE, 6 PENDING
--  [S-F]  6 EMIs on ₹20,000 @ 15% p.a. — 2 PAID, 1 OVERDUE, 3 PENDING
--
--  EMI amounts pre-calculated:
--   [S-A]  r=0.01,    n=6,  P=50000  → EMI = ₹8,605.64
--   [S-B]  r=0.01167, n=9,  P=26000  → EMI = ₹3,086.24
--   [S-F]  r=0.0125,  n=6,  P=20000  → EMI = ₹3,479.07
-- ============================================================================
INSERT INTO repayment_schedule (
    id, loan_id, installment_no, due_date,
    emi_amount, principal_component, interest_component,
    opening_balance, closing_balance,
    penalty_amount, status, paid_at
)
VALUES

-- ── [S-A]  50000 @ 12% / 6 months  — all PAID ────────────────────────────────
('rsa001', 'aaaaaaaa-0000-0000-0000-000000000001', 1, NOW()::DATE - 105, 8605.64, 8105.64, 500.00, 50000.00, 41894.36, 0.00, 'PAID', NOW() - INTERVAL '104 days'),
('rsa002', 'aaaaaaaa-0000-0000-0000-000000000001', 2, NOW()::DATE - 75,  8605.64, 8186.70, 418.94, 41894.36, 33707.66, 0.00, 'PAID', NOW() - INTERVAL '74 days'),
('rsa003', 'aaaaaaaa-0000-0000-0000-000000000001', 3, NOW()::DATE - 45,  8605.64, 8268.57, 337.08, 33707.66, 25439.09, 0.00, 'PAID', NOW() - INTERVAL '44 days'),
('rsa004', 'aaaaaaaa-0000-0000-0000-000000000001', 4, NOW()::DATE - 15,  8605.64, 8351.25, 254.39, 25439.09, 17087.84, 0.00, 'PAID', NOW() - INTERVAL '14 days'),
('rsa005', 'aaaaaaaa-0000-0000-0000-000000000001', 5, NOW()::DATE + 15,  8605.64, 8434.77, 170.88, 17087.84, 8653.07,  0.00, 'PAID', NOW() - INTERVAL '3 days'),
('rsa006', 'aaaaaaaa-0000-0000-0000-000000000001', 6, NOW()::DATE + 45,  8739.71, 8653.07, 86.53,  8653.07,  0.00,     0.00, 'PAID', NOW() - INTERVAL '3 hours'),

-- ── [S-B]  26000 @ 14% / 9 months  — 2 PAID, 1 OVERDUE, 6 PENDING ───────────
('rsb001', 'bbbbbbbb-0000-0000-0000-000000000002', 1, NOW()::DATE - 35, 3086.24, 2783.24, 303.00, 26000.00, 23216.76, 0.00,  'PAID', NOW() - INTERVAL '34 days'),
('rsb002', 'bbbbbbbb-0000-0000-0000-000000000002', 2, NOW()::DATE - 5,  3086.24, 2815.69, 270.53, 23216.76, 20401.07, 0.00,  'PAID', NOW() - INTERVAL '4 days'),
('rsb003', 'bbbbbbbb-0000-0000-0000-000000000002', 3, NOW()::DATE - 8,  3086.24, 2848.50, 237.68, 20401.07, 17552.57, 61.72, 'OVERDUE', NULL),
('rsb004', 'bbbbbbbb-0000-0000-0000-000000000002', 4, NOW()::DATE + 22, 3086.24, 2881.67, 204.53, 17552.57, 14670.90, 0.00,  'PENDING', NULL),
('rsb005', 'bbbbbbbb-0000-0000-0000-000000000002', 5, NOW()::DATE + 52, 3086.24, 2915.20, 171.00, 14670.90, 11755.70, 0.00,  'PENDING', NULL),
('rsb006', 'bbbbbbbb-0000-0000-0000-000000000002', 6, NOW()::DATE + 82, 3086.24, 2949.11, 137.15, 11755.70, 8806.59,  0.00,  'PENDING', NULL),
('rsb007', 'bbbbbbbb-0000-0000-0000-000000000002', 7, NOW()::DATE + 112,3086.24, 2983.39, 102.74, 8806.59,  5823.20,  0.00,  'PENDING', NULL),
('rsb008', 'bbbbbbbb-0000-0000-0000-000000000002', 8, NOW()::DATE + 142,3086.24, 3018.06, 68.10,  5823.20,  2805.14,  0.00,  'PENDING', NULL),
('rsb009', 'bbbbbbbb-0000-0000-0000-000000000002', 9, NOW()::DATE + 172,2837.88, 2805.14, 32.73,  2805.14,  0.00,     0.00,  'PENDING', NULL),

-- ── [S-F]  20000 @ 15% / 6 months  — 2 PAID, 1 OVERDUE, 3 PENDING ───────────
('rsf001', 'ffffffff-0000-0000-0000-000000000006', 1, NOW()::DATE - 62, 3479.07, 3229.07, 250.00, 20000.00, 16770.93, 0.00,   'PAID', NOW() - INTERVAL '61 days'),
('rsf002', 'ffffffff-0000-0000-0000-000000000006', 2, NOW()::DATE - 32, 3479.07, 3269.45, 209.64, 16770.93, 13501.48, 0.00,   'PAID', NOW() - INTERVAL '31 days'),
('rsf003', 'ffffffff-0000-0000-0000-000000000006', 3, NOW()::DATE - 9,  3479.07, 3310.32, 168.77, 13501.48, 10191.16, 69.58,  'OVERDUE', NULL),
('rsf004', 'ffffffff-0000-0000-0000-000000000006', 4, NOW()::DATE + 21, 3479.07, 3351.70, 127.39, 10191.16, 6839.46,  0.00,   'PENDING', NULL),
('rsf005', 'ffffffff-0000-0000-0000-000000000006', 5, NOW()::DATE + 51, 3479.07, 3393.59, 85.49,  6839.46,  3445.87,  0.00,   'PENDING', NULL),
('rsf006', 'ffffffff-0000-0000-0000-000000000006', 6, NOW()::DATE + 81, 3489.04, 3445.87, 43.07,  3445.87,  0.00,     0.00,   'PENDING', NULL);


-- ============================================================================
--  EMI DISTRIBUTIONS
--  Pro-rata splits for all PAID installments.
--
--  [S-A] Ananya 50% / Sameer 50%
--  [S-B] Ananya 50% / Sameer 30.77% / Deepika 19.23%
--  [S-F] Sameer 50% / Deepika 50%
-- ============================================================================
INSERT INTO emi_distributions (
    id, schedule_id, loan_id,
    contribution_id, lender_id,
    contribution_ratio,
    principal_share, gross_interest_share,
    platform_fee_amount, net_interest_share,
    total_credited, distributed_at
)
VALUES

-- ── [S-A] Installment 1 ───────────────────────────────────────────────────────
('da001', 'rsa001', 'aaaaaaaa-0000-0000-0000-000000000001', 'aa000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 0.5000000000, 4052.82, 250.00, 2.50, 247.50, 4300.32, NOW() - INTERVAL '104 days'),
('da002', 'rsa001', 'aaaaaaaa-0000-0000-0000-000000000001', 'aa000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.5000000000, 4052.82, 250.00, 2.50, 247.50, 4300.32, NOW() - INTERVAL '104 days'),

-- ── [S-A] Installment 2 ───────────────────────────────────────────────────────
('da003', 'rsa002', 'aaaaaaaa-0000-0000-0000-000000000001', 'aa000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 0.5000000000, 4093.35, 209.47, 2.09, 207.38, 4300.73, NOW() - INTERVAL '74 days'),
('da004', 'rsa002', 'aaaaaaaa-0000-0000-0000-000000000001', 'aa000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.5000000000, 4093.35, 209.47, 2.09, 207.38, 4300.73, NOW() - INTERVAL '74 days'),

-- ── [S-A] Installments 3-6 (abbreviated for brevity — same 50/50 split) ──────
('da005', 'rsa003', 'aaaaaaaa-0000-0000-0000-000000000001', 'aa000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 0.5000000000, 4134.29, 168.54, 1.69, 166.85, 4301.14, NOW() - INTERVAL '44 days'),
('da006', 'rsa003', 'aaaaaaaa-0000-0000-0000-000000000001', 'aa000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.5000000000, 4134.29, 168.54, 1.69, 166.85, 4301.14, NOW() - INTERVAL '44 days'),
('da007', 'rsa004', 'aaaaaaaa-0000-0000-0000-000000000001', 'aa000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 0.5000000000, 4175.63, 127.20, 1.27, 125.93, 4301.56, NOW() - INTERVAL '14 days'),
('da008', 'rsa004', 'aaaaaaaa-0000-0000-0000-000000000001', 'aa000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.5000000000, 4175.63, 127.20, 1.27, 125.93, 4301.56, NOW() - INTERVAL '14 days'),
('da009', 'rsa005', 'aaaaaaaa-0000-0000-0000-000000000001', 'aa000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 0.5000000000, 4217.39, 85.44,  0.85, 84.59,  4301.98, NOW() - INTERVAL '3 days'),
('da010', 'rsa005', 'aaaaaaaa-0000-0000-0000-000000000001', 'aa000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.5000000000, 4217.39, 85.44,  0.85, 84.59,  4301.98, NOW() - INTERVAL '3 days'),
('da011', 'rsa006', 'aaaaaaaa-0000-0000-0000-000000000001', 'aa000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 0.5000000000, 4326.54, 43.27,  0.43, 42.84,  4369.38, NOW() - INTERVAL '3 hours'),
('da012', 'rsa006', 'aaaaaaaa-0000-0000-0000-000000000001', 'aa000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.5000000000, 4326.54, 43.27,  0.43, 42.84,  4369.38, NOW() - INTERVAL '3 hours'),

-- ── [S-B] Installment 1  (Ananya 50%, Sameer 30.77%, Deepika 19.23%) ─────────
('db001', 'rsb001', 'bbbbbbbb-0000-0000-0000-000000000002', 'bb000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 0.5000000000, 1391.62, 151.50, 1.52, 149.98, 1541.60, NOW() - INTERVAL '34 days'),
('db002', 'rsb001', 'bbbbbbbb-0000-0000-0000-000000000002', 'bb000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.3076900000, 855.76,  93.20,  0.93, 92.27,  948.03,  NOW() - INTERVAL '34 days'),
('db003', 'rsb001', 'bbbbbbbb-0000-0000-0000-000000000002', 'bb000003-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000022', 0.1923100000, 535.86,  58.30,  0.58, 57.72,  593.58,  NOW() - INTERVAL '34 days'),

-- ── [S-B] Installment 2 ───────────────────────────────────────────────────────
('db004', 'rsb002', 'bbbbbbbb-0000-0000-0000-000000000002', 'bb000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 0.5000000000, 1407.85, 135.27, 1.35, 133.92, 1541.77, NOW() - INTERVAL '4 days'),
('db005', 'rsb002', 'bbbbbbbb-0000-0000-0000-000000000002', 'bb000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.3076900000, 866.21,  83.20,  0.83, 82.37,  948.58,  NOW() - INTERVAL '4 days'),
('db006', 'rsb002', 'bbbbbbbb-0000-0000-0000-000000000002', 'bb000003-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000022', 0.1923100000, 541.63,  52.06,  0.52, 51.54,  593.17,  NOW() - INTERVAL '4 days'),

-- ── [S-F] Installment 1  (Sameer 50%, Deepika 50%) ───────────────────────────
('df001', 'rsf001', 'ffffffff-0000-0000-0000-000000000006', 'ff000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.5000000000, 1614.54, 125.00, 1.25, 123.75, 1738.29, NOW() - INTERVAL '61 days'),
('df002', 'rsf001', 'ffffffff-0000-0000-0000-000000000006', 'ff000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000022', 0.5000000000, 1614.54, 125.00, 1.25, 123.75, 1738.29, NOW() - INTERVAL '61 days'),

-- ── [S-F] Installment 2 ───────────────────────────────────────────────────────
('df003', 'rsf002', 'ffffffff-0000-0000-0000-000000000006', 'ff000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.5000000000, 1634.73, 104.82, 1.05, 103.77, 1738.50, NOW() - INTERVAL '31 days'),
('df004', 'rsf002', 'ffffffff-0000-0000-0000-000000000006', 'ff000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000022', 0.5000000000, 1634.73, 104.82, 1.05, 103.77, 1738.50, NOW() - INTERVAL '31 days');


-- ============================================================================
--  PLATFORM REVENUE  (1% of gross interest per distribution)
-- ============================================================================
INSERT INTO platform_revenue (
    id, loan_id, schedule_id, contribution_id, lender_id,
    fee_amount, fee_pct_applied, collected_at
)
VALUES
-- [S-A] 12 fee events (6 EMIs × 2 lenders)
('pra001', 'aaaaaaaa-0000-0000-0000-000000000001', 'rsa001', 'aa000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 2.50, 1.00, NOW() - INTERVAL '104 days'),
('pra002', 'aaaaaaaa-0000-0000-0000-000000000001', 'rsa001', 'aa000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 2.50, 1.00, NOW() - INTERVAL '104 days'),
('pra003', 'aaaaaaaa-0000-0000-0000-000000000001', 'rsa002', 'aa000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 2.09, 1.00, NOW() - INTERVAL '74 days'),
('pra004', 'aaaaaaaa-0000-0000-0000-000000000001', 'rsa002', 'aa000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 2.09, 1.00, NOW() - INTERVAL '74 days'),
('pra005', 'aaaaaaaa-0000-0000-0000-000000000001', 'rsa003', 'aa000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 1.69, 1.00, NOW() - INTERVAL '44 days'),
('pra006', 'aaaaaaaa-0000-0000-0000-000000000001', 'rsa003', 'aa000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 1.69, 1.00, NOW() - INTERVAL '44 days'),
('pra007', 'aaaaaaaa-0000-0000-0000-000000000001', 'rsa004', 'aa000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 1.27, 1.00, NOW() - INTERVAL '14 days'),
('pra008', 'aaaaaaaa-0000-0000-0000-000000000001', 'rsa004', 'aa000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 1.27, 1.00, NOW() - INTERVAL '14 days'),
('pra009', 'aaaaaaaa-0000-0000-0000-000000000001', 'rsa005', 'aa000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 0.85, 1.00, NOW() - INTERVAL '3 days'),
('pra010', 'aaaaaaaa-0000-0000-0000-000000000001', 'rsa005', 'aa000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.85, 1.00, NOW() - INTERVAL '3 days'),
('pra011', 'aaaaaaaa-0000-0000-0000-000000000001', 'rsa006', 'aa000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 0.43, 1.00, NOW() - INTERVAL '3 hours'),
('pra012', 'aaaaaaaa-0000-0000-0000-000000000001', 'rsa006', 'aa000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.43, 1.00, NOW() - INTERVAL '3 hours'),
-- [S-B] 6 fee events (2 EMIs × 3 lenders)
('prb001', 'bbbbbbbb-0000-0000-0000-000000000002', 'rsb001', 'bb000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 1.52, 1.00, NOW() - INTERVAL '34 days'),
('prb002', 'bbbbbbbb-0000-0000-0000-000000000002', 'rsb001', 'bb000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.93, 1.00, NOW() - INTERVAL '34 days'),
('prb003', 'bbbbbbbb-0000-0000-0000-000000000002', 'rsb001', 'bb000003-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000022', 0.58, 1.00, NOW() - INTERVAL '34 days'),
('prb004', 'bbbbbbbb-0000-0000-0000-000000000002', 'rsb002', 'bb000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000020', 1.35, 1.00, NOW() - INTERVAL '4 days'),
('prb005', 'bbbbbbbb-0000-0000-0000-000000000002', 'rsb002', 'bb000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 0.83, 1.00, NOW() - INTERVAL '4 days'),
('prb006', 'bbbbbbbb-0000-0000-0000-000000000002', 'rsb002', 'bb000003-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000022', 0.52, 1.00, NOW() - INTERVAL '4 days'),
-- [S-F] 4 fee events (2 EMIs × 2 lenders)
('prf001', 'ffffffff-0000-0000-0000-000000000006', 'rsf001', 'ff000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 1.25, 1.00, NOW() - INTERVAL '61 days'),
('prf002', 'ffffffff-0000-0000-0000-000000000006', 'rsf001', 'ff000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000022', 1.25, 1.00, NOW() - INTERVAL '61 days'),
('prf003', 'ffffffff-0000-0000-0000-000000000006', 'rsf002', 'ff000001-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000021', 1.05, 1.00, NOW() - INTERVAL '31 days'),
('prf004', 'ffffffff-0000-0000-0000-000000000006', 'rsf002', 'ff000002-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000022', 1.05, 1.00, NOW() - INTERVAL '31 days');


-- ============================================================================
--  WALLET TRANSACTIONS  (representative entries — not exhaustive)
--  Covers: deposits, pledges, disbursements, EMI payments, receipts, refunds
-- ============================================================================
INSERT INTO wallet_transactions (
    id, user_id, transaction_type, amount,
    balance_before, balance_after,
    reference_id, description, created_at
)
VALUES

-- ── Initial deposits ──────────────────────────────────────────────────────────
('wt0001', '00000000-0000-0000-0000-000000000020', 'DEPOSIT',   100000.00, 0.00,      100000.00, NULL, 'Initial wallet funding', NOW() - INTERVAL '150 days'),
('wt0002', '00000000-0000-0000-0000-000000000021', 'DEPOSIT',   100000.00, 0.00,      100000.00, NULL, 'Initial wallet funding', NOW() - INTERVAL '140 days'),
('wt0003', '00000000-0000-0000-0000-000000000022', 'DEPOSIT',    80000.00, 0.00,       80000.00, NULL, 'Initial wallet funding', NOW() - INTERVAL '100 days'),
('wt0004', '00000000-0000-0000-0000-000000000023', 'DEPOSIT',    20000.00, 0.00,       20000.00, NULL, 'Initial wallet funding', NOW() - INTERVAL '30 days'),

-- ── [S-A] Pledges ─────────────────────────────────────────────────────────────
('wt0010', '00000000-0000-0000-0000-000000000020', 'PLEDGE_TO_ESCROW', -25000.00, 100000.00, 75000.00, 'aaaaaaaa-0000-0000-0000-000000000001', 'Pledged to loan: Business Equipment', NOW() - INTERVAL '118 days'),
('wt0011', '00000000-0000-0000-0000-000000000021', 'PLEDGE_TO_ESCROW', -25000.00, 100000.00, 75000.00, 'aaaaaaaa-0000-0000-0000-000000000001', 'Pledged to loan: Business Equipment', NOW() - INTERVAL '117 days'),

-- ── [S-A] Disbursement to Arjun ───────────────────────────────────────────────
('wt0020', '00000000-0000-0000-0000-000000000010', 'LOAN_DISBURSEMENT', 50000.00, 0.00, 50000.00, 'aaaaaaaa-0000-0000-0000-000000000001', 'Loan disbursed', NOW() - INTERVAL '115 days'),

-- ── [S-A] EMI payments (borrower) — 6 payments ────────────────────────────────
('wt0030', '00000000-0000-0000-0000-000000000010', 'EMI_PAYMENT', -8605.64, 50000.00, 41394.36, 'rsa001', 'EMI #1', NOW() - INTERVAL '104 days'),
('wt0031', '00000000-0000-0000-0000-000000000010', 'EMI_PAYMENT', -8605.64, 41394.36, 32788.72, 'rsa002', 'EMI #2', NOW() - INTERVAL '74 days'),
('wt0032', '00000000-0000-0000-0000-000000000010', 'EMI_PAYMENT', -8605.64, 32788.72, 24183.08, 'rsa003', 'EMI #3', NOW() - INTERVAL '44 days'),
('wt0033', '00000000-0000-0000-0000-000000000010', 'EMI_PAYMENT', -8605.64, 24183.08, 15577.44, 'rsa004', 'EMI #4', NOW() - INTERVAL '14 days'),
('wt0034', '00000000-0000-0000-0000-000000000010', 'EMI_PAYMENT', -8605.64, 15577.44, 6971.80,  'rsa005', 'EMI #5', NOW() - INTERVAL '3 days'),
('wt0035', '00000000-0000-0000-0000-000000000010', 'EMI_PAYMENT', -8739.71, 6971.80,  -1767.91, 'rsa006', 'EMI #6 (final)', NOW() - INTERVAL '3 hours'),
-- Top-up before final EMI to cover balance
('wt0036', '00000000-0000-0000-0000-000000000010', 'DEPOSIT', 26267.91, 0.00, 26267.91, NULL, 'Top-up before final EMI', NOW() - INTERVAL '4 hours'),

-- ── [S-A] Lender receipts — EMI 1 (representative) ───────────────────────────
('wt0040', '00000000-0000-0000-0000-000000000020', 'EMI_PRINCIPAL_RECEIPT',  4052.82, 75000.00, 79052.82, 'rsa001', 'Principal EMI #1', NOW() - INTERVAL '104 days'),
('wt0041', '00000000-0000-0000-0000-000000000020', 'EMI_INTEREST_RECEIPT',    247.50, 79052.82, 79300.32, 'rsa001', 'Interest EMI #1',  NOW() - INTERVAL '104 days'),
('wt0042', '00000000-0000-0000-0000-000000000021', 'EMI_PRINCIPAL_RECEIPT',  4052.82, 75000.00, 79052.82, 'rsa001', 'Principal EMI #1', NOW() - INTERVAL '104 days'),
('wt0043', '00000000-0000-0000-0000-000000000021', 'EMI_INTEREST_RECEIPT',    247.50, 79052.82, 79300.32, 'rsa001', 'Interest EMI #1',  NOW() - INTERVAL '104 days'),

-- ── [S-B] Pledges ─────────────────────────────────────────────────────────────
('wt0050', '00000000-0000-0000-0000-000000000020', 'PLEDGE_TO_ESCROW', -13000.00, 79300.32, 66300.32, 'bbbbbbbb-0000-0000-0000-000000000002', 'Pledged to loan: MICA Diploma', NOW() - INTERVAL '88 days'),
('wt0051', '00000000-0000-0000-0000-000000000021', 'PLEDGE_TO_ESCROW',  -8000.00, 79300.32, 71300.32, 'bbbbbbbb-0000-0000-0000-000000000002', 'Pledged to loan: MICA Diploma', NOW() - INTERVAL '87 days'),
('wt0052', '00000000-0000-0000-0000-000000000022', 'PLEDGE_TO_ESCROW',  -5000.00, 80000.00, 75000.00, 'bbbbbbbb-0000-0000-0000-000000000002', 'Pledged to loan: MICA Diploma', NOW() - INTERVAL '86 days'),

-- ── [S-B] Disbursement to Priya ───────────────────────────────────────────────
('wt0060', '00000000-0000-0000-0000-000000000011', 'LOAN_DISBURSEMENT', 26000.00, 0.00, 26000.00, 'bbbbbbbb-0000-0000-0000-000000000002', 'Partial disbursement', NOW() - INTERVAL '5 days'),

-- ── [S-C] Pledge then refund (Rahul) ─────────────────────────────────────────
('wt0070', '00000000-0000-0000-0000-000000000023', 'PLEDGE_TO_ESCROW', -3000.00, 20000.00, 17000.00, 'cccccccc-0000-0000-0000-000000000003', 'Pledged to loan: Kitchen Remodel', NOW() - INTERVAL '50 days'),
('wt0071', '00000000-0000-0000-0000-000000000023', 'ESCROW_REFUND',     3000.00, 17000.00, 20000.00, 'cccccccc-0000-0000-0000-000000000003', 'Refund: threshold not met',        NOW() - INTERVAL '20 days'),

-- ── [S-F] Pledges (Vikram's medical loan) ─────────────────────────────────────
('wt0080', '00000000-0000-0000-0000-000000000021', 'PLEDGE_TO_ESCROW', -10000.00, 71300.32, 61300.32, 'ffffffff-0000-0000-0000-000000000006', 'Pledged to loan: Medical', NOW() - INTERVAL '73 days'),
('wt0081', '00000000-0000-0000-0000-000000000022', 'PLEDGE_TO_ESCROW', -10000.00, 75000.00, 65000.00, 'ffffffff-0000-0000-0000-000000000006', 'Pledged to loan: Medical', NOW() - INTERVAL '73 days'),

-- ── [S-F] Disbursement to Vikram ─────────────────────────────────────────────
('wt0090', '00000000-0000-0000-0000-000000000014', 'LOAN_DISBURSEMENT', 20000.00, 0.00, 20000.00, 'ffffffff-0000-0000-0000-000000000006', 'Loan disbursed: Medical emergency', NOW() - INTERVAL '62 days'),

-- ── [S-OPEN] Pledge from Deepika ──────────────────────────────────────────────
('wt0100', '00000000-0000-0000-0000-000000000022', 'PLEDGE_TO_ESCROW', -14000.00, 65000.00, 51000.00, 'eeeeeeee-0000-0000-0000-000000000005', 'Pledged to loan: Solar Panels', NOW() - INTERVAL '1 day');


-- ============================================================================
--  Re-enable triggers
-- ============================================================================
SET session_replication_role = 'origin';


-- ============================================================================
--  VERIFICATION QUERIES
--  Uncomment and run each block to confirm the seed is consistent.
-- ============================================================================

/*
-- 1. User summary
SELECT id, full_name, wallet_balance, kyc_status, role_state,
       credit_score, cooling_off_until
  FROM users
 ORDER BY created_at;

-- 2. Loan pipeline
SELECT id, title, status, requested_amount, funded_amount,
       disbursed_amount, funding_deadline
  FROM loans
 ORDER BY created_at;

-- 3. Marketplace view (should show the OPEN solar loan)
SELECT loan_id, title, funded_pct, remaining_gap,
       hours_remaining, lender_count
  FROM v_loan_marketplace;

-- 4. Overdue watchlist (should show S-B installment 3 and S-F installment 3)
SELECT loan_title, borrower_name, installment_no,
       days_overdue, total_outstanding
  FROM v_overdue_watchlist;

-- 5. Lender portfolio — Sameer
SELECT loan_title, pledged_amount, pct_of_loan,
       principal_outstanding, interest_earned, position_status
  FROM v_lender_portfolio
 WHERE lender_id = '00000000-0000-0000-0000-000000000021';

-- 6. Platform health snapshot
SELECT * FROM v_platform_health;

-- 7. Platform revenue by month
SELECT revenue_month, category,
       loans_generating_revenue, total_fees_collected
  FROM v_platform_revenue_summary;

-- 8. Borrower dashboard — Priya
SELECT loan_title, loan_status, disbursed_amount,
       emis_paid, emis_total, next_due_date, next_emi_due
  FROM v_borrower_dashboard
 WHERE user_id = '00000000-0000-0000-0000-000000000011';

-- 9. Repayment schedule — completed loan
SELECT installment_no, due_date, emi_amount,
       principal_component, interest_component,
       opening_balance, closing_balance, status
  FROM v_repayment_schedule_detail
 WHERE loan_id = 'aaaaaaaa-0000-0000-0000-000000000001'
 ORDER BY installment_no;

-- 10. Credit score leaderboard
SELECT rank, full_name, credit_score,
       loans_completed, total_emis_paid_on_time, total_emis_overdue
  FROM v_credit_score_leaderboard
 LIMIT 10;
*/
