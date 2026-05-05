-- Migration: 3-Level Recursive Governance (Final)
-- Goal: Seal the gap between Employees, Mid-Managers (L2), and Director (Satya, L3)

-- 1. Extend Status Enum for 3-Level Workflow
-- Note: 'pending_director_approval' is for when L2 (Mid-Manager) submits the branch to L3 (Director)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_enum e ON t.oid = e.enumtypid WHERE t.typname = 'theme_status' AND e.enumlabel = 'pending_director_approval') THEN
        ALTER TYPE theme_status ADD VALUE 'pending_director_approval';
    END IF;
END $$;

-- 2. Ensure Recursive Theme Columns exist
-- (Checking for safety, though previously seen in schema)
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'themes' AND column_name = 'parent_id') THEN
        ALTER TABLE themes ADD COLUMN parent_id UUID REFERENCES themes(id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'themes' AND column_name = 'main_theme_id') THEN
        ALTER TABLE themes ADD COLUMN main_theme_id UUID REFERENCES themes(id);
    END IF;
END $$;

-- 3. Seed Year 2025 Strategic Pillars for Satya (The "ROOT" Themes)
-- These 5 pillars are broadcasted to all subordinates
INSERT INTO themes (
    id, 
    employee_id, 
    cycle_id, 
    title, 
    category, 
    description, 
    status, 
    is_locked
)
VALUES 
    ('e1e1e1e1-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000400116', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'Development Excellence', 'Technical Initiative', 'Global yearly focus on core engineering and architecture.', 'approved', true),
    ('e1e1e1e1-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000400116', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'Global Testing & Quality', 'Delivery Quality', 'Continuous integration and quality automation pillar.', 'approved', true),
    ('e1e1e1e1-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000400116', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'Training & Mentorship', 'Leadership & Mentoring', 'Upskilling the organization through knowledge sharing.', 'approved', true),
    ('e1e1e1e1-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000400116', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'Strategic Marketing', 'Stakeholder Collaboration', 'Improving market visibility and client trust.', 'approved', true),
    ('e1e1e1e1-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000400116', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'Client Handling & Support', 'Stakeholder Collaboration', 'Excellence in customer response and lifecycle management.', 'approved', true)
ON CONFLICT (id) DO NOTHING;

-- 4. Recursive RLS Policies (Allowing branch visibility)
-- Policy: Managers can see themes where they are the manager_id of the theme owner 
-- AND they can see themes where they are the 'assigned_by' or 'assigned_to'.

DROP POLICY IF EXISTS "View themes" ON themes;
CREATE POLICY "View themes" ON themes FOR SELECT
USING ( 
    auth.uid() = employee_id -- My own
    OR auth.uid() IN (SELECT id FROM profiles WHERE manager_id = auth.uid()) -- My direct reports
    OR auth.uid() IN ( -- Managers of my manager (Director view)
        SELECT p2.id FROM profiles p1 
        JOIN profiles p2 ON p1.manager_id = p2.id 
        WHERE p1.id = themes.employee_id AND p2.id = auth.uid()
    )
    OR status = 'approved' -- Public view for yearly pillars
);

-- 5. Manager Bridge Modification
-- Allow managers to update themes they are "assigned_by" to add their supplement
DROP POLICY IF EXISTS "Update themes for managers" ON themes;
CREATE POLICY "Update themes for managers" ON themes FOR UPDATE
USING ( 
    auth.uid() = employee_id 
    OR auth.uid() IN (SELECT id FROM profiles WHERE manager_id = auth.uid())
);
