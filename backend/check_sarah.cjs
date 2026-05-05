const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

async function check() {
  try {
    const { rows } = await pool.query("SELECT * FROM employee_subtheme_alignment WHERE employee_id = 'f4590e94-7e56-4a6d-b0c3-17892a57694c'");
    console.log("Sarah Jenkins alignments:");
    console.log(JSON.stringify(rows, null, 2));
  } catch (err) {
    console.error("Error:", err);
  } finally {
    await pool.end();
  }
}

check();
