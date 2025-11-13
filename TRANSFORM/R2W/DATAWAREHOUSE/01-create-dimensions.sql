-- ============================================================
-- FOOTBALL DATA WAREHOUSE - DIMENSION TABLES
-- Star Schema Design
-- ============================================================

-- Create schema for data warehouse
CREATE SCHEMA IF NOT EXISTS dw;

-- ============================================================
-- DIMENSION: Date
-- Standard date dimension for all time-based analysis
-- ============================================================
CREATE TABLE dw.dim_date (
    date_sk SERIAL PRIMARY KEY,
    date_value DATE NOT NULL UNIQUE,
    year INTEGER NOT NULL,
    quarter INTEGER NOT NULL,
    month INTEGER NOT NULL,
    month_name VARCHAR(20) NOT NULL,
    day INTEGER NOT NULL,
    day_of_week INTEGER NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    week_of_year INTEGER NOT NULL,
    is_weekend BOOLEAN NOT NULL,
    is_holiday BOOLEAN DEFAULT FALSE,
    season_name VARCHAR(10), -- e.g., '24/25'
    CONSTRAINT check_quarter CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT check_month CHECK (month BETWEEN 1 AND 12),
    CONSTRAINT check_day CHECK (day BETWEEN 1 AND 31),
    CONSTRAINT check_dow CHECK (day_of_week BETWEEN 0 AND 6)
);

CREATE INDEX idx_dim_date_value ON dw.dim_date(date_value);
CREATE INDEX idx_dim_date_year ON dw.dim_date(year);
CREATE INDEX idx_dim_date_season ON dw.dim_date(season_name);

COMMENT ON TABLE dw.dim_date IS 'Date dimension for time-based analysis';

-- ============================================================
-- DIMENSION: Season
-- Season reference dimension
-- ============================================================
CREATE TABLE dw.dim_season (
    season_sk SERIAL PRIMARY KEY,
    season_name VARCHAR(10) NOT NULL UNIQUE, -- '24/25', '23/24'
    season_start_year INTEGER NOT NULL,
    season_end_year INTEGER NOT NULL,
    is_current_season BOOLEAN DEFAULT FALSE,
    CONSTRAINT check_season_years CHECK (season_end_year = season_start_year + 1)
);

CREATE INDEX idx_dim_season_name ON dw.dim_season(season_name);

COMMENT ON TABLE dw.dim_season IS 'Season dimension for multi-year competitions';

-- ============================================================
-- DIMENSION: Competition
-- Competition/League dimension
-- ============================================================
CREATE TABLE dw.dim_competition (
    competition_sk SERIAL PRIMARY KEY,
    competition_id VARCHAR(50) NOT NULL UNIQUE,
    competition_name VARCHAR(255) NOT NULL,
    competition_slug VARCHAR(255),
    competition_type VARCHAR(50), -- 'league', 'cup', 'international'
    country_name VARCHAR(100),
    tier_level INTEGER, -- 1 for top tier, 2 for second division, etc.
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_competition_id ON dw.dim_competition(competition_id);
CREATE INDEX idx_dim_competition_country ON dw.dim_competition(country_name);

COMMENT ON TABLE dw.dim_competition IS 'Competition and league dimension';

-- ============================================================
-- DIMENSION: Team (SCD Type 1)
-- Team/Club dimension with current attributes
-- ============================================================
CREATE TABLE dw.dim_team (
    team_sk SERIAL PRIMARY KEY,
    team_nk VARCHAR(50) NOT NULL UNIQUE, -- Natural key (can be non-numeric like 'FS')
    team_name VARCHAR(255) NOT NULL,
    team_slug VARCHAR(255),
    country_name VARCHAR(100),
    team_type VARCHAR(50), -- 'club', 'national', 'youth'
    logo_url TEXT,
    primary_competition_id VARCHAR(50), -- Main competition
    division_level VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_team_nk ON dw.dim_team(team_nk);
CREATE INDEX idx_dim_team_name ON dw.dim_team(team_name);
CREATE INDEX idx_dim_team_country ON dw.dim_team(country_name);

COMMENT ON TABLE dw.dim_team IS 'Team dimension (SCD Type 1 - current state only)';

-- ============================================================
-- DIMENSION: Agent
-- Player agent dimension
-- ============================================================
CREATE TABLE dw.dim_agent (
    agent_sk SERIAL PRIMARY KEY,
    agent_id INTEGER NOT NULL UNIQUE,
    agent_name VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_agent_id ON dw.dim_agent(agent_id);

COMMENT ON TABLE dw.dim_agent IS 'Player agent dimension';

-- ============================================================
-- DIMENSION: Player (SCD Type 2)
-- Player dimension with full history tracking
-- ============================================================
CREATE TABLE dw.dim_player (
    player_sk BIGSERIAL PRIMARY KEY,
    player_nk INTEGER NOT NULL, -- Natural key (player_id from source)
    
    -- Player attributes
    player_name VARCHAR(255) NOT NULL,
    player_slug VARCHAR(255),
    player_image_url TEXT,
    name_in_home_country VARCHAR(255),
    
    -- Birth information
    date_of_birth DATE,
    place_of_birth VARCHAR(255),
    country_of_birth VARCHAR(100),
    
    -- Physical attributes
    height_cm DECIMAL(5,2),
    
    -- Citizenship and position
    citizenship VARCHAR(100),
    is_eu BOOLEAN,
    position VARCHAR(100),
    main_position VARCHAR(100),
    foot VARCHAR(20),
    
    -- Current club information (tracked for SCD2)
    current_club_nk VARCHAR(50),
    current_club_name VARCHAR(255),
    joined_club_date DATE,
    contract_expires DATE,
    contract_option VARCHAR(100),
    contract_extension_date DATE,
    
    -- Loan information
    on_loan_from_club_nk VARCHAR(50),
    on_loan_from_club_name VARCHAR(255),
    loan_contract_expires DATE,
    
    -- Agent (foreign key)
    agent_sk INTEGER REFERENCES dw.dim_agent(agent_sk),
    
    -- Other attributes
    outfitter VARCHAR(100),
    social_media_url TEXT,
    
    -- Multiple clubs tracking
    second_club_url TEXT,
    second_club_name VARCHAR(255),
    third_club_url TEXT,
    third_club_name VARCHAR(255),
    fourth_club_url TEXT,
    fourth_club_name VARCHAR(255),
    
    -- Death date if applicable
    date_of_death DATE,
    
    -- SCD Type 2 fields
    valid_from TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    valid_to TIMESTAMP DEFAULT '9999-12-31'::TIMESTAMP,
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit fields
    source_row_hash VARCHAR(64), -- MD5/SHA hash for change detection
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_dim_player_nk ON dw.dim_player(player_nk);
CREATE INDEX idx_dim_player_current ON dw.dim_player(player_nk, is_current);
CREATE INDEX idx_dim_player_name ON dw.dim_player(player_name);
CREATE INDEX idx_dim_player_club ON dw.dim_player(current_club_nk);
CREATE INDEX idx_dim_player_country ON dw.dim_player(country_of_birth);
CREATE INDEX idx_dim_player_position ON dw.dim_player(main_position);
CREATE INDEX idx_dim_player_valid_dates ON dw.dim_player(valid_from, valid_to);

COMMENT ON TABLE dw.dim_player IS 'Player dimension with SCD Type 2 for tracking historical changes';
COMMENT ON COLUMN dw.dim_player.player_sk IS 'Surrogate key - unique identifier for each player version';
COMMENT ON COLUMN dw.dim_player.player_nk IS 'Natural key - player_id from source system';
COMMENT ON COLUMN dw.dim_player.is_current IS 'TRUE for current active record, FALSE for historical';
COMMENT ON COLUMN dw.dim_player.source_row_hash IS 'Hash of tracked attributes for change detection';

-- ============================================================
-- DIMENSION: Injury Type (optional)
-- Reference dimension for injury classifications
-- ============================================================
CREATE TABLE dw.dim_injury_type (
    injury_type_sk SERIAL PRIMARY KEY,
    injury_category VARCHAR(100) NOT NULL, -- e.g., 'Muscle', 'Ligament', 'Bone'
    injury_severity VARCHAR(50), -- 'Minor', 'Moderate', 'Severe'
    typical_recovery_days INTEGER,
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE dw.dim_injury_type IS 'Classification of injury types';

-- ============================================================
-- DIMENSION: Transfer Type
-- Reference dimension for transfer classifications
-- ============================================================
CREATE TABLE dw.dim_transfer_type (
    transfer_type_sk SERIAL PRIMARY KEY,
    transfer_type_code VARCHAR(50) NOT NULL UNIQUE,
    transfer_type_name VARCHAR(100) NOT NULL,
    is_free_transfer BOOLEAN DEFAULT FALSE,
    is_loan BOOLEAN DEFAULT FALSE,
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE dw.dim_transfer_type IS 'Classification of transfer types (loan, permanent, free, etc)';

-- ============================================================
-- Insert reference data for Transfer Types
-- ============================================================
INSERT INTO dw.dim_transfer_type (transfer_type_code, transfer_type_name, is_free_transfer, is_loan) VALUES
('PERMANENT', 'Permanent Transfer', FALSE, FALSE),
('FREE', 'Free Transfer', TRUE, FALSE),
('LOAN', 'Loan', FALSE, TRUE),
('END_LOAN', 'End of Loan', FALSE, FALSE),
('LOAN_RETURN', 'Return from Loan', FALSE, FALSE),
('UNKNOWN', 'Unknown', FALSE, FALSE);

-- ============================================================
-- Helper view for current players only
-- ============================================================
CREATE VIEW dw.v_dim_player_current AS
SELECT 
    player_sk,
    player_nk,
    player_name,
    date_of_birth,
    country_of_birth,
    position,
    main_position,
    current_club_nk,
    current_club_name,
    contract_expires,
    agent_sk
FROM dw.dim_player
WHERE is_current = TRUE;

COMMENT ON VIEW dw.v_dim_player_current IS 'View showing only current (active) player records';
