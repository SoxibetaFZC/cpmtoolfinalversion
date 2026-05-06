# CPMTool — Database Migration Guide

## Folder Structure

```
cpmtool/
│
├── database/
│   ├── migrations/
│   │   ├── 001_base_schema.sql           ← Tables, enums, indexes
│   │   ├── 002_rls_policies.sql          ← Row Level Security
│   │   ├── 003_seed_admin.sql            ← Admin user + first cycle
│   │   └── 004_example_add_notifications.sql  ← Example new migration
│   └── migrate.js                        ← CLI migration runner
│
├── backend/
│   ├── server.js                         ← Express server (runs migrations on startup)
│   ├── runMigrations.js                  ← Migration engine used by server.js
│   ├── package.json                      ← npm scripts for migrations
│   └── .env.example                      ← Environment variable template
```

---

## How the Migration System Works

A `_migrations` table is automatically created in your database:

```
_migrations
┌────┬────────────────────────────────────┬─────────────────────────┐
│ id │ filename                           │ applied_at              │
├────┼────────────────────────────────────┼─────────────────────────┤
│  1 │ 001_base_schema.sql                │ 2026-05-06 10:00:00+00  │
│  2 │ 002_rls_policies.sql               │ 2026-05-06 10:00:01+00  │
│  3 │ 003_seed_admin.sql                 │ 2026-05-06 10:00:01+00  │
└────┴────────────────────────────────────┴─────────────────────────┘
```

**Rules:**
- Each migration runs in a **transaction** — if it fails, it rolls back completely
- Once applied, a migration is **never re-run**
- Files run in **alphabetical/numeric order** (001, 002, 003...)
- **Never edit** an already-applied migration — create a new one instead

---

## Fresh Setup (First Time)

### Step 1 — Create your database

```bash
psql -U postgres -c "CREATE DATABASE cpmtool;"
```

### Step 2 — Configure environment

```bash
cd backend
cp .env.example .env
# Edit .env and set DATABASE_URL, JWT_SECRET
```

### Step 3 — Start the backend (auto-runs migrations)

```bash
cd backend
npm install
npm run dev
```

Output you'll see:
```
🚀  PulseReview backend starting on http://localhost:5000
🚀  DB: Applying 3 migration(s)...
  ✅  001_base_schema.sql
  ✅  002_rls_policies.sql
  ✅  003_seed_admin.sql
✅  DB: All migrations applied
✅  Server ready
```


## Running Migrations Manually (CLI)

From the project root:

```bash
# Run all pending migrations
node database/migrate.js

# Check status — see what is applied and what is pending
node database/migrate.js status

# Create a new migration file (auto-numbered)
node database/migrate.js create add_audit_log_table
```

Or from the backend folder using npm scripts:

```bash
cd backend
npm run migrate             # run pending
npm run migrate:status      # check status
npm run migrate:create -- add_audit_log_table  # create new
```

---

## How to Create a New Migration (Step by Step)

### Example: You want to add an `audit_log` table

**Step 1 — Create the migration file**

```bash
node database/migrate.js create add_audit_log_table
```

This creates: `database/migrations/005_add_audit_log_table.sql`

**Step 2 — Write your SQL**

```sql
-- ============================================================
-- MIGRATION 005: Add Audit Log Table
-- Date: 2026-06-01
-- Description: Track all status changes for compliance
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_log (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    table_name   TEXT NOT NULL,
    record_id    UUID NOT NULL,
    action       TEXT NOT NULL,       -- INSERT / UPDATE / DELETE
    changed_by   UUID REFERENCES profiles(id),
    old_values   JSONB,
    new_values   JSONB,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_record ON audit_log(record_id);
CREATE INDEX IF NOT EXISTS idx_audit_table  ON audit_log(table_name);
```

**Step 3 — Apply it**

```bash
# Option A: Restart the backend (auto-applies on startup)
npm run dev

# Option B: Run manually
node database/migrate.js
```

Output:
```
🚀  Running 1 pending migration(s)...
  ✅  005_add_audit_log_table.sql
✅  Done.
```

**Step 4 — Verify**

```bash
node database/migrate.js status
```

```
📋  PulseReview Migration Status
───────────────────────────────────────────────────────
  Status      File
───────────────────────────────────────────────────────
  ✅  applied   001_base_schema.sql
  ✅  applied   002_rls_policies.sql
  ✅  applied   003_seed_admin.sql
  ✅  applied   005_add_audit_log_table.sql
───────────────────────────────────────────────────────
  Total: 4  |  Applied: 4  |  Pending: 0
```

---

## Common Migration Patterns

### Add a column
```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone TEXT;
```

### Add a new enum value
```sql
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'superadmin';
```

### Add a table with RLS
```sql
CREATE TABLE IF NOT EXISTS my_table (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ...
);

ALTER TABLE my_table ENABLE ROW LEVEL SECURITY;

CREATE POLICY "my_table_select" ON my_table
    FOR SELECT USING (true);
```

### Rename a column (non-destructive)
```sql
-- Add new column
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS full_name TEXT;

-- Copy data
UPDATE profiles SET full_name = first_name || ' ' || last_name;

-- Drop old in a LATER migration (after verifying app works)
```

### Insert reference data
```sql
INSERT INTO review_cycles (id, period_name, start_date, end_date, is_active)
VALUES (gen_random_uuid(), 'June 2026', '2026-06-01', '2026-06-30', true)
ON CONFLICT DO NOTHING;
```

---

## Golden Rules

| ✅ Do                                         | ❌ Never                              |
|-----------------------------------------------|---------------------------------------|
| Number files sequentially (005_, 006_)        | Edit an already-applied migration     |
| Use `IF NOT EXISTS` for all CREATE statements | Delete migration files                |
| Use `ON CONFLICT DO NOTHING` for inserts      | Skip migration numbers                |
| One concern per migration file                | Apply migrations directly on prod DB without testing locally first |
| Test locally before deploying                 | Put rollback logic in the same file   |

---

## Kubernetes / Production Deployment

In K8s the backend pod auto-runs migrations on startup. No separate job needed.

```
Pod starts
  └── server.js
        └── runMigrations(pool)
              ├── checks _migrations table
              ├── finds pending files
              └── applies them before accepting traffic
```

If a migration fails the pod logs the error but still starts — so your app keeps running even if a migration has an issue. You can then fix and redeploy.
