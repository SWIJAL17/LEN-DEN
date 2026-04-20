const { query } = require('../config/db');

// POST /api/investments
exports.fundLoan = async (req, res, next) => {
  try {
    const { loanId, amount } = req.body;
    const lenderId = req.user.id;

    if (!loanId || !amount || amount <= 0) {
      return res.status(400).json({ error: 'Valid loan ID and amount are required.' });
    }

    // Start transaction
    await query('BEGIN');

    // Check loan status and required funding
    const loanResult = await query(
      `SELECT id, amount, funded_amount, status, interest_rate, tenure_months 
       FROM loans WHERE id = $1 FOR UPDATE`,
      [loanId]
    );

    if (loanResult.rows.length === 0) {
      await query('ROLLBACK');
      return res.status(404).json({ error: 'Loan not found.' });
    }

    const loan = loanResult.rows[0];

    if (loan.status !== 'approved') {
      await query('ROLLBACK');
      return res.status(400).json({ error: 'Loan is not currently open for funding.' });
    }

    const remainingAmount = Number(loan.amount) - Number(loan.funded_amount);
    if (amount > remainingAmount) {
      await query('ROLLBACK');
      return res.status(400).json({ error: `Cannot fund more than the remaining amount: ₹${remainingAmount}` });
    }

    // Check lender's wallet balance
    const userResult = await query('SELECT wallet_balance FROM users WHERE id = $1 FOR UPDATE', [lenderId]);
    const balance = Number(userResult.rows[0].wallet_balance);

    if (balance < amount) {
      await query('ROLLBACK');
      return res.status(400).json({ error: 'Insufficient wallet balance.' });
    }

    // 1. Deduct from wallet
    const newBalance = balance - amount;
    await query('UPDATE users SET wallet_balance = $1 WHERE id = $2', [newBalance, lenderId]);

    // 2. Log transaction
    await query(
      `INSERT INTO transactions (user_id, type, amount, balance_after, reference_id, description)
       VALUES ($1, 'loan_funding', $2, $3, $4, $5)`,
      [lenderId, amount, newBalance, loanId, `Funded loan ${loanId}`]
    );

    // 3. Update loan funded amount
    const newFundedAmount = Number(loan.funded_amount) + Number(amount);
    await query('UPDATE loans SET funded_amount = $1 WHERE id = $2', [newFundedAmount, loanId]);

    // 4. Create contribution record
    // Expected return = Amount + (Amount * Interest * Tenure / 12)
    const expectedReturn = amount + (amount * (loan.interest_rate / 100) * (loan.tenure_months / 12));
    
    // Check if lender already funded this loan
    const existingContrib = await query('SELECT id FROM loan_contributions WHERE loan_id = $1 AND lender_id = $2', [loanId, lenderId]);
    
    if (existingContrib.rows.length > 0) {
      // Update existing contribution
      await query(
        `UPDATE loan_contributions 
         SET amount = amount + $1, expected_return = expected_return + $2 
         WHERE loan_id = $3 AND lender_id = $4`,
        [amount, expectedReturn, loanId, lenderId]
      );
    } else {
      // Insert new contribution
      await query(
        `INSERT INTO loan_contributions (loan_id, lender_id, amount, expected_return)
         VALUES ($1, $2, $3, $4)`,
        [loanId, lenderId, amount, expectedReturn]
      );
    }

    // Commit transaction
    // Note: The trg_check_loan_fully_funded trigger will automatically handle 
    // changing status to 'fully_funded' if funded_amount == amount
    await query('COMMIT');

    res.json({ message: 'Successfully funded loan!', newBalance });
  } catch (err) {
    await query('ROLLBACK');
    next(err);
  }
};

// GET /api/investments/my
exports.getMyInvestments = async (req, res, next) => {
  try {
    const result = await query(
      `SELECT c.id as contribution_id, c.amount as invested_amount, c.expected_return, c.status as investment_status,
              l.id as loan_id, l.title, l.interest_rate, l.tenure_months, l.status as loan_status
       FROM loan_contributions c
       JOIN loans l ON c.loan_id = l.id
       WHERE c.lender_id = $1
       ORDER BY c.created_at DESC`,
      [req.user.id]
    );

    res.json({ investments: result.rows });
  } catch (err) {
    next(err);
  }
};
