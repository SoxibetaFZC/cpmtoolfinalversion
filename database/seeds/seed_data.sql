-- Seed data for testing the UI
-- RUN AFTER CREATING THE TABLES

-- 1. Create a dummy authenticated user if you are bypassing Supabase Auth for now.
-- If you are enforcing auth, you will need to replace the id with real UUIDs from auth.users
-- For this test, you'll need to temporally disable the `auth.users` foreign key on profiles, OR just insert dummy auth users if your RLS / config allows.
-- A simpler approach for UI testing without full Auth is to temporarily REMOVE the "REFERENCES auth.users(id)" constraint. 
-- Assuming you have done that or are using safe UUIDs:

-- Insert Departments
INSERT INTO departments (id, name) VALUES 
('11111111-1111-1111-1111-111111111111', 'Engineering'),
('22222222-2222-2222-2222-222222222222', 'Product');

-- Insert Profiles (James Okafor as Manager, Sarah Mitchell as Employee)
INSERT INTO profiles (id, employee_id, first_name, last_name, job_title, department_id, role, manager_id, is_active) VALUES 
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'EMP-MGR1', 'James', 'Okafor', 'Engineering Lead', '11111111-1111-1111-1111-111111111111', 'manager', NULL, true);

INSERT INTO profiles (id, employee_id, first_name, last_name, job_title, department_id, role, manager_id, is_active) VALUES 
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'EMP-12345', 'Sarah', 'Mitchell', 'Frontend Developer', '11111111-1111-1111-1111-111111111111', 'employee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true),
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'EMP-12346', 'David', 'Osei', 'Backend Developer', '11111111-1111-1111-1111-111111111111', 'employee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true),
('dddddddd-dddd-dddd-dddd-dddddddddddd', 'EMP-12347', 'Priya', 'Nair', 'QA Engineer', '11111111-1111-1111-1111-111111111111', 'employee', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', true);

-- Insert Review Cycle
INSERT INTO review_cycles (id, period_name, start_date, end_date, is_active) VALUES 
('ffffffff-ffff-ffff-ffff-ffffffffffff', 'Apr 2025', '2025-04-01', '2025-04-30', true);

-- Insert a Mock Theme for Sarah
INSERT INTO themes (employee_id, cycle_id, title, category, description, status) VALUES 
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'Dashboard Performance Refactor', 'Delivery Quality', 'Refactored the main analytics dashboard reducing load time from 4.2s to 0.9s.', 'approved'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'ffffffff-ffff-ffff-ffff-ffffffffffff', 'API Integration with Finance Team', 'Stakeholder Collaboration', 'Led cross-functional sessions with Finance.', 'pending_review');

-- Insert Mock Review for David
INSERT INTO monthly_reviews (employee_id, manager_id, cycle_id, input_contribution, input_collaboration, input_consistency, input_growth, overall_result, is_draft) VALUES 
('cccccccc-cccc-cccc-cccc-cccccccccccc', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ffffffff-ffff-ffff-ffff-ffffffffffff', true, true, true, true, 'YES', false);
