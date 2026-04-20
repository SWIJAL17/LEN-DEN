const bcrypt = require('bcryptjs');
const { query } = require('../config/db');
const { generateToken } = require('../utils/jwt');

// POST /api/auth/signup
exports.signup = async (req, res, next) => {
  try {
    const { name, email, password, role } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ error: 'Name, email, and password are required.' });
    }
    if (role && !['borrower', 'lender'].includes(role)) {
      return res.status(400).json({ error: 'Role must be borrower or lender.' });
    }

    // Check if email already exists
    const existing = await query('SELECT id FROM users WHERE email = $1', [email]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Email already registered.' });
    }

    // Hash password
    const salt = await bcrypt.genSalt(12);
    const passwordHash = await bcrypt.hash(password, salt);

    // Insert user
    const result = await query(
      `INSERT INTO users (name, email, password_hash, role, wallet_balance)
       VALUES ($1, $2, $3, $4, 10000.00)
       RETURNING id, name, email, role, wallet_balance, created_at`,
      [name, email, passwordHash, role || null]
    );

    const user = result.rows[0];
    const token = generateToken({ id: user.id, email: user.email, role: user.role });

    res.status(201).json({
      message: 'Account created successfully.',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        walletBalance: user.wallet_balance,
      }
    });
  } catch (err) {
    next(err);
  }
};

// POST /api/auth/login
exports.login = async (req, res, next) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ error: 'Email and password are required.' });
    }

    const result = await query(
      'SELECT id, name, email, password_hash, role, wallet_balance FROM users WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const user = result.rows[0];

    if (!user.password_hash) {
      return res.status(401).json({ error: 'This account uses Google sign-in. Please use Google to log in.' });
    }

    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }

    const token = generateToken({ id: user.id, email: user.email, role: user.role });

    res.json({
      message: 'Login successful.',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        walletBalance: user.wallet_balance,
      }
    });
  } catch (err) {
    next(err);
  }
};

// POST /api/auth/google
exports.googleAuth = async (req, res, next) => {
  try {
    const { email, name, googleId } = req.body;

    if (!email || !googleId) {
      return res.status(400).json({ error: 'Email and Google ID are required.' });
    }

    // Check if user exists
    let result = await query('SELECT * FROM users WHERE email = $1 OR google_id = $2', [email, googleId]);
    let user;

    if (result.rows.length === 0) {
      // Create new user
      result = await query(
        `INSERT INTO users (name, email, google_id, wallet_balance)
         VALUES ($1, $2, $3, 10000.00)
         RETURNING id, name, email, role, wallet_balance, created_at`,
        [name, email, googleId]
      );
      user = result.rows[0];
    } else {
      user = result.rows[0];
      // Update google_id if not set
      if (!user.google_id) {
        await query('UPDATE users SET google_id = $1 WHERE id = $2', [googleId, user.id]);
      }
    }

    const token = generateToken({ id: user.id, email: user.email, role: user.role });

    res.json({
      message: user.role ? 'Login successful.' : 'Welcome! Please select your role.',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        walletBalance: user.wallet_balance,
      }
    });
  } catch (err) {
    next(err);
  }
};

// PUT /api/auth/role
exports.setRole = async (req, res, next) => {
  try {
    const { role } = req.body;
    if (!['borrower', 'lender'].includes(role)) {
      return res.status(400).json({ error: 'Role must be borrower or lender.' });
    }

    const result = await query(
      'UPDATE users SET role = $1 WHERE id = $2 RETURNING id, name, email, role, wallet_balance',
      [role, req.user.id]
    );

    const user = result.rows[0];
    const token = generateToken({ id: user.id, email: user.email, role: user.role });

    res.json({
      message: 'Role updated successfully.',
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        role: user.role,
        walletBalance: user.wallet_balance,
      }
    });
  } catch (err) {
    next(err);
  }
};
