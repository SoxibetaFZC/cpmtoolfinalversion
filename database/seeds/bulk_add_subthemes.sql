-- ==========================================
-- BULK ADD SUB-THEMES FOR ALL PROFILES
-- ==========================================

DO $$
DECLARE
    profile_record RECORD;
    pillar_id UUID := '9ac3ee5d-836d-4313-9c31-39ee639f6d27'; -- Development Pillar
    cycle_id UUID := 'ffffffff-ffff-ffff-ffff-ffffffffffff';
BEGIN
    -- Loop through every profile
    FOR profile_record IN SELECT id FROM profiles LOOP
        
        -- Insert 4 sub-themes for each person
        INSERT INTO themes (
            employee_id, assigned_to, assigned_by, 
            cycle_id, parent_id, main_theme_id,
            title, description, category, status, 
            is_locked, start_date, end_date
        ) VALUES 
        (profile_record.id, profile_record.id, profile_record.id, cycle_id, pillar_id, pillar_id, 'Q2 Feature Delivery', 'Complete primary module features', 'Delivery Quality', 'submitted_to_manager', false, '2026-04-01', '2026-04-30'),
        (profile_record.id, profile_record.id, profile_record.id, cycle_id, pillar_id, pillar_id, 'Code Review Quality', 'Improve peer review feedback cycle', 'Delivery Quality', 'submitted_to_manager', false, '2026-04-01', '2026-04-30'),
        (profile_record.id, profile_record.id, profile_record.id, cycle_id, pillar_id, pillar_id, 'Unit Test Coverage', 'Reach 80% coverage on core logic', 'Engineering Excellence', 'submitted_to_manager', false, '2026-04-01', '2026-04-30'),
        (profile_record.id, profile_record.id, profile_record.id, cycle_id, pillar_id, pillar_id, 'Documentation Sync', 'Update API docs for new endpoints', 'Delivery Quality', 'submitted_to_manager', false, '2026-04-01', '2026-04-30');

    END LOOP;
END $$;
