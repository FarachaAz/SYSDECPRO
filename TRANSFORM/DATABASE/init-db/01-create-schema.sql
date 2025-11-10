
CREATE TABLE player_profiles (
    player_id INTEGER PRIMARY KEY,
    player_slug VARCHAR(255),
    player_name VARCHAR(255),
    player_image_url TEXT,
    name_in_home_country VARCHAR(255),
    date_of_birth DATE,
    place_of_birth VARCHAR(255),
    country_of_birth VARCHAR(100),
    height DECIMAL(5,2),
    citizenship VARCHAR(100),
    is_eu BOOLEAN,
    position VARCHAR(100),
    main_position VARCHAR(100),
    foot VARCHAR(20),
    current_club_id INTEGER,
    current_club_name VARCHAR(255),
    joined DATE,
    contract_expires DATE,
    outfitter VARCHAR(100),
    social_media_url TEXT,
    player_agent_id INTEGER,
    player_agent_name VARCHAR(255),
    contract_option VARCHAR(100),
    date_of_last_contract_extension DATE,
    on_loan_from_club_id INTEGER,
    on_loan_from_club_name VARCHAR(255),
    contract_there_expires DATE,
    second_club_url TEXT,
    second_club_name VARCHAR(255),
    third_club_url TEXT,
    third_club_name VARCHAR(255),
    fourth_club_url TEXT,
    fourth_club_name VARCHAR(255),
    date_of_death DATE
);

-- Player Injuries
CREATE TABLE player_injuries (
    injury_id SERIAL PRIMARY KEY,
    player_id INTEGER NOT NULL,
    season_name VARCHAR(20),
    injury_reason TEXT,
    from_date DATE,
    end_date DATE,
    days_missed DECIMAL(10,2),
    games_missed INTEGER,
    FOREIGN KEY (player_id) REFERENCES player_profiles(player_id) ON DELETE CASCADE
);

-- Player Market Value History
CREATE TABLE player_market_value (
    market_value_id SERIAL PRIMARY KEY,
    player_id INTEGER NOT NULL,
    date_unix BIGINT,
    value DECIMAL(15,2),
    FOREIGN KEY (player_id) REFERENCES player_profiles(player_id) ON DELETE CASCADE
);

-- Player Latest Market Value
CREATE TABLE player_latest_market_value (
    player_id INTEGER PRIMARY KEY,
    date_unix BIGINT,
    value DECIMAL(15,2),
    FOREIGN KEY (player_id) REFERENCES player_profiles(player_id) ON DELETE CASCADE
);

-- Player National Team Performances
CREATE TABLE player_national_performances (
    national_performance_id SERIAL PRIMARY KEY,
    player_id INTEGER NOT NULL,
    team_id INTEGER,
    team_name VARCHAR(255),
    first_game_date DATE,
    matches INTEGER,
    goals INTEGER,
    FOREIGN KEY (player_id) REFERENCES player_profiles(player_id) ON DELETE CASCADE
);

-- Player Performances (Club level)
-- Note: This table will be created to handle large dataset
CREATE TABLE player_performances (
    performance_id SERIAL PRIMARY KEY,
    player_id INTEGER NOT NULL,
    season_name VARCHAR(20),
    competition_id VARCHAR(50),
    competition_name VARCHAR(255),
    team_id INTEGER,
    team_name VARCHAR(255),
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
    FOREIGN KEY (player_id) REFERENCES player_profiles(player_id) ON DELETE CASCADE
);

-- Player Teammates
CREATE TABLE player_teammates_played_with (
    teammate_record_id SERIAL PRIMARY KEY,
    player_id INTEGER NOT NULL,
    teammate_player_id INTEGER NOT NULL,
    teammate_player_name VARCHAR(255),
    ppg_played_with DECIMAL(10,2),
    joint_goal_participation INTEGER,
    minutes_played_with INTEGER,
    FOREIGN KEY (player_id) REFERENCES player_profiles(player_id) ON DELETE CASCADE
);

-- ===========================================
-- TEAM TABLES
-- ===========================================

-- Team Details
CREATE TABLE team_details (
    club_id INTEGER NOT NULL,
    club_slug VARCHAR(255),
    club_name VARCHAR(255),
    logo_url TEXT,
    country_name VARCHAR(100),
    season_id INTEGER NOT NULL,
    competition_id VARCHAR(50),
    competition_slug VARCHAR(255),
    competition_name VARCHAR(255),
    club_division VARCHAR(255),
    source_url TEXT,
    _last_modified_at TIMESTAMP,
    PRIMARY KEY (club_id, season_id)
);

-- Team Children (Parent-Child Club Relationships)
CREATE TABLE team_children (
    team_child_id SERIAL PRIMARY KEY,
    parent_team_id INTEGER NOT NULL,
    parent_team_name VARCHAR(255),
    child_team_id INTEGER NOT NULL,
    child_team_name VARCHAR(255),
    _last_modified_at TIMESTAMP
);

-- Team Competitions Seasons
CREATE TABLE team_competitions_seasons (
    team_competition_id SERIAL PRIMARY KEY,
    club_id INTEGER NOT NULL,
    team_name VARCHAR(255),
    season_id INTEGER,
    competition_name VARCHAR(255),
    competition_id VARCHAR(50),
    club_division VARCHAR(255),
    _last_modified_at TIMESTAMP
);

-- ===========================================
-- TRANSFER TABLES
-- ===========================================

-- Transfer History
CREATE TABLE transfer_history (
    transfer_id SERIAL PRIMARY KEY,
    player_id INTEGER NOT NULL,
    season_name VARCHAR(20),
    transfer_date DATE,
    from_team_id INTEGER,
    from_team_name VARCHAR(255),
    to_team_id INTEGER,
    to_team_name VARCHAR(255),
    transfer_type VARCHAR(100),
    value_at_transfer DECIMAL(15,2),
    transfer_fee DECIMAL(15,2),
    FOREIGN KEY (player_id) REFERENCES player_profiles(player_id) ON DELETE CASCADE
);

-- ===========================================
-- INDEXES FOR PERFORMANCE
-- ===========================================

-- Player Profiles indexes
CREATE INDEX idx_player_profiles_name ON player_profiles(player_name);
CREATE INDEX idx_player_profiles_club ON player_profiles(current_club_id);
CREATE INDEX idx_player_profiles_country ON player_profiles(country_of_birth);

-- Player Injuries indexes
CREATE INDEX idx_player_injuries_player ON player_injuries(player_id);
CREATE INDEX idx_player_injuries_season ON player_injuries(season_name);
CREATE INDEX idx_player_injuries_dates ON player_injuries(from_date, end_date);

-- Player Market Value indexes
CREATE INDEX idx_player_market_value_player ON player_market_value(player_id);
CREATE INDEX idx_player_market_value_date ON player_market_value(date_unix);

-- Player Performances indexes
CREATE INDEX idx_player_performances_player ON player_performances(player_id);
CREATE INDEX idx_player_performances_season ON player_performances(season_name);
CREATE INDEX idx_player_performances_team ON player_performances(team_id);
CREATE INDEX idx_player_performances_competition ON player_performances(competition_id);

-- Player National Performances indexes
CREATE INDEX idx_player_national_perf_player ON player_national_performances(player_id);
CREATE INDEX idx_player_national_perf_team ON player_national_performances(team_id);

-- Player Teammates indexes
CREATE INDEX idx_player_teammates_player ON player_teammates_played_with(player_id);
CREATE INDEX idx_player_teammates_teammate ON player_teammates_played_with(teammate_player_id);

-- Transfer History indexes
CREATE INDEX idx_transfer_history_player ON transfer_history(player_id);
CREATE INDEX idx_transfer_history_season ON transfer_history(season_name);
CREATE INDEX idx_transfer_history_from_team ON transfer_history(from_team_id);
CREATE INDEX idx_transfer_history_to_team ON transfer_history(to_team_id);
CREATE INDEX idx_transfer_history_date ON transfer_history(transfer_date);

-- Team Details indexes
CREATE INDEX idx_team_details_club ON team_details(club_id);
CREATE INDEX idx_team_details_season ON team_details(season_id);
CREATE INDEX idx_team_details_competition ON team_details(competition_id);
CREATE INDEX idx_team_details_country ON team_details(country_name);

-- Team Children indexes
CREATE INDEX idx_team_children_parent ON team_children(parent_team_id);
CREATE INDEX idx_team_children_child ON team_children(child_team_id);

-- Team Competitions Seasons indexes
CREATE INDEX idx_team_competitions_club ON team_competitions_seasons(club_id);
CREATE INDEX idx_team_competitions_season ON team_competitions_seasons(season_id);
CREATE INDEX idx_team_competitions_competition ON team_competitions_seasons(competition_id);

-- ===========================================
-- COMMENTS
-- ===========================================

COMMENT ON TABLE player_profiles IS 'Master table containing player biographical and contract information';
COMMENT ON TABLE player_injuries IS 'Historical record of player injuries and recovery periods';
COMMENT ON TABLE player_market_value IS 'Historical market value tracking for players';
COMMENT ON TABLE player_latest_market_value IS 'Current market value snapshot for each player';
COMMENT ON TABLE player_national_performances IS 'Player statistics for national team appearances';
COMMENT ON TABLE player_performances IS 'Detailed player performance statistics by season and competition';
COMMENT ON TABLE player_teammates_played_with IS 'Records of which players have played together';
COMMENT ON TABLE team_details IS 'Team information by season and competition';
COMMENT ON TABLE team_children IS 'Hierarchical relationships between parent clubs and youth/reserve teams';
COMMENT ON TABLE team_competitions_seasons IS 'Teams participation in competitions by season';
COMMENT ON TABLE transfer_history IS 'Complete transfer history including fees and dates';
