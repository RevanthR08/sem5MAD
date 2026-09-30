"""Database initialization and schema migration for Civic Connect."""
import os
from pathlib import Path
import psycopg2
from dotenv import load_dotenv

env_path = Path(__file__).resolve().parent.parent / ".env"
if env_path.exists():
    load_dotenv(dotenv_path=env_path)
load_dotenv()

DB_URL = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/postgres")

SCHEMA_SQL = """
-- Extensions
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Authorities (Municipal Corporations, Councils)
CREATE TABLE IF NOT EXISTS authorities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Zones
CREATE TABLE IF NOT EXISTS zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    authority_id UUID REFERENCES authorities(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    zone_number INT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Wards
CREATE TABLE IF NOT EXISTS wards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_id UUID REFERENCES zones(id) ON DELETE CASCADE,
    authority_id UUID REFERENCES authorities(id) ON DELETE CASCADE,
    ward_number VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    center_lat DOUBLE PRECISION,
    center_lng DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Departments
CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    authority_id UUID REFERENCES authorities(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    head_officer_name VARCHAR(150),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(authority_id, code)
);

-- Users & Profiles
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(50) UNIQUE,
    full_name VARCHAR(150) NOT NULL,
    role VARCHAR(50) NOT NULL DEFAULT 'CITIZEN',
    department_id UUID REFERENCES departments(id),
    authority_id UUID REFERENCES authorities(id),
    ward_id UUID REFERENCES wards(id),
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Categories & Subcategories
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    icon VARCHAR(50) NOT NULL,
    description TEXT,
    default_sla_hours INT DEFAULT 48,
    duplicate_radius_meters INT DEFAULT 50,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subcategories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    sla_hours INT DEFAULT 48,
    priority_level VARCHAR(20) DEFAULT 'MEDIUM',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(category_id, code)
);

-- Routing Rules
CREATE TABLE IF NOT EXISTS routing_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    authority_id UUID REFERENCES authorities(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    department_id UUID REFERENCES departments(id) ON DELETE CASCADE,
    ward_id UUID REFERENCES wards(id) ON DELETE SET NULL,
    priority INT DEFAULT 1,
    active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Reports Core Table
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    public_id VARCHAR(50) UNIQUE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    is_anonymous BOOLEAN DEFAULT FALSE,
    reporter_name VARCHAR(150),
    reporter_contact VARCHAR(150),
    category_id UUID REFERENCES categories(id),
    subcategory_id UUID REFERENCES subcategories(id),
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'SUBMITTED',
    priority VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    severity VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    location GEOGRAPHY(Point, 4326),
    address TEXT,
    landmark TEXT,
    authority_id UUID REFERENCES authorities(id),
    department_id UUID REFERENCES departments(id),
    zone_id UUID REFERENCES zones(id),
    ward_id UUID REFERENCES wards(id),
    assigned_to UUID REFERENCES users(id),
    assigned_team VARCHAR(100),
    custom_fields JSONB DEFAULT '{}'::jsonb,
    sla_hours INT DEFAULT 48,
    sla_deadline TIMESTAMPTZ,
    is_overdue BOOLEAN DEFAULT FALSE,
    upvotes INT DEFAULT 1,
    parent_duplicate_id UUID REFERENCES reports(id),
    resolution_notes TEXT,
    resolution_before_photo TEXT,
    resolution_after_photo TEXT,
    citizen_verified BOOLEAN,
    citizen_feedback TEXT,
    resolved_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Spatial index on reports location
CREATE INDEX IF NOT EXISTS idx_reports_location ON reports USING GIST(location);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_category ON reports(category_id);
CREATE INDEX IF NOT EXISTS idx_reports_ward ON reports(ward_id);

-- Report Media
CREATE TABLE IF NOT EXISTS report_media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_id UUID REFERENCES reports(id) ON DELETE CASCADE,
    media_type VARCHAR(20) DEFAULT 'PHOTO',
    url TEXT NOT NULL,
    caption TEXT,
    is_resolution_proof BOOLEAN DEFAULT FALSE,
    stage VARCHAR(20) DEFAULT 'SUBMISSION',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Report Timeline & Status History
CREATE TABLE IF NOT EXISTS report_timeline (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_id UUID REFERENCES reports(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    actor_name VARCHAR(150),
    actor_role VARCHAR(50),
    event_type VARCHAR(100) NOT NULL,
    old_status VARCHAR(50),
    new_status VARCHAR(50),
    notes TEXT,
    media_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Subscriptions / Followers
CREATE TABLE IF NOT EXISTS report_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_id UUID REFERENCES reports(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(report_id, user_id)
);
"""

def init_db():
    print("Connecting to Supabase PostgreSQL...")
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    print("Executing schema migration...")
    cur.execute(SCHEMA_SQL)
    conn.commit()
    print("Migration executed successfully!")
    cur.close()
    conn.close()

if __name__ == "__main__":
    init_db()
