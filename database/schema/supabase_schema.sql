-- 1. Enums (Standardizing UI Dropdowns & Statuses)
CREATE TYPE user_role AS ENUM ('employee', 'manager', 'hr');

-- Updated to match the Exact 5 dropdown options in App.jsx
CREATE TYPE theme_category AS ENUM (
  'Delivery Quality', 
  'Stakeholder Collaboration', 
  'Technical Initiative',
  'Process Improvement',
  'Leadership & Mentoring'
);

-- Theme validation statuses
CREATE TYPE theme_status AS ENUM ('draft', 'pending_review', 'approved', 'returned', 'rejected');

-- Monthly review binary results
CREATE TYPE review_result AS ENUM ('YES', 'NO', 'PENDING');


-- 2. Core Organization Tables
CREATE TABLE departments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL -- e.g., 'Engineering', 'Product', 'Sales'
);

CREATE TABLE profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  employee_id TEXT UNIQUE NOT NULL, -- e.g., 'EMP-12345'
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  job_title TEXT NOT NULL,          -- e.g., 'Frontend Developer'
  department_id UUID REFERENCES departments(id),
  role user_role DEFAULT 'employee',
  manager_id UUID REFERENCES profiles(id), 
  is_active BOOLEAN DEFAULT true,   -- Used for "Active Employees" metric
  last_sap_sync TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE review_cycles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  period_name TEXT NOT NULL,        -- e.g., 'April 2025'
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  is_active BOOLEAN DEFAULT true
);


-- 3. Employee Themes (The Evidence Engine)
CREATE TABLE themes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES profiles(id) NOT NULL,
  cycle_id UUID REFERENCES review_cycles(id) NOT NULL,
  
  -- Form Inputs
  title TEXT NOT NULL,                    -- "Theme Title"
  category theme_category NOT NULL,       -- "Category"
  description TEXT,                       -- "Short Description"
  linked_objective TEXT,                  -- "Link to Objective / Task / Project"
  achievement_evidence TEXT,              -- "Achievement Evidence" (Short input)
  supporting_evidence TEXT,               -- "Supporting Evidence / Proof Points"
  
  -- Manager Validation Workflow
  status theme_status DEFAULT 'pending_review',
  manager_comment TEXT,                   -- "Manager: Excellent delivery..."
  
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  validated_at TIMESTAMPTZ,               -- Timestamp for when manager approved/rejected
  
  updated_at TIMESTAMPTZ DEFAULT NOW()
);


-- 4. Monthly Binary Reviews (The Manager Input)
CREATE TABLE monthly_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES profiles(id) NOT NULL,
  manager_id UUID REFERENCES profiles(id) NOT NULL,
  cycle_id UUID REFERENCES review_cycles(id) NOT NULL,
  
  -- The 4 Binary Inputs
  input_contribution BOOLEAN,  -- "Contribution & Delivery"
  input_collaboration BOOLEAN, -- "Collaboration & Teamwork"
  input_consistency BOOLEAN,   -- "Consistency & Reliability"
  input_growth BOOLEAN,        -- "Growth & Initiative"
  
  -- Auto-calculated based on the "2+ Yes = Overall YES" rule
  overall_result review_result DEFAULT 'PENDING',
  
  -- Manager Feedback
  manager_comment TEXT,        -- "Add context, guidance, or feedback..."
  
  -- UI State tracking
  is_draft BOOLEAN DEFAULT true,
  submitted_at TIMESTAMPTZ,
  
  UNIQUE(employee_id, cycle_id) -- One review per employee per month
);


-- 5. Manager Directions (Directed Themes Banner)
CREATE TABLE manager_directions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id UUID REFERENCES profiles(id) NOT NULL,
  cycle_id UUID REFERENCES review_cycles(id) NOT NULL,
  directed_themes TEXT[], -- Array of categories the manager wants the employee to focus on
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(employee_id, cycle_id)
);

-- =========================================================================
-- OPTIONAL: RLS (Row Level Security) Policies
-- To ensure employees only see their own themes and managers see their team's
-- =========================================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE themes ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE manager_directions ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own profile, or if they are a manager to read their reports
CREATE POLICY "Users can view own profile or reports" ON profiles FOR SELECT
USING ( auth.uid() = id OR auth.uid() = manager_id );

-- Themes: Employees can view their own, Managers can view their reports
CREATE POLICY "View themes" ON themes FOR SELECT
USING ( auth.uid() = employee_id OR auth.uid() IN (SELECT id FROM profiles WHERE manager_id = auth.uid()) );
