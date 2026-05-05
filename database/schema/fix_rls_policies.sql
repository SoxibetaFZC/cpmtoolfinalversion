-- ==========================================
-- FIX RLS POLICIES FOR 3-LEVEL GOVERNANCE
-- ==========================================

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "View themes" ON themes;
DROP POLICY IF EXISTS "Insert themes" ON themes;
DROP POLICY IF EXISTS "Update themes" ON themes;
DROP POLICY IF EXISTS "View themes v2" ON themes;
DROP POLICY IF EXISTS "Insert themes v2" ON themes;
DROP POLICY IF EXISTS "Update themes v2" ON themes;

-- 1. SELECT: Allow viewing own themes, themes assigned to me, themes I assigned, 
-- or themes of my direct reports. Also allow viewing 'approved' pillars.
CREATE POLICY "View themes_final" ON themes FOR SELECT
USING (
    employee_id IN (SELECT id FROM profiles WHERE auth_email = auth.email())
    OR assigned_to IN (SELECT id FROM profiles WHERE auth_email = auth.email())
    OR assigned_by IN (SELECT id FROM profiles WHERE auth_email = auth.email())
    OR employee_id IN (
        SELECT id FROM profiles 
        WHERE manager_id IN (SELECT id FROM profiles WHERE auth_email = auth.email())
    )
    OR status = 'approved'
    OR is_locked = true
);

-- 2. INSERT: Allow inserting themes for myself or for my reports.
CREATE POLICY "Insert themes_final" ON themes FOR INSERT
WITH CHECK (
    employee_id IN (SELECT id FROM profiles WHERE auth_email = auth.email())
    OR assigned_by IN (SELECT id FROM profiles WHERE auth_email = auth.email())
);

-- 3. UPDATE: Allow updating own themes or themes of direct reports (for review).
CREATE POLICY "Update themes_final" ON themes FOR UPDATE
USING (
    employee_id IN (SELECT id FROM profiles WHERE auth_email = auth.email())
    OR employee_id IN (
        SELECT id FROM profiles 
        WHERE manager_id IN (SELECT id FROM profiles WHERE auth_email = auth.email())
    )
);

-- 4. DELETE: Allow deleting own themes if not approved.
CREATE POLICY "Delete themes_final" ON themes FOR DELETE
USING (
    employee_id IN (SELECT id FROM profiles WHERE auth_email = auth.email())
    AND status != 'approved'
);

-- 5. Profiles visibility (Ensure everyone can see everyone else for initials/names)
DROP POLICY IF EXISTS "View profiles" ON profiles;
CREATE POLICY "View profiles_final" ON profiles FOR SELECT USING (true);
