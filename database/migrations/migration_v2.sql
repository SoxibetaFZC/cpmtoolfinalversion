-- ==========================================
-- PERFORMANCE WORKFLOW MIGRATION V2
-- ==========================================

-- 1. Enforce 1-subtheme constraint per employee per directive
-- Any theme with a parent_id (a subtheme) must be unique for that parent and employee combination.
ALTER TABLE themes
ADD CONSTRAINT unique_subtheme_per_parent 
UNIQUE (parent_id, employee_id);

-- 2. Note on monthly_reviews data consistency
-- The columns input_contribution, input_collaboration, input_consistency, and input_growth
-- are no longer updated by the frontend. New reviews will only populate overall_result.
-- Existing data remains for historical auditing.
