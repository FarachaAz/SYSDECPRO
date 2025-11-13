-- ============================================================
-- FOOTBALL DATA WAREHOUSE - FACT TABLES
-- Star Schema Design
-- ============================================================

-- ============================================================
-- FACT: Player Performance
-- Grain: One record per player performance entry (season/competition/team combination)
-- ============================================================
CREATE TABLE dw.fact_player_performance (
    performance_sk BIGSERIAL PRIMARY KEY,
    
    -- Dimension foreign keys
    player_sk BIGINT NOT NULL REFERENCES dw.dim_player(player_sk),
    team_sk INTEGER REFERENCES dw.dim_team(team_sk),
    competition_sk INTEGER REFERENCES dw.dim_competition(competition_sk),
    season_sk INTEGER REFERENCES dw.dim_season(season_sk),
    
    -- Degenerate dimensions (if no date available)
    season_name VARCHAR(10),
    competition_name VARCHAR(255),
    
    -- Performance metrics
    nb_in_group INTEGER,
    nb_on_pitch INTEGER,
    goals DECIMAL(10,2),
    assists INTEGER,
    own_goals INTEGER,
    subed_in INTEGER,
    subed_out INTEGER,
    yellow_cards INTEGER,
    second_yellow_cards INTEGER,
    direct_red_cards INTEGER,
    penalty_goals INTEGER,
    minutes_played INTEGER,
    goals_conceded INTEGER,
    clean_sheets INTEGER,
    
    -- Calculated metrics
    goals_per_match DECIMAL(10,4),
    assists_per_match DECIMAL(10,4),
    minutes_per_goal DECIMAL(10,2),
    cards_total INTEGER, -- yellow + second_yellow + direct_red
    
    -- Source tracking
    source_system VARCHAR(50) DEFAULT 'club',
    source_record_id VARCHAR(100),
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Partitioning hint: partition by season_name or year
    CONSTRAINT check_goals_positive CHECK (goals >= 0),
    CONSTRAINT check_assists_positive CHECK (assists >= 0)
);

-- Indexes for common queries
CREATE INDEX idx_fact_performance_player ON dw.fact_player_performance(player_sk);
CREATE INDEX idx_fact_performance_team ON dw.fact_player_performance(team_sk);
CREATE INDEX idx_fact_performance_competition ON dw.fact_player_performance(competition_sk);
CREATE INDEX idx_fact_performance_season ON dw.fact_player_performance(season_sk);
CREATE INDEX idx_fact_performance_season_name ON dw.fact_player_performance(season_name);
CREATE INDEX idx_fact_performance_composite ON dw.fact_player_performance(player_sk, season_sk, team_sk);

COMMENT ON TABLE dw.fact_player_performance IS 'Player performance metrics by competition and season';

-- ============================================================
-- FACT: Market Value
-- Grain: One record per player per date (market value snapshot)
-- ============================================================
CREATE TABLE dw.fact_market_value (
    market_value_sk BIGSERIAL PRIMARY KEY,
    
    -- Dimension foreign keys
    player_sk BIGINT NOT NULL REFERENCES dw.dim_player(player_sk),
    date_sk INTEGER NOT NULL REFERENCES dw.dim_date(date_sk),
    
    -- Measures
    market_value DECIMAL(15,2) NOT NULL,
    
    -- Classification
    is_latest_value BOOLEAN DEFAULT FALSE, -- TRUE if from player_latest_market_value table
    value_source VARCHAR(50), -- 'historical' or 'latest'
    
    -- Value change tracking (can be calculated)
    previous_value DECIMAL(15,2),
    value_change DECIMAL(15,2),
    value_change_pct DECIMAL(10,4),
    
    -- Source tracking
    source_record_id VARCHAR(100),
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_market_value_positive CHECK (market_value >= 0),
    UNIQUE(player_sk, date_sk, value_source)
);

-- Indexes
CREATE INDEX idx_fact_market_value_player ON dw.fact_market_value(player_sk);
CREATE INDEX idx_fact_market_value_date ON dw.fact_market_value(date_sk);
CREATE INDEX idx_fact_market_value_latest ON dw.fact_market_value(player_sk, is_latest_value);
CREATE INDEX idx_fact_market_value_composite ON dw.fact_market_value(player_sk, date_sk);

COMMENT ON TABLE dw.fact_market_value IS 'Historical and current player market values';

-- ============================================================
-- FACT: Transfer
-- Grain: One record per transfer event
-- ============================================================
CREATE TABLE dw.fact_transfer (
    transfer_sk BIGSERIAL PRIMARY KEY,
    
    -- Dimension foreign keys
    player_sk BIGINT NOT NULL REFERENCES dw.dim_player(player_sk),
    from_team_sk INTEGER REFERENCES dw.dim_team(team_sk), -- NULL if from unknown/youth
    to_team_sk INTEGER REFERENCES dw.dim_team(team_sk), -- NULL if retired/unknown
    transfer_date_sk INTEGER REFERENCES dw.dim_date(date_sk),
    season_sk INTEGER REFERENCES dw.dim_season(season_sk),
    transfer_type_sk INTEGER REFERENCES dw.dim_transfer_type(transfer_type_sk),
    
    -- Degenerate dimensions
    season_name VARCHAR(10),
    
    -- Measures
    transfer_fee DECIMAL(15,2), -- Actual transfer fee paid
    value_at_transfer DECIMAL(15,2), -- Player's market value at time of transfer
    
    -- Calculated metrics
    fee_to_value_ratio DECIMAL(10,4), -- transfer_fee / value_at_transfer
    
    -- Transfer type (if not using dimension)
    transfer_type_text VARCHAR(100),
    
    -- Source tracking
    source_record_id VARCHAR(100),
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_transfer_fee_positive CHECK (transfer_fee >= 0 OR transfer_fee IS NULL),
    CONSTRAINT check_value_positive CHECK (value_at_transfer >= 0 OR value_at_transfer IS NULL)
);

-- Indexes
CREATE INDEX idx_fact_transfer_player ON dw.fact_transfer(player_sk);
CREATE INDEX idx_fact_transfer_from_team ON dw.fact_transfer(from_team_sk);
CREATE INDEX idx_fact_transfer_to_team ON dw.fact_transfer(to_team_sk);
CREATE INDEX idx_fact_transfer_date ON dw.fact_transfer(transfer_date_sk);
CREATE INDEX idx_fact_transfer_season ON dw.fact_transfer(season_sk);
CREATE INDEX idx_fact_transfer_type ON dw.fact_transfer(transfer_type_sk);
CREATE INDEX idx_fact_transfer_composite ON dw.fact_transfer(player_sk, transfer_date_sk);

COMMENT ON TABLE dw.fact_transfer IS 'Player transfer events and associated fees';

-- ============================================================
-- FACT: Injury
-- Grain: One record per injury event
-- ============================================================
CREATE TABLE dw.fact_injury (
    injury_sk BIGSERIAL PRIMARY KEY,
    
    -- Dimension foreign keys
    player_sk BIGINT NOT NULL REFERENCES dw.dim_player(player_sk),
    injury_from_date_sk INTEGER REFERENCES dw.dim_date(date_sk),
    injury_end_date_sk INTEGER REFERENCES dw.dim_date(date_sk),
    season_sk INTEGER REFERENCES dw.dim_season(season_sk),
    injury_type_sk INTEGER REFERENCES dw.dim_injury_type(injury_type_sk),
    
    -- Degenerate dimensions
    season_name VARCHAR(10),
    injury_reason TEXT, -- Keep as text for analysis
    
    -- Measures
    days_missed DECIMAL(10,2),
    games_missed INTEGER,
    
    -- Calculated metrics
    avg_days_per_game DECIMAL(10,2), -- days_missed / games_missed
    severity_score INTEGER, -- Derived from days_missed (1-5 scale)
    
    -- Source tracking
    source_record_id VARCHAR(100),
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_days_positive CHECK (days_missed >= 0 OR days_missed IS NULL),
    CONSTRAINT check_games_positive CHECK (games_missed >= 0 OR games_missed IS NULL)
);

-- Indexes
CREATE INDEX idx_fact_injury_player ON dw.fact_injury(player_sk);
CREATE INDEX idx_fact_injury_from_date ON dw.fact_injury(injury_from_date_sk);
CREATE INDEX idx_fact_injury_end_date ON dw.fact_injury(injury_end_date_sk);
CREATE INDEX idx_fact_injury_season ON dw.fact_injury(season_sk);
CREATE INDEX idx_fact_injury_type ON dw.fact_injury(injury_type_sk);

COMMENT ON TABLE dw.fact_injury IS 'Player injury events and recovery periods';

-- ============================================================
-- FACT: National Team Performance
-- Grain: One record per player per national team
-- ============================================================
CREATE TABLE dw.fact_national_performance (
    national_performance_sk BIGSERIAL PRIMARY KEY,
    
    -- Dimension foreign keys
    player_sk BIGINT NOT NULL REFERENCES dw.dim_player(player_sk),
    national_team_sk INTEGER REFERENCES dw.dim_team(team_sk), -- Links to national teams in dim_team
    first_game_date_sk INTEGER REFERENCES dw.dim_date(date_sk),
    
    -- Measures
    total_matches INTEGER,
    total_goals INTEGER,
    
    -- Calculated metrics
    goals_per_match DECIMAL(10,4),
    
    -- Source tracking
    source_record_id VARCHAR(100),
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_matches_positive CHECK (total_matches >= 0),
    CONSTRAINT check_goals_positive CHECK (total_goals >= 0),
    UNIQUE(player_sk, national_team_sk)
);

-- Indexes
CREATE INDEX idx_fact_national_perf_player ON dw.fact_national_performance(player_sk);
CREATE INDEX idx_fact_national_perf_team ON dw.fact_national_performance(national_team_sk);
CREATE INDEX idx_fact_national_perf_date ON dw.fact_national_performance(first_game_date_sk);

COMMENT ON TABLE dw.fact_national_performance IS 'Player performance for national teams';

-- ============================================================
-- FACT: Teammate Relationship
-- Grain: One record per player-teammate pair
-- ============================================================
CREATE TABLE dw.fact_teammate_relationship (
    teammate_fact_sk BIGSERIAL PRIMARY KEY,
    
    -- Dimension foreign keys
    player_sk BIGINT NOT NULL REFERENCES dw.dim_player(player_sk),
    teammate_player_sk BIGINT NOT NULL REFERENCES dw.dim_player(player_sk),
    
    -- Measures
    minutes_played_together INTEGER,
    ppg_played_with DECIMAL(10,2), -- Points per game when playing together
    joint_goal_participation INTEGER, -- Goals where both were involved
    
    -- Calculated metrics
    chemistry_score DECIMAL(10,4), -- Derived metric for partnership effectiveness
    
    -- Source tracking
    source_record_id VARCHAR(100),
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_minutes_positive CHECK (minutes_played_together >= 0),
    CONSTRAINT check_different_players CHECK (player_sk != teammate_player_sk),
    UNIQUE(player_sk, teammate_player_sk)
);

-- Indexes
CREATE INDEX idx_fact_teammate_player ON dw.fact_teammate_relationship(player_sk);
CREATE INDEX idx_fact_teammate_teammate ON dw.fact_teammate_relationship(teammate_player_sk);
CREATE INDEX idx_fact_teammate_composite ON dw.fact_teammate_relationship(player_sk, teammate_player_sk);

COMMENT ON TABLE dw.fact_teammate_relationship IS 'Player-teammate relationship metrics';

-- ============================================================
-- Aggregate/Summary Tables (optional - for performance)
-- ============================================================

-- Player Season Summary
CREATE TABLE dw.fact_player_season_summary (
    player_season_sk BIGSERIAL PRIMARY KEY,
    player_sk BIGINT NOT NULL REFERENCES dw.dim_player(player_sk),
    season_sk INTEGER NOT NULL REFERENCES dw.dim_season(season_sk),
    
    -- Aggregated measures
    total_matches INTEGER,
    total_goals DECIMAL(10,2),
    total_assists INTEGER,
    total_minutes INTEGER,
    total_yellow_cards INTEGER,
    total_red_cards INTEGER,
    
    -- Averages
    avg_goals_per_match DECIMAL(10,4),
    avg_assists_per_match DECIMAL(10,4),
    
    -- Market value at season start/end
    season_start_value DECIMAL(15,2),
    season_end_value DECIMAL(15,2),
    value_change_pct DECIMAL(10,4),
    
    -- Injury summary
    total_injury_days INTEGER,
    total_games_missed INTEGER,
    
    load_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(player_sk, season_sk)
);

CREATE INDEX idx_fact_player_season_player ON dw.fact_player_season_summary(player_sk);
CREATE INDEX idx_fact_player_season_season ON dw.fact_player_season_summary(season_sk);

COMMENT ON TABLE dw.fact_player_season_summary IS 'Pre-aggregated player statistics by season for fast reporting';
