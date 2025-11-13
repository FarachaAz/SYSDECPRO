-- ============================================================
-- FOOTBALL DATA WAREHOUSE - HELPER FUNCTIONS & PROCEDURES
-- Utility functions for ETL and data management
-- ============================================================

-- ============================================================
-- Function: Get or Create Date SK
-- Returns the date_sk for a given date, creating the record if needed
-- ============================================================
CREATE OR REPLACE FUNCTION dw.get_date_sk(p_date DATE)
RETURNS INTEGER AS $$
DECLARE
    v_date_sk INTEGER;
BEGIN
    -- Try to find existing date
    SELECT date_sk INTO v_date_sk
    FROM dw.dim_date
    WHERE date_value = p_date;
    
    -- If not found, insert it
    IF NOT FOUND THEN
        INSERT INTO dw.dim_date (
            date_value, year, quarter, month, month_name, day,
            day_of_week, day_name, week_of_year, is_weekend, season_name
        )
        VALUES (
            p_date,
            EXTRACT(YEAR FROM p_date),
            EXTRACT(QUARTER FROM p_date),
            EXTRACT(MONTH FROM p_date),
            TO_CHAR(p_date, 'Month'),
            EXTRACT(DAY FROM p_date),
            EXTRACT(DOW FROM p_date),
            TO_CHAR(p_date, 'Day'),
            EXTRACT(WEEK FROM p_date),
            EXTRACT(DOW FROM p_date) IN (0, 6),
            -- Calculate season_name (assumes July 1 as season start)
            CASE 
                WHEN EXTRACT(MONTH FROM p_date) >= 7 THEN
                    CONCAT(
                        SUBSTRING(CAST(EXTRACT(YEAR FROM p_date) AS TEXT), 3, 2),
                        '/',
                        SUBSTRING(CAST(EXTRACT(YEAR FROM p_date) + 1 AS TEXT), 3, 2)
                    )
                ELSE
                    CONCAT(
                        SUBSTRING(CAST(EXTRACT(YEAR FROM p_date) - 1 AS TEXT), 3, 2),
                        '/',
                        SUBSTRING(CAST(EXTRACT(YEAR FROM p_date) AS TEXT), 3, 2)
                    )
            END
        )
        RETURNING date_sk INTO v_date_sk;
    END IF;
    
    RETURN v_date_sk;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Function: Get Current Player SK
-- Returns the current (active) player_sk for a given player_nk
-- ============================================================
CREATE OR REPLACE FUNCTION dw.get_current_player_sk(p_player_nk INTEGER)
RETURNS BIGINT AS $$
DECLARE
    v_player_sk BIGINT;
BEGIN
    SELECT player_sk INTO v_player_sk
    FROM dw.dim_player
    WHERE player_nk = p_player_nk
      AND is_current = TRUE;
    
    RETURN v_player_sk;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Function: Get or Create Team SK
-- Returns the team_sk for a given team_nk, creating if needed
-- ============================================================
CREATE OR REPLACE FUNCTION dw.get_or_create_team_sk(
    p_team_nk VARCHAR(50),
    p_team_name VARCHAR(255) DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_team_sk INTEGER;
BEGIN
    -- Try to find existing team
    SELECT team_sk INTO v_team_sk
    FROM dw.dim_team
    WHERE team_nk = p_team_nk;
    
    -- If not found, insert it with minimal info
    IF NOT FOUND THEN
        INSERT INTO dw.dim_team (team_nk, team_name)
        VALUES (p_team_nk, COALESCE(p_team_name, 'Unknown'))
        RETURNING team_sk INTO v_team_sk;
    END IF;
    
    RETURN v_team_sk;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Function: Get or Create Competition SK
-- ============================================================
CREATE OR REPLACE FUNCTION dw.get_or_create_competition_sk(
    p_competition_id VARCHAR(50),
    p_competition_name VARCHAR(255) DEFAULT NULL
)
RETURNS INTEGER AS $$
DECLARE
    v_competition_sk INTEGER;
BEGIN
    SELECT competition_sk INTO v_competition_sk
    FROM dw.dim_competition
    WHERE competition_id = p_competition_id;
    
    IF NOT FOUND THEN
        INSERT INTO dw.dim_competition (competition_id, competition_name)
        VALUES (p_competition_id, COALESCE(p_competition_name, 'Unknown'))
        RETURNING competition_sk INTO v_competition_sk;
    END IF;
    
    RETURN v_competition_sk;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Function: Get or Create Season SK
-- ============================================================
CREATE OR REPLACE FUNCTION dw.get_or_create_season_sk(p_season_name VARCHAR(10))
RETURNS INTEGER AS $$
DECLARE
    v_season_sk INTEGER;
    v_start_year INTEGER;
    v_end_year INTEGER;
BEGIN
    SELECT season_sk INTO v_season_sk
    FROM dw.dim_season
    WHERE season_name = p_season_name;
    
    IF NOT FOUND THEN
        -- Parse season name like '24/25' -> 2024, 2025
        v_start_year := 2000 + SUBSTRING(p_season_name, 1, 2)::INTEGER;
        v_end_year := 2000 + SUBSTRING(p_season_name, 4, 2)::INTEGER;
        
        INSERT INTO dw.dim_season (season_name, season_start_year, season_end_year)
        VALUES (p_season_name, v_start_year, v_end_year)
        RETURNING season_sk INTO v_season_sk;
    END IF;
    
    RETURN v_season_sk;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Function: Calculate MD5 Hash for Player Attributes
-- Used for SCD2 change detection
-- ============================================================
CREATE OR REPLACE FUNCTION dw.calculate_player_hash(
    p_player_name VARCHAR(255),
    p_position VARCHAR(100),
    p_current_club_nk VARCHAR(50),
    p_contract_expires DATE,
    p_agent_sk INTEGER
)
RETURNS VARCHAR(64) AS $$
BEGIN
    RETURN MD5(
        COALESCE(p_player_name, '') ||
        COALESCE(p_position, '') ||
        COALESCE(p_current_club_nk, '') ||
        COALESCE(p_contract_expires::TEXT, '') ||
        COALESCE(p_agent_sk::TEXT, '')
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================
-- Procedure: Populate Date Dimension
-- Populates dim_date with dates from start to end
-- ============================================================
CREATE OR REPLACE PROCEDURE dw.populate_date_dimension(
    p_start_date DATE,
    p_end_date DATE
)
LANGUAGE plpgsql AS $$
DECLARE
    v_date DATE;
BEGIN
    v_date := p_start_date;
    
    WHILE v_date <= p_end_date LOOP
        INSERT INTO dw.dim_date (
            date_value, year, quarter, month, month_name, day,
            day_of_week, day_name, week_of_year, is_weekend, season_name
        )
        VALUES (
            v_date,
            EXTRACT(YEAR FROM v_date),
            EXTRACT(QUARTER FROM v_date),
            EXTRACT(MONTH FROM v_date),
            TO_CHAR(v_date, 'Month'),
            EXTRACT(DAY FROM v_date),
            EXTRACT(DOW FROM v_date),
            TO_CHAR(v_date, 'Day'),
            EXTRACT(WEEK FROM v_date),
            EXTRACT(DOW FROM v_date) IN (0, 6),
            -- Calculate season_name (July 1 as season boundary)
            CASE 
                WHEN EXTRACT(MONTH FROM v_date) >= 7 THEN
                    CONCAT(
                        SUBSTRING(CAST(EXTRACT(YEAR FROM v_date) AS TEXT), 3, 2),
                        '/',
                        SUBSTRING(CAST(EXTRACT(YEAR FROM v_date) + 1 AS TEXT), 3, 2)
                    )
                ELSE
                    CONCAT(
                        SUBSTRING(CAST(EXTRACT(YEAR FROM v_date) - 1 AS TEXT), 3, 2),
                        '/',
                        SUBSTRING(CAST(EXTRACT(YEAR FROM v_date) AS TEXT), 3, 2)
                    )
            END
        )
        ON CONFLICT (date_value) DO NOTHING;
        
        v_date := v_date + INTERVAL '1 day';
    END LOOP;
    
    RAISE NOTICE 'Date dimension populated from % to %', p_start_date, p_end_date;
END;
$$;

-- ============================================================
-- View: Data Quality Checks
-- ============================================================
CREATE OR REPLACE VIEW dw.v_data_quality_checks AS
SELECT 
    'Fact Player Performance' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE player_sk IS NULL) AS null_player_sk,
    COUNT(*) FILTER (WHERE team_sk IS NULL) AS null_team_sk,
    COUNT(*) FILTER (WHERE goals < 0) AS negative_goals,
    COUNT(*) FILTER (WHERE minutes_played < 0) AS negative_minutes
FROM dw.fact_player_performance
UNION ALL
SELECT 
    'Fact Market Value' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE player_sk IS NULL) AS null_player_sk,
    COUNT(*) FILTER (WHERE date_sk IS NULL) AS null_date_sk,
    COUNT(*) FILTER (WHERE market_value < 0) AS negative_value,
    0 AS additional_check
FROM dw.fact_market_value
UNION ALL
SELECT 
    'Fact Transfer' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE player_sk IS NULL) AS null_player_sk,
    COUNT(*) FILTER (WHERE from_team_sk IS NULL AND to_team_sk IS NULL) AS both_teams_null,
    COUNT(*) FILTER (WHERE transfer_fee < 0) AS negative_fee,
    0 AS additional_check
FROM dw.fact_transfer;

COMMENT ON VIEW dw.v_data_quality_checks IS 'Basic data quality checks across fact tables';

-- ============================================================
-- Grant permissions (adjust as needed for your users)
-- ============================================================
-- Example: GRANT SELECT ON ALL TABLES IN SCHEMA dw TO reporting_user;
-- Example: GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA dw TO etl_user;
