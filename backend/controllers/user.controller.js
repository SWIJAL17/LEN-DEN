const { query } = require('../config/db');

// GET /api/users/profile
exports.getProfile = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, name, email, role, phone, avatar_url, wallet_balance, 
              credit_score, kyc_verified, created_at
       FROM users WHERE id = $1`,
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const user = result.rows[0];
    res.json({
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      phone: user.phone,
      avatarUrl: user.avatar_url,
      walletBalance: user.wallet_balance,
      creditScore: user.credit_score,
      kycVerified: user.kyc_verified,
      createdAt: user.created_at,
    });
  } catch (err) {
    next(err);
  }
};

// PUT /api/users/profile
exports.updateProfile = async (req, res, next) => {
  try {
    const { name, phone } = req.body;

    const result = await query(
      `UPDATE users SET name = COALESCE($1, name), phone = COALESCE($2, phone)
       WHERE id = $3
       RETURNING id, name, email, role, phone, wallet_balance, credit_score`,
      [name, phone, req.user.id]
    );

    res.json({ message: 'Profile updated.', user: result.rows[0] });
  } catch (err) {
    next(err);
  }
};

// GET /api/users/stats
exports.getStats = async (req, res, next) => {
  try {
    const userId = req.user.id;
    const role = req.user.role;

    let stats = {};

    if (role === 'borrower') {
      const loans = await query(
        `SELECT 
           COUNT(*) as total_loans,
           COALESCE(SUM(CASE WHEN status IN ('active', 'fully_funded') THEN amount ELSE 0 END), 0) as total_borrowed,
           COALESCE(SUM(CASE WHEN status = 'active' THEN funded_amount ELSE 0 END), 0) as active_amount
         FROM loans WHERE borrower_id = $1`,
        [userId]
      );
      const repayments = await query(
        `SELECT 
           COALESCE(SUM(CASE WHEN r.status = 'paid' THEN r.amount_paid ELSE 0 END), 0) as total_repaid,
           COUNT(CASE WHEN r.status = 'overdue' THEN 1 END) as overdue_count
         FROM repayments r 
         JOIN loans l ON r.loan_id = l.id 
         WHERE l.borrower_id = $1`,
        [userId]
      );
      stats = { ...loans.rows[0], ...repayments.rows[0] };
    } else if (role === 'lender') {
      const investments = await query(
        `SELECT 
           COUNT(*) as total_investments,
           COALESCE(SUM(amount), 0) as total_invested,
           COALESCE(SUM(actual_return), 0) as total_returns,
           COALESCE(SUM(expected_return - actual_return), 0) as pending_returns
         FROM loan_contributions WHERE lender_id = $1`,
        [userId]
      );
      stats = investments.rows[0];
    }

    // Wallet balance
    const wallet = await query('SELECT wallet_balance FROM users WHERE id = $1', [userId]);
    stats.walletBalance = wallet.rows[0]?.wallet_balance || 0;

    res.json(stats);
  } catch (err) {
    next(err);
  }
};
