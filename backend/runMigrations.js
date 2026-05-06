// ============================================================
// backend/runMigrations.js
// Called automatically when the backend server starts.
// Reads migration files from database/migrations/ and applies
// any that haven't been recorded in the _migrations table.
// ============================================================

const fs   = require('fs');
const path = require('path');

const MIGRATIONS_DIR = path.join(__dirname, '..', 'database', 'migrations');

async function runMigrations(pool) {
  // 1. Create tracking table if it doesn't exist
  await pool.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      id          SERIAL PRIMARY KEY,
      filename    TEXT UNIQUE NOT NULL,
      applied_at  TIMESTAMPTZ DEFAULT NOW()
    )
  `);

  // 2. Find already-applied migrations
  const { rows } = await pool.query(
    'SELECT filename FROM _migrations ORDER BY id'
  );
  const applied = new Set(rows.map(r => r.filename));

  // 3. Get all migration files sorted
  if (!fs.existsSync(MIGRATIONS_DIR)) {
    console.warn('⚠️  No migrations directory found at', MIGRATIONS_DIR);
    return;
  }

  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter(f => f.endsWith('.sql'))
    .sort();

  const pending = files.filter(f => !applied.has(f));

  if (pending.length === 0) {
    console.log('✅  DB: All migrations up to date');
    return;
  }

  console.log(`🚀  DB: Applying ${pending.length} migration(s)...`);

  // 4. Apply each pending migration in a transaction
  for (const filename of pending) {
    const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, filename), 'utf8');
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(sql);
      await client.query(
        'INSERT INTO _migrations (filename) VALUES ($1)',
        [filename]
      );
      await client.query('COMMIT');
      console.log(`  ✅  ${filename}`);
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(`  ❌  ${filename} — ${err.message}`);
      throw err; // Stop server startup on migration failure
    } finally {
      client.release();
    }
  }

  console.log('✅  DB: All migrations applied');
}

module.exports = { runMigrations };
