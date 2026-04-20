const { getClient, query } = require('../config/db');

// POST /api/repayments — Make a repayment (ATOMIC)
exports.makeRepayment = async (req, res, next) => {
  const client = await getClient();
  try {
    const { repaymentId } = req.body;
    const borrowerId = req.user.id;

    await client.query('BEGIN');

    // Get repayment details
    const repResult = await client.query(
      `SELECT r.*, l.borrower_id, l.title, l.amount as loan_amount
       FROM repayments r JOIN loans l ON r.loan_id = l.id
       WHERE r.id = $1 FOR UPDATE`, [repaymentId]
    );

    if (repResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Repayment not found.' });
    }

    const repayment = repResult.rows[0];
    if (repayment.borrower_id !== borrowerId) {
      await client.query('ROLLBACK');
      return res.status(403).json({ error: 'Not your loan.' });
    }
    if (repayment.status === 'paid') {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Already paid.' });
    }

    const amountDue = parseFloat(repayment.amount_due) + parseFloat(repayment.penalty);

    // Check borrower balance
    const borrowerRes = await client.query(
      'SELECT wallet_balance FROM users WHERE id = $1 FOR UPDATE', [borrowerId]
    );
    const balance = parseFloat(borrowerRes.rows[0].wallet_balance);
    if (balance < amountDue) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Insufficient balance.' });
    }

    // Deduct from borrower
    await client.query(
      'UPDATE users SET wallet_balance = wallet_balance - $1 WHERE id = $2',
      [amountDue, borrowerId]
    );

    // Mark repayment as paid
    await client.query(
      `UPDATE repayments SET status = 'paid', amount_paid = $1, paid_date = NOW()
       WHERE id = $2`, [amountDue, repaymentId]
    );

    // Record borrower transaction
    await client.query(
      `INSERT INTO transactions (user_id, type, amount, balance_after, reference_id, description)
       VALUES ($1, 'repayment_out', $2, $3, $4, $5)`,
      [borrowerId, amountDue, balance - amountDue, repayment.loan_id, `Repayment for: ${repayment.title}`]
    );

    // Distribute to lenders proportionally
    const contributions = await client.query(
      `SELECT lc.*, l.amount as loan_amount FROM loan_contributions lc
       JOIN loans l ON lc.loan_id = l.id WHERE lc.loan_id = $1`,
      [repayment.loan_id]
    );

    for (const c of contributions.rows) {
      const proportion = parseFloat(c.amount) / parseFloat(c.loan_amount);
      const lenderShare = parseFloat((amountDue * proportion).toFixed(2));
      await client.query(
        'UPDATE users SET wallet_balance = wallet_balance + $1 WHERE id = $2',
        [lenderShare, c.lender_id]
      );
      await client.query(
        'UPDATE loan_contributions SET actual_return = actual_return + $1 WHERE id = $2',
        [lenderShare, c.id]
      );
      const lBal = await client.query('SELECT wallet_balance FROM users WHERE id = $1', [c.lender_id]);
      await client.query(
        `INSERT INTO transactions (user_id, type, amount, balance_after, reference_id, description)
         VALUES ($1, 'repayment_in', $2, $3, $4, $5)`,
        [c.lender_id, lenderShare, lBal.rows[0].wallet_balance, repayment.loan_id, `Repayment received for: ${repayment.title}`]
      );
    }

    // Check if all repayments are done
    const remaining = await client.query(
      `SELECT COUNT(*) FROM repayments WHERE loan_id = $1 AND status != 'paid'`,
      [repayment.loan_id]
    );
    if (parseInt(remaining.rows[0].count) === 0) {
      await client.query(`UPDATE loans SET status = 'completed' WHERE id = $1`, [repayment.loan_id]);
    }

    await client.query('COMMIT');
    res.json({ message: 'Repayment successful.', amountPaid: amountDue });
  } catch (err) {
    await client.query('ROLLBACK');
    next(err);
  } finally {
    client.release();
  }
};

// GET /api/repayments/:loanId
exports.getRepaymentSchedule = async (req, res, next) => {
  try {
    const result = await query(
      'SELECT * FROM repayments WHERE loan_id = $1 ORDER BY installment_no',
      [req.params.loanId]
    );
    res.json({ repayments: result.rows });
  } catch (err) {
    next(err);
  }
};
