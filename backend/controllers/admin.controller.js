const { query } = require('../config/db');

// GET /api/admin/dashboard
exports.getDashboard = async (req, res, next) => {
  try {
    const stats = await query(`
      SELECT
        (SELECT COUNT(*) FROM users WHERE role != 'admin') as total_users,
        (SELECT COUNT(*) FROM users WHERE role = 'borrower') as total_borrowers,
        (SELECT COUNT(*) FROM users WHERE role = 'lender') as total_lenders,
        (SELECT COUNT(*) FROM loans) as total_loans,
        (SELECT COUNT(*) FROM loans WHERE status = 'pending') as pending_loans,
        (SELECT COUNT(*) FROM loans WHERE status = 'active') as active_loans,
        (SELECT COALESCE(SUM(funded_amount), 0) FROM loans) as total_volume,
        (SELECT COUNT(*) FROM loans WHERE status = 'defaulted') as defaulted_loans
    `);
    res.json(stats.rows[0]);
  } catch (err) { next(err); }
};

// GET /api/admin/loans/pending
exports.getPendingLoans = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT l.*, u.name as borrower_name, u.email as borrower_email, u.credit_score
       FROM loans l JOIN users u ON l.borrower_id = u.id
       WHERE l.status = 'pending' ORDER BY l.created_at ASC`
    );
    res.json({ loans: result.rows });
  } catch (err) { next(err); }
};

// PUT /api/admin/loans/:id/approve
exports.approveLoan = async (req, res, next) => {
  try {
    const result = await query(
      `UPDATE loans SET status = 'approved', approved_by = $1, approved_at = NOW()
       WHERE id = $2 AND status = 'pending' RETURNING *`,
      [req.user.id, req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Loan not found or already processed.' });
    res.json({ message: 'Loan approved.', loan: result.rows[0] });
  } catch (err) { next(err); }
};

// PUT /api/admin/loans/:id/reject
exports.rejectLoan = async (req, res, next) => {
  try {
    const { reason } = req.body;
    const result = await query(
      `UPDATE loans SET status = 'rejected', approved_by = $1, approved_at = NOW()
       WHERE id = $2 AND status = 'pending' RETURNING *`,
      [req.user.id, req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Loan not found or already processed.' });
    res.json({ message: 'Loan rejected.', loan: result.rows[0] });
  } catch (err) { next(err); }
};

// GET /api/admin/users
exports.getUsers = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT id, name, email, role, wallet_balance, credit_score, kyc_verified, is_active, created_at
       FROM users WHERE role != 'admin' ORDER BY created_at DESC`
    );
    res.json({ users: result.rows });
  } catch (err) { next(err); }
};

const bcrypt = require('bcryptjs');

// POST /api/admin/users
exports.createUser = async (req, res, next) => {
  try {
    const { name, email, password, role } = req.body;
    if (!name || !email || !password || !role) {
      return res.status(400).json({ error: 'Name, email, password, and role are required.' });
    }

    const existing = await query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email already registered.' });
    }

    const salt = await bcrypt.genSalt(12);
    const passwordHash = await bcrypt.hash(password, salt);

    const result = await query(
      `INSERT INTO users (name, email, password_hash, role, wallet_balance)
       VALUES ($1, $2, $3, $4, 10000.00)
       RETURNING id, name, email, role, wallet_balance, credit_score, kyc_verified, is_active, created_at`,
      [name, email, passwordHash, role]
    );

    res.status(201).json({ message: 'User created successfully.', user: result.rows[0] });
  } catch (err) { next(err); }
};
