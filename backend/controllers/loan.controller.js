const { query } = require('../config/db');
const { calculateRiskScore } = require('../utils/helpers');

// POST /api/loans — Create a loan request (borrower only)
exports.createLoan = async (req, res, next) => {
  try {
    const { title, description, amount, interestRate, tenureMonths, purpose } = req.body;

    if (!title || !amount || !interestRate || !tenureMonths) {
      return res.status(400).json({ error: 'Title, amount, interest rate, and tenure are required.' });
    }
    if (amount < 100 || amount > 500000) {
      return res.status(400).json({ error: 'Loan amount must be between ₹100 and ₹5,00,000.' });
    }

    // Get borrower credit score for risk calculation
    const userRes = await query('SELECT credit_score FROM users WHERE id = $1', [req.user.id]);
    const creditScore = userRes.rows[0]?.credit_score || 650;

    const riskScore = calculateRiskScore(amount, tenureMonths, interestRate, creditScore);

    const result = await query(
      `INSERT INTO loans (borrower_id, title, description, amount, interest_rate, tenure_months, purpose, risk_score)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [req.user.id, title, description, amount, interestRate, tenureMonths, purpose, riskScore]
    );

    res.status(201).json({
      message: 'Loan request submitted for approval.',
      loan: result.rows[0],
    });
  } catch (err) {
    next(err);
  }
};

// GET /api/loans — List all approved/funded loans (marketplace)
exports.getAllLoans = async (req, res, next) => {
  try {
    const { status, risk, sort, page = 1, limit = 12 } = req.query;
    const offset = (page - 1) * limit;

    let whereClause = "WHERE l.status IN ('approved', 'fully_funded')";
    const params = [];
    let paramIndex = 1;

    if (status) {
      whereClause += ` AND l.status = $${paramIndex++}`;
      params.push(status);
    }
    if (risk) {
      whereClause += ` AND l.risk_score = $${paramIndex++}`;
      params.push(risk);
    }

    let orderBy = 'ORDER BY l.created_at DESC';
    if (sort === 'interest_high') orderBy = 'ORDER BY l.interest_rate DESC';
    if (sort === 'interest_low') orderBy = 'ORDER BY l.interest_rate ASC';
    if (sort === 'amount_high') orderBy = 'ORDER BY l.amount DESC';
    if (sort === 'amount_low') orderBy = 'ORDER BY l.amount ASC';

    params.push(limit, offset);

    const result = await query(
      `SELECT l.*, u.name as borrower_name, u.credit_score as borrower_credit,
              (SELECT COUNT(*) FROM loan_contributions lc WHERE lc.loan_id = l.id) as contributor_count
       FROM loans l
       JOIN users u ON l.borrower_id = u.id
       ${whereClause}
       ${orderBy}
       LIMIT $${paramIndex++} OFFSET $${paramIndex}`,
      params
    );

    // Get total count for pagination
    const countResult = await query(
      `SELECT COUNT(*) FROM loans l ${whereClause}`,
      params.slice(0, -2) // Remove limit and offset
    );

    res.json({
      loans: result.rows,
      pagination: {
        total: parseInt(countResult.rows[0].count),
        page: parseInt(page),
        limit: parseInt(limit),
        pages: Math.ceil(countResult.rows[0].count / limit),
      }
    });
  } catch (err) {
    next(err);
  }
};

// GET /api/loans/my — My loans (borrower) or funded loans (lender)
exports.getMyLoans = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const role = req.user.role;

    let result;
    if (role === 'borrower') {
      result = await query(
        `SELECT l.*, 
                (SELECT COUNT(*) FROM loan_contributions lc WHERE lc.loan_id = l.id) as contributor_count
         FROM loans l 
         WHERE l.borrower_id = $1 
         ORDER BY l.created_at DESC`,
        [userId]
      );
    } else {
      // Lender — get loans I've contributed to
      result = await query(
        `SELECT l.*, lc.amount as my_contribution, lc.expected_return, lc.actual_return,
                u.name as borrower_name,
                (SELECT COUNT(*) FROM loan_contributions lc2 WHERE lc2.loan_id = l.id) as contributor_count
         FROM loan_contributions lc
         JOIN loans l ON lc.loan_id = l.id
         JOIN users u ON l.borrower_id = u.id
         WHERE lc.lender_id = $1
         ORDER BY lc.created_at DESC`,
        [userId]
      );
    }

    res.json({ loans: result.rows });
  } catch (err) {
    next(err);
  }
};

// GET /api/loans/:id — Loan details with contributors and schedule
exports.getLoanDetails = async (req, res, next) => {
  try {
    const { id } = req.params;

    const loanResult = await query(
      `SELECT l.*, u.name as borrower_name, u.credit_score as borrower_credit, u.avatar_url
       FROM loans l
       JOIN users u ON l.borrower_id = u.id
       WHERE l.id = $1`,
      [id]
    );

    if (loanResult.rows.length === 0) {
      return res.status(404).json({ error: 'Loan not found.' });
    }

    // Get contributors
    const contributors = await query(
      `SELECT lc.amount, lc.expected_return, lc.created_at, u.name, u.avatar_url
       FROM loan_contributions lc
       JOIN users u ON lc.lender_id = u.id
       WHERE lc.loan_id = $1
       ORDER BY lc.created_at DESC`,
      [id]
    );

    // Get repayment schedule
    const repayments = await query(
      `SELECT * FROM repayments WHERE loan_id = $1 ORDER BY installment_no`,
      [id]
    );

    // Calculate interest details using stored function
    const loan = loanResult.rows[0];
    const interestCalc = await query(
      `SELECT * FROM calculate_compound_interest($1, $2, $3)`,
      [loan.amount, loan.interest_rate, loan.tenure_months]
    ).catch(() => ({ rows: [{ total_amount: 0, total_interest: 0, monthly_emi: 0 }] }));

    res.json({
      loan: loanResult.rows[0],
      contributors: contributors.rows,
      repayments: repayments.rows,
      interestDetails: interestCalc.rows[0],
    });
  } catch (err) {
    next(err);
  }
};
