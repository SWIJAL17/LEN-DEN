const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

async function test() {
  try {
    const res = await pool.query('SELECT NOW()');
    console.log('DB Connection SUCCESS:', res.rows[0]);
  } catch (err) {
    console.error('DB Connection FAILED:', err.message);
  } finally {
    pool.end();
  }
}
test();
