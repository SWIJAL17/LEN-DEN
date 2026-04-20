const { query } = require('../config/db');

// GET /api/wallet
exports.getWallet = async (req, res, next) => {
  try {
    const balResult = await query('SELECT wallet_balance FROM users WHERE id = $1', [req.user.id]);
    const txResult = await query(
      `SELECT * FROM transactions WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50`,
      [req.user.id]
    );
    res.json({
      balance: balResult.rows[0]?.wallet_balance || 0,
      transactions: txResult.rows,
    });
  } catch (err) { next(err); }
};

// POST /api/wallet/deposit
exports.deposit = async (req, res, next) => {
  try {
    const { amount } = req.body;
    if (!amount || amount <= 0) return res.status(400).json({ error: 'Enter a valid amount.' });

    const result = await query(
      `UPDATE users SET wallet_balance = wallet_balance + $1 WHERE id = $2 RETURNING wallet_balance`,
      [amount, req.user.id]
    );
    await query(
      `INSERT INTO transactions (user_id, type, amount, balance_after, description)
       VALUES ($1, 'deposit', $2, $3, 'Wallet deposit')`,
      [req.user.id, amount, result.rows[0].wallet_balance]
    );
    res.json({ message: 'Deposit successful.', balance: result.rows[0].wallet_balance });
  } catch (err) { next(err); }
};

// POST /api/wallet/withdraw
exports.withdraw = async (req, res, next) => {
  try {
    const { amount } = req.body;
    if (!amount || amount <= 0) return res.status(400).json({ error: 'Enter a valid amount.' });

    const bal = await query('SELECT wallet_balance FROM users WHERE id = $1', [req.user.id]);
    if (parseFloat(bal.rows[0].wallet_balance) < amount) {
      return res.status(400).json({ error: 'Insufficient balance.' });
    }

    const result = await query(
      `UPDATE users SET wallet_balance = wallet_balance - $1 WHERE id = $2 RETURNING wallet_balance`,
      [amount, req.user.id]
    );
    await query(
      `INSERT INTO transactions (user_id, type, amount, balance_after, description)
       VALUES ($1, 'withdrawal', $2, $3, 'Wallet withdrawal')`,
      [req.user.id, amount, result.rows[0].wallet_balance]
    );
    res.json({ message: 'Withdrawal successful.', balance: result.rows[0].wallet_balance });
  } catch (err) { next(err); }
};
