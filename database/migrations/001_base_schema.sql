-- ============================================================
-- MIGRATION 001: Base Schema
-- Date: 2026-05-06
-- Description: All tables, enums, and indexes for PulseReview
--              Built from live database dump. Pure PostgreSQL.
-- ============================================================

-- ----------------------------------------
-- ENUMS
-- ----------------------------------------

DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('employee', 'manager', 'hod', 'hr');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE employment_type AS ENUM ('PERMANENT', 'PROBATION', 'CONTRACT');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE review_result AS ENUM ('YES', 'NO', 'PENDING');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE rating_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'REVERTED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE alignment_status AS ENUM ('PENDING', 'APPROVED', 'REVERTED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ----------------------------------------
-- PROFILES (employees, managers, HR, HoD)
-- ----------------------------------------

CREATE TABLE IF NOT EXISTS profiles (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id     TEXT UNIQUE NOT NULL,       -- e.g. EMP001
    first_name      TEXT NOT NULL,
    last_name       TEXT NOT NULL,
    job_title       TEXT,
    department      TEXT,
    role            user_role DEFAULT 'employee',
    employment_type employment_type DEFAULT 'PERMANENT',
    function        TEXT,
    sub_function    TEXT,
    manager_id      UUID REFERENCES profiles(id),
    auth_email      TEXT UNIQUE NOT NULL,       -- login email
    is_active       BOOLEAN DEFAULT true,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    "USERID" TEXT,
    "STATUS" TEXT,
    "User Name" TEXT,
    "First Name" TEXT,
    "Nick" TEXT,
    "Middle Name" TEXT,
    "Last Name" TEXT,
    "Suffix" TEXT,
    "Job Title" TEXT,
    "Gender" TEXT,
    "Email" TEXT,
    "Manager" TEXT,
    "Human Resource" TEXT,
    "Department" TEXT,
    "Job Code" TEXT,
    "Division" TEXT,
    "Location" TEXT,
    "Time Zone" TEXT,
    "Date of Join" TEXT,
    "Bussiness Phone" TEXT,
    "Bussiness Fax" TEXT,
    "Address Line 1" TEXT,
    "Address Line 2" TEXT,
    "City" TEXT,
    "State" TEXT,
    "Zip" TEXT,
    "Country" TEXT,
    "Matrix Manager" TEXT,
    "Default Locale" TEXT,
    "Proxy" TEXT,
    "Seating Chart" TEXT,
    "Review Frequency" TEXT,
    "Last Review Date" TEXT,
    "Company Exit Date" TEXT,
    "Date of Birth" TEXT,
    "Auto Launch PMGM Criteria" TEXT,
    "phoneInfo-Personal" TEXT,
    "Other Role" TEXT,
    "Company" TEXT,
    "Cost Center" TEXT,
    "Business Unit" TEXT,
    "Entity" TEXT,
    "Section" TEXT,
    "Sub-Section" TEXT,
    "EmailInfo-Personal" TEXT,
    "Person-id-external" TEXT,
    "PhoneInfo-Business" TEXT,
    "EmailInfo-Business" TEXT,
    "Login Method" TEXT,
    "Assignment ID" TEXT,
    "Assignment UUID" TEXT,
    "Display Name" TEXT
);

-- ----------------------------------------
-- REVIEW CYCLES (monthly periods)
-- ----------------------------------------

CREATE TABLE IF NOT EXISTS review_cycles (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    period_name TEXT NOT NULL,                  -- e.g. 'May 2026'
    start_date  DATE NOT NULL,
    end_date    DATE NOT NULL,
    is_active   TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------
-- GLOBAL THEMES (top-level pillars by HoD/HR)
-- ----------------------------------------

CREATE TABLE IF NOT EXISTS global_themes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title       TEXT NOT NULL,
    description TEXT,
    created_by  UUID REFERENCES profiles(id),
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    status      TEXT
);

-- ----------------------------------------
-- GLOBAL SUBTHEMES (under each global theme)
-- ----------------------------------------

CREATE TABLE IF NOT EXISTS global_subthemes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    theme_id    UUID NOT NULL REFERENCES global_themes(id) ON DELETE CASCADE,
    title       TEXT NOT NULL,
    description TEXT,
    start_date  TEXT,
    end_date    TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------
-- EMPLOYEE SUBTHEME ALIGNMENT
-- ----------------------------------------

CREATE TABLE IF NOT EXISTS employee_subtheme_alignment (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    subtheme_id      UUID NOT NULL REFERENCES global_subthemes(id) ON DELETE CASCADE,
    cycle_year       TEXT,
    status           alignment_status DEFAULT 'PENDING',
    manager_feedback TEXT,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (employee_id, subtheme_id, cycle_year)
);

-- ----------------------------------------
-- MONTHLY REVIEWS
-- ----------------------------------------

CREATE TABLE IF NOT EXISTS monthly_reviews (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id      UUID NOT NULL REFERENCES profiles(id),
    manager_id       UUID REFERENCES profiles(id),
    cycle_id         UUID NOT NULL REFERENCES review_cycles(id),
    overall_result   review_result DEFAULT 'PENDING',
    rating_status    rating_status DEFAULT 'PENDING',
    manager_comment  TEXT,
    emp_achievements TEXT,
    emp_blockers     TEXT,
    emp_learning     TEXT,
    emp_proof_points TEXT,
    attachments      TEXT,
    submitted_at     TIMESTAMPTZ,
    created_at       TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (employee_id, cycle_id)
);


-- ----------------------------------------
-- INDEXES
-- ----------------------------------------

CREATE INDEX IF NOT EXISTS idx_profiles_manager      ON profiles(manager_id);
CREATE INDEX IF NOT EXISTS idx_profiles_email        ON profiles(auth_email);
CREATE INDEX IF NOT EXISTS idx_profiles_role         ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_subthemes_theme       ON global_subthemes(theme_id);
CREATE INDEX IF NOT EXISTS idx_alignment_employee    ON employee_subtheme_alignment(employee_id);
CREATE INDEX IF NOT EXISTS idx_alignment_subtheme    ON employee_subtheme_alignment(subtheme_id);
CREATE INDEX IF NOT EXISTS idx_reviews_employee      ON monthly_reviews(employee_id);
CREATE INDEX IF NOT EXISTS idx_reviews_cycle         ON monthly_reviews(cycle_id);
CREATE INDEX IF NOT EXISTS idx_reviews_manager       ON monthly_reviews(manager_id);
