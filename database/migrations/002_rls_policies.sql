-- ============================================================
-- MIGRATION 002: Row Level Security Policies
-- Date: 2026-05-06
-- Description: Pure PostgreSQL RLS. Uses current_setting()
--              set by the backend per-request instead of
--              Supabase auth.uid() / auth.email().
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE profiles                    ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_cycles               ENABLE ROW LEVEL SECURITY;
ALTER TABLE global_themes               ENABLE ROW LEVEL SECURITY;
ALTER TABLE global_subthemes            ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_subtheme_alignment ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_reviews             ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------
-- PROFILES
-- Everyone can read profiles (needed for names/initials display)
-- Only HR/HoD can insert; users can update their own
-- ----------------------------------------

DROP POLICY IF EXISTS "profiles_select_all" ON profiles;
CREATE POLICY "profiles_select_all" ON profiles
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "profiles_insert_hr_hod" ON profiles;
CREATE POLICY "profiles_insert_hr_hod" ON profiles
    FOR INSERT WITH CHECK (
        current_setting('app.current_user_id', true)::UUID IN (
            SELECT id FROM profiles WHERE role IN ('hr', 'hod')
        )
    );

DROP POLICY IF EXISTS "profiles_update_own" ON profiles;
CREATE POLICY "profiles_update_own" ON profiles
    FOR UPDATE USING (
        id = current_setting('app.current_user_id', true)::UUID
        OR current_setting('app.current_user_id', true)::UUID IN (
            SELECT id FROM profiles WHERE role IN ('hr', 'hod')
        )
    );

-- ----------------------------------------
-- REVIEW CYCLES
-- Everyone reads; only HR/HoD manages
-- ----------------------------------------

DROP POLICY IF EXISTS "cycles_select_all" ON review_cycles;
CREATE POLICY "cycles_select_all" ON review_cycles
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "cycles_manage_hr_hod" ON review_cycles;
CREATE POLICY "cycles_manage_hr_hod" ON review_cycles
    FOR ALL USING (
        current_setting('app.current_user_id', true)::UUID IN (
            SELECT id FROM profiles WHERE role IN ('hr', 'hod')
        )
    );

-- ----------------------------------------
-- GLOBAL THEMES
-- Everyone reads active themes; only HR/HoD manages
-- ----------------------------------------

DROP POLICY IF EXISTS "global_themes_select" ON global_themes;
CREATE POLICY "global_themes_select" ON global_themes
    FOR SELECT USING (is_active = true);

DROP POLICY IF EXISTS "global_themes_manage_hr_hod" ON global_themes;
CREATE POLICY "global_themes_manage_hr_hod" ON global_themes
    FOR ALL USING (
        current_setting('app.current_user_id', true)::UUID IN (
            SELECT id FROM profiles WHERE role IN ('hr', 'hod')
        )
    );

-- ----------------------------------------
-- GLOBAL SUBTHEMES
-- Everyone reads; only HR/HoD manages
-- ----------------------------------------

DROP POLICY IF EXISTS "subthemes_select_all" ON global_subthemes;
CREATE POLICY "subthemes_select_all" ON global_subthemes
    FOR SELECT USING (true);

DROP POLICY IF EXISTS "subthemes_manage_hr_hod" ON global_subthemes;
CREATE POLICY "subthemes_manage_hr_hod" ON global_subthemes
    FOR ALL USING (
        current_setting('app.current_user_id', true)::UUID IN (
            SELECT id FROM profiles WHERE role IN ('hr', 'hod')
        )
    );

-- ----------------------------------------
-- EMPLOYEE SUBTHEME ALIGNMENT
-- Employees: own only
-- Managers: own + direct reports
-- HR/HoD: all
-- ----------------------------------------

DROP POLICY IF EXISTS "alignment_select" ON employee_subtheme_alignment;
CREATE POLICY "alignment_select" ON employee_subtheme_alignment
    FOR SELECT USING (
        employee_id = current_setting('app.current_user_id', true)::UUID
        OR employee_id IN (
            SELECT id FROM profiles
            WHERE manager_id = current_setting('app.current_user_id', true)::UUID
        )
        OR current_setting('app.current_user_id', true)::UUID IN (
            SELECT id FROM profiles WHERE role IN ('hr', 'hod')
        )
    );

DROP POLICY IF EXISTS "alignment_insert_own" ON employee_subtheme_alignment;
CREATE POLICY "alignment_insert_own" ON employee_subtheme_alignment
    FOR INSERT WITH CHECK (
        employee_id = current_setting('app.current_user_id', true)::UUID
    );

DROP POLICY IF EXISTS "alignment_update" ON employee_subtheme_alignment;
CREATE POLICY "alignment_update" ON employee_subtheme_alignment
    FOR UPDATE USING (
        employee_id = current_setting('app.current_user_id', true)::UUID
        OR employee_id IN (
            SELECT id FROM profiles
            WHERE manager_id = current_setting('app.current_user_id', true)::UUID
        )
        OR current_setting('app.current_user_id', true)::UUID IN (
            SELECT id FROM profiles WHERE role IN ('hr', 'hod')
        )
    );

-- ----------------------------------------
-- MONTHLY REVIEWS
-- Employees: own only
-- Managers: own + their reports
-- HR/HoD: all
-- ----------------------------------------

DROP POLICY IF EXISTS "reviews_select" ON monthly_reviews;
CREATE POLICY "reviews_select" ON monthly_reviews
    FOR SELECT USING (
        employee_id = current_setting('app.current_user_id', true)::UUID
        OR manager_id = current_setting('app.current_user_id', true)::UUID
        OR employee_id IN (
            SELECT id FROM profiles
            WHERE manager_id = current_setting('app.current_user_id', true)::UUID
        )
        OR current_setting('app.current_user_id', true)::UUID IN (
            SELECT id FROM profiles WHERE role IN ('hr', 'hod')
        )
    );

DROP POLICY IF EXISTS "reviews_insert_own" ON monthly_reviews;
CREATE POLICY "reviews_insert_own" ON monthly_reviews
    FOR INSERT WITH CHECK (
        employee_id = current_setting('app.current_user_id', true)::UUID
    );

DROP POLICY IF EXISTS "reviews_update" ON monthly_reviews;
CREATE POLICY "reviews_update" ON monthly_reviews
    FOR UPDATE USING (
        employee_id = current_setting('app.current_user_id', true)::UUID
        OR manager_id = current_setting('app.current_user_id', true)::UUID
        OR employee_id IN (
            SELECT id FROM profiles
            WHERE manager_id = current_setting('app.current_user_id', true)::UUID
        )
        OR current_setting('app.current_user_id', true)::UUID IN (
            SELECT id FROM profiles WHERE role IN ('hr', 'hod')
        )
    );
