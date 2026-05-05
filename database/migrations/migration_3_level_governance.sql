-- ==========================================
-- PULSEREVIEW 3-LEVEL GOVERNANCE MIGRATION
-- ==========================================

-- 1. Extend theme_status Enum
-- Postgres doesn't allow adding values inside a transaction in some versions, 
-- but we'll provide the ALTER commands.
ALTER TYPE theme_status ADD VALUE IF NOT EXISTS 'pending_hr_approval';
ALTER TYPE theme_status ADD VALUE IF NOT EXISTS 'submitted_to_manager';
ALTER TYPE theme_status ADD VALUE IF NOT EXISTS 'reverted';

-- 2. Update themes table for Governance
ALTER TABLE themes ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES profiles(id);
ALTER TABLE themes ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES profiles(id);
ALTER TABLE themes ADD COLUMN IF NOT EXISTS is_locked BOOLEAN DEFAULT false;
ALTER TABLE themes ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE themes ADD COLUMN IF NOT EXISTS end_date DATE;

-- 3. Comments/Labels for Clarity
COMMENT ON COLUMN themes.status IS 'Manager themes: pending_hr_approval -> approved/rejected/reverted. Subthemes: submitted_to_manager -> approved/etc.';

-- 4. Audit Log Table (Optional but requested in roadmap)
CREATE TABLE IF NOT EXISTS validation_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  theme_id UUID REFERENCES themes(id),
  action TEXT NOT NULL,
  comment TEXT,
  performed_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. RLS UPDATES (Manager visibility for HR)
-- Ensure HR can see themes created by Managers
CREATE POLICY "HR can view all themes" ON themes FOR SELECT
USING ( auth.uid() IN (SELECT id FROM profiles WHERE role = 'hr') );

CREATE POLICY "Managers can view own created themes" ON themes FOR SELECT
USING ( auth.uid() = created_by );
