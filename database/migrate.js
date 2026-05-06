#!/usr/bin/env node
// ============================================================
// database/migrate.js - PulseReview Migration Runner
//
// Commands:
//   node migrate.js              → run all pending migrations
//   node migrate.js status       → show what is applied / pending
//   node migrate.js create <name>→ create a new migration file
//
// Requires: DATABASE_URL in .env or environment
// ============================================================

const { Pool } = require('pg');
const fs = require('fs');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', 'backend', '.env') });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/postgres',
});

const MIGRATIONS_DIR = path.join(__dirname, 'migrations');

// ----------------------------------------
// Create _migrations tracking table if not exists
// ----------------------------------------
async function ensureTrackingTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      id          SERIAL PRIMARY KEY,
      filename    TEXT UNIQUE NOT NULL,
      applied_at  TIMESTAMPTZ DEFAULT NOW()
    )
  `);
}

// ----------------------------------------
// Get filenames of already-applied migrations
// ----------------------------------------
async function getApplied() {
  const { rows } = await pool.query(
    'SELECT filename FROM _migrations ORDER BY id'
  );
  return rows.map(r => r.filename);
}

// ----------------------------------------
// Get all .sql files in migrations/ sorted by name
// ----------------------------------------
function getAllFiles() {
  if (!fs.existsSync(MIGRATIONS_DIR)) {
    console.error(`❌  Migrations folder not found: ${MIGRATIONS_DIR}`);
    process.exit(1);
  }
  return fs
    .readdirSync(MIGRATIONS_DIR)
    .filter(f => f.endsWith('.sql'))
    .sort();
}

// ----------------------------------------
// Apply a single migration inside a transaction
// ----------------------------------------
async function applyMigration(filename) {
  const filepath = path.join(MIGRATIONS_DIR, filename);
  const sql = fs.readFileSync(filepath, 'utf8');
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
    console.error(`  ❌  ${filename}`);
    console.error(`      ${err.message}`);
    throw err;
  } finally {
    client.release();
  }
}

// ----------------------------------------
// STATUS command
// ----------------------------------------
async function cmdStatus() {
  await ensureTrackingTable();
  const applied = await getApplied();
  const files = getAllFiles();

  console.log('\n📋  PulseReview Migration Status');
  console.log('─'.repeat(55));
  console.log('  Status      File');
  console.log('─'.repeat(55));

  if (files.length === 0) {
    console.log('  (no migration files found)');
  }

  files.forEach(f => {
    const tick = applied.includes(f) ? '✅  applied ' : '⏳  pending ';
    console.log(`  ${tick}  ${f}`);
  });

  const pending = files.filter(f => !applied.includes(f));
  console.log('─'.repeat(55));
  console.log(`  Total: ${files.length}  |  Applied: ${applied.length}  |  Pending: ${pending.length}`);
  console.log('');
}

// ----------------------------------------
// RUN command (default)
// ----------------------------------------
async function cmdRun() {
  await ensureTrackingTable();
  const applied = await getApplied();
  const files = getAllFiles();
  const pending = files.filter(f => !applied.includes(f));

  if (pending.length === 0) {
    console.log('\n✅  All migrations already applied. Nothing to do.\n');
    return;
  }

  console.log(`\n🚀  Running ${pending.length} pending migration(s)...\n`);
  for (const filename of pending) {
    await applyMigration(filename);
  }
  console.log('\n✅  Done. All migrations applied successfully.\n');
}

// ----------------------------------------
// CREATE command: scaffold a new migration file
// ----------------------------------------
function cmdCreate(name) {
  if (!name) {
    console.error('\n❌  Please provide a migration name.');
    console.error('    Example: node migrate.js create add_notifications_table\n');
    process.exit(1);
  }

  const files = getAllFiles();
  const lastNum = files.length > 0
    ? parseInt(files[files.length - 1].split('_')[0], 10)
    : 0;
  const nextNum = String(lastNum + 1).padStart(3, '0');
  const slug = name.toLowerCase().replace(/\s+/g, '_');
  const filename = `${nextNum}_${slug}.sql`;
  const filepath = path.join(MIGRATIONS_DIR, filename);
  const today = new Date().toISOString().split('T')[0];

  const template = `-- ============================================================
-- MIGRATION ${nextNum}: ${name}
-- Date: ${today}
-- Description: 
-- ============================================================

-- Write your SQL here

`;

  fs.writeFileSync(filepath, template);
  console.log(`\n✅  Created: database/migrations/${filename}\n`);
  console.log('    Edit the file, then run:');
  console.log('      node database/migrate.js\n');
}

// ----------------------------------------
// Entry point
// ----------------------------------------
const [,, command, ...args] = process.argv;

(async () => {
  try {
    if (command === 'status') {
      await cmdStatus();
    } else if (command === 'create') {
      cmdCreate(args.join(' '));
      process.exit(0);
    } else {
      await cmdRun();
    }
  } catch {
    console.error('\n💥  Migration failed. All changes were rolled back.\n');
    process.exit(1);
  } finally {
    await pool.end();
  }
})();
