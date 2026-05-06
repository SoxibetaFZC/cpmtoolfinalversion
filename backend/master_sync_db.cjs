const { Pool } = require('pg');
require('dotenv').config();

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

const sql = `
-- 1. STRENGTHEN PROFILES
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'employee';

-- 2. CREATE GLOBAL THEMES (IF MISSING)
CREATE TABLE IF NOT EXISTS global_themes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    description TEXT,
    created_by TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE global_themes ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

-- 3. CREATE GLOBAL SUBTHEMES (IF MISSING)
CREATE TABLE IF NOT EXISTS global_subthemes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    theme_id UUID REFERENCES global_themes(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. CREATE ALIGNMENT TABLE (IF MISSING)
CREATE TABLE IF NOT EXISTS employee_subtheme_alignment (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id TEXT NOT NULL,
    subtheme_id UUID REFERENCES global_subthemes(id) ON DELETE CASCADE,
    cycle_year TEXT,
    status TEXT DEFAULT 'PENDING',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    manager_feedback TEXT
);

-- 5. UPGRADE MONTHLY REVIEWS
ALTER TABLE monthly_reviews ADD COLUMN IF NOT EXISTS theme_results JSONB;
ALTER TABLE monthly_reviews ADD COLUMN IF NOT EXISTS attachments JSONB DEFAULT '[]';
ALTER TABLE monthly_reviews ADD COLUMN IF NOT EXISTS manager_comment TEXT;

-- 6. SEED INITIAL STRATEGIC PILLARS (SAFE INSERT)
INSERT INTO global_themes (id, title, description, status)
VALUES 
('11111111-1111-1111-1111-111111111111', 'Development Excellence', 'Focus on high-quality software delivery and architectural integrity.', 'active'),
('22222222-2222-2222-2222-222222222222', 'Customer Success', 'Improving response times and client satisfaction metrics.', 'active')
ON CONFLICT (id) DO NOTHING;

-- 7. SEED INITIAL SUBTHEMES (SAFE INSERT)
INSERT INTO global_subthemes (id, theme_id, title, description)
VALUES 
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'Software Testing', 'Implement 80% code coverage across all core modules.'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '22222222-2222-2222-2222-222222222222', 'Ticket Resolution', 'Reduce average response time to under 4 hours.')
ON CONFLICT (id) DO NOTHING;
`;

async function run() {
  try {
    console.log("🚀 Starting Safe Master Alignment...");
    await pool.query(sql);
    console.log("✅ Database successfully synchronized and seeded.");
    console.log("📊 Your SQL files are now 'Live' in PostgreSQL!");
  } catch (err) {
    console.error("❌ Alignment failed:", err.message);
  } finally {
    await pool.end();
  }
}

run();
