# Football Data Warehouse

## Overview
This directory contains the **Star Schema** design for the Football Data Warehouse. The warehouse is designed to support analytical queries for:
- Player performance analysis
- Market value trends
- Transfer activity tracking
- Injury impact analysis
- Team and competition comparisons

## Architecture

### Star Schema Design
The warehouse follows a **dimensional modeling** approach with:
- **8 Dimensions**: Player (SCD2), Team, Competition, Date, Season, Agent, Injury Type, Transfer Type
- **6 Fact Tables**: Player Performance, Market Value, Transfers, Injuries, National Performance, Teammate Relationships
- **1 Aggregate Table**: Player Season Summary (for fast reporting)

### Database: PostgreSQL
- Schema: `dw` (data warehouse)
- Same PostgreSQL container as the source database
- Separate schema for clear separation of concerns

### Star Schema Diagram

```mermaid
erDiagram
    %% Dimensions
    DIM_PLAYER ||--o{ FACT_PLAYER_PERFORMANCE : "player_sk"
    DIM_PLAYER ||--o{ FACT_MARKET_VALUE : "player_sk"
    DIM_PLAYER ||--o{ FACT_TRANSFER : "player_sk"
    DIM_PLAYER ||--o{ FACT_INJURY : "player_sk"
    DIM_PLAYER ||--o{ FACT_NATIONAL_PERFORMANCE : "player_sk"
    DIM_PLAYER ||--o{ FACT_TEAMMATE_RELATIONSHIP : "player_sk"
    DIM_PLAYER ||--o{ FACT_PLAYER_SEASON_SUMMARY : "player_sk"
    
    DIM_TEAM ||--o{ FACT_PLAYER_PERFORMANCE : "team_sk"
    DIM_TEAM ||--o{ FACT_TRANSFER : "from_team_sk"
    DIM_TEAM ||--o{ FACT_TRANSFER : "to_team_sk"
    DIM_TEAM ||--o{ FACT_NATIONAL_PERFORMANCE : "national_team_sk"
    
    DIM_COMPETITION ||--o{ FACT_PLAYER_PERFORMANCE : "competition_sk"
    
    DIM_DATE ||--o{ FACT_MARKET_VALUE : "date_sk"
    DIM_DATE ||--o{ FACT_TRANSFER : "transfer_date_sk"
    DIM_DATE ||--o{ FACT_INJURY : "injury_from_date_sk"
    DIM_DATE ||--o{ FACT_INJURY : "injury_end_date_sk"
    DIM_DATE ||--o{ FACT_NATIONAL_PERFORMANCE : "first_game_date_sk"
    
    DIM_SEASON ||--o{ FACT_PLAYER_PERFORMANCE : "season_sk"
    DIM_SEASON ||--o{ FACT_TRANSFER : "season_sk"
    DIM_SEASON ||--o{ FACT_INJURY : "season_sk"
    DIM_SEASON ||--o{ FACT_PLAYER_SEASON_SUMMARY : "season_sk"
    
    DIM_AGENT ||--o{ DIM_PLAYER : "agent_sk"
    
    DIM_INJURY_TYPE ||--o{ FACT_INJURY : "injury_type_sk"
    
    DIM_TRANSFER_TYPE ||--o{ FACT_TRANSFER : "transfer_type_sk"
    
    %% Dimension Tables
    DIM_PLAYER {
        bigserial player_sk PK
        integer player_nk NK
        varchar player_name
        varchar position
        date date_of_birth
        varchar current_club_nk
        integer agent_sk FK
        date valid_from
        date valid_to
        boolean is_current
        varchar source_row_hash
    }
    
    DIM_TEAM {
        serial team_sk PK
        varchar team_nk NK
        varchar team_name
        varchar country
        varchar competition_name
        integer tier_level
    }
    
    DIM_COMPETITION {
        serial competition_sk PK
        varchar competition_id NK
        varchar competition_name
        varchar competition_type
        varchar country
        integer tier_level
    }
    
    DIM_DATE {
        serial date_sk PK
        date date_value UK
        integer year
        integer quarter
        integer month
        varchar month_name
        integer day
        varchar season_name
    }
    
    DIM_SEASON {
        serial season_sk PK
        varchar season_name UK
        integer season_start_year
        integer season_end_year
        boolean is_current
    }
    
    DIM_AGENT {
        serial agent_sk PK
        varchar agent_id NK
        varchar agent_name
        varchar country
    }
    
    DIM_INJURY_TYPE {
        serial injury_type_sk PK
        varchar injury_type_name UK
        varchar injury_category
        varchar severity_level
    }
    
    DIM_TRANSFER_TYPE {
        serial transfer_type_sk PK
        varchar transfer_type_name UK
        varchar transfer_type_desc
    }
    
    %% Fact Tables
    FACT_PLAYER_PERFORMANCE {
        bigserial performance_sk PK
        bigint player_sk FK
        integer team_sk FK
        integer competition_sk FK
        integer season_sk FK
        integer goals
        integer assists
        integer minutes_played
        integer yellow_cards
        integer red_cards
        decimal goals_per_match
    }
    
    FACT_MARKET_VALUE {
        bigserial market_value_sk PK
        bigint player_sk FK
        integer date_sk FK
        bigint market_value
        bigint previous_value
        bigint value_change
        decimal value_change_pct
    }
    
    FACT_TRANSFER {
        bigserial transfer_sk PK
        bigint player_sk FK
        integer from_team_sk FK
        integer to_team_sk FK
        integer transfer_date_sk FK
        integer season_sk FK
        integer transfer_type_sk FK
        bigint transfer_fee
        bigint value_at_transfer
        decimal fee_to_value_ratio
    }
    
    FACT_INJURY {
        bigserial injury_sk PK
        bigint player_sk FK
        integer injury_from_date_sk FK
        integer injury_end_date_sk FK
        integer season_sk FK
        integer injury_type_sk FK
        integer days_missed
        integer games_missed
        integer severity_score
    }
    
    FACT_NATIONAL_PERFORMANCE {
        bigserial national_perf_sk PK
        bigint player_sk FK
        integer national_team_sk FK
        integer first_game_date_sk FK
        integer total_matches
        integer total_goals
        decimal goals_per_match
    }
    
    FACT_TEAMMATE_RELATIONSHIP {
        bigserial teammate_sk PK
        bigint player_sk FK
        bigint teammate_player_sk FK
        integer minutes_played_together
        decimal ppg_played_with
        integer joint_goal_participation
    }
    
    FACT_PLAYER_SEASON_SUMMARY {
        bigserial summary_sk PK
        bigint player_sk FK
        integer season_sk FK
        integer total_goals
        integer total_assists
        integer total_minutes
        decimal avg_goals_per_match
        bigint market_value_start
        bigint market_value_end
        integer injuries_count
    }
```

**Legend:**
- **PK**: Primary Key (Surrogate Key)
- **FK**: Foreign Key
- **NK**: Natural Key (from source system)
- **UK**: Unique Key

---

## Schema Documentation

### Dimensions

#### `dw.dim_player` (SCD Type 2)
Tracks player attributes with full history.
- **Grain**: One record per player version
- **SCD Type**: Type 2 (historical tracking)
- **Key Fields**: `player_sk` (surrogate), `player_nk` (natural), `is_current`, `valid_from`, `valid_to`
- **Tracked Attributes**: position, club, contract dates, agent
- **Total Attributes**: 35+ columns

#### `dw.dim_team` (SCD Type 1)
Current state of teams/clubs.
- **Grain**: One record per team
- **SCD Type**: Type 1 (overwrite)
- **Key Fields**: `team_sk`, `team_nk` (can be non-numeric like 'FS')
- **Attributes**: team name, country, competition, division

#### `dw.dim_competition`
Competitions and leagues.
- **Grain**: One record per competition
- **Key Fields**: `competition_sk`, `competition_id`
- **Attributes**: name, type, country, tier level

#### `dw.dim_date`
Standard date dimension for time-based analysis.
- **Grain**: One record per date
- **Key Fields**: `date_sk`, `date_value`
- **Attributes**: year, quarter, month, day, week, is_weekend, season_name
- **Range**: Pre-populated from 2010 to 2030

#### `dw.dim_season`
Season reference (e.g., '24/25', '23/24').
- **Grain**: One record per season
- **Key Fields**: `season_sk`, `season_name`
- **Attributes**: start year, end year, is_current

#### `dw.dim_agent`
Player agents.
- **Grain**: One record per agent
- **Key Fields**: `agent_sk`, `agent_id`

---

### Facts

#### `dw.fact_player_performance`
Player performance metrics by competition/season.
- **Grain**: One record per player performance entry
- **Dimensions**: player, team, competition, season
- **Measures**: goals, assists, minutes, cards, clean sheets, own goals, etc. (14 measures)
- **Source**: `player_performances` and `player_national_performances` tables

#### `dw.fact_market_value`
Historical and current market values.
- **Grain**: One record per player per date
- **Dimensions**: player, date
- **Measures**: market_value, value_change, value_change_pct
- **Source**: `player_market_value` and `player_latest_market_value` tables

#### `dw.fact_transfer`
Transfer events and fees.
- **Grain**: One record per transfer
- **Dimensions**: player, from_team, to_team, transfer_date, season, transfer_type
- **Measures**: transfer_fee, value_at_transfer, fee_to_value_ratio
- **Source**: `transfer_history` table

#### `dw.fact_injury`
Injury events and recovery periods.
- **Grain**: One record per injury
- **Dimensions**: player, injury_from_date, injury_end_date, season, injury_type
- **Measures**: days_missed, games_missed, severity_score
- **Source**: `player_injuries` table

#### `dw.fact_national_performance`
National team statistics.
- **Grain**: One record per player per national team
- **Dimensions**: player, national_team, first_game_date
- **Measures**: total_matches, total_goals, goals_per_match
- **Source**: `player_national_performances` table

#### `dw.fact_teammate_relationship`
Player partnership metrics.
- **Grain**: One record per player-teammate pair
- **Dimensions**: player, teammate_player
- **Measures**: minutes_played_together, ppg_played_with, joint_goal_participation
- **Source**: `player_teammates_played_with` table

#### `dw.fact_player_season_summary` (Aggregate)
Pre-aggregated player statistics by season for fast queries.
- **Grain**: One record per player per season
- **Dimensions**: player, season
- **Measures**: totals and averages for goals, assists, cards, market value changes, injuries

---

## Files

| File | Description |
|------|-------------|
| `01-create-dimensions.sql` | DDL for all dimension tables |
| `02-create-facts.sql` | DDL for all fact tables |
| `03-helper-functions.sql` | Utility functions for ETL (get_date_sk, get_player_sk, SCD helpers) |
| `init-warehouse.sh` | Bash script to initialize warehouse (Linux/Mac) |
| `init-warehouse.ps1` | PowerShell script to initialize warehouse (Windows) |
| `README.md` | This file |

---

## Setup Instructions

### Prerequisites
- PostgreSQL container `football_data_postgres` running
- Database `football_data_sa` with source data loaded
- Docker installed

### Option 1: Initialize via PowerShell (Windows)
```powershell
cd TRANSFORM\R2W\DATAWAREHOUSE
.\init-warehouse.ps1
```

### Option 2: Initialize via Docker directly
```bash
# Copy SQL files to Docker container
docker cp 01-create-dimensions.sql football_data_postgres:/tmp/
docker cp 02-create-facts.sql football_data_postgres:/tmp/
docker cp 03-helper-functions.sql football_data_postgres:/tmp/

# Execute in order
docker exec football_data_postgres psql -U football_admin -d football_data_sa -f /tmp/01-create-dimensions.sql
docker exec football_data_postgres psql -U football_admin -d football_data_sa -f /tmp/02-create-facts.sql
docker exec football_data_postgres psql -U football_admin -d football_data_sa -f /tmp/03-helper-functions.sql

# Populate date dimension
docker exec football_data_postgres psql -U football_admin -d football_data_sa -c "CALL dw.populate_date_dimension('2010-01-01'::DATE, '2030-12-31'::DATE);"
```

### Option 3: Manual SQL execution
1. Connect to the database:
   ```bash
   docker exec -it football_data_postgres psql -U football_admin -d football_data_sa
   ```

2. Execute each SQL file:
   ```sql
   \i /path/to/01-create-dimensions.sql
   \i /path/to/02-create-facts.sql
   \i /path/to/03-helper-functions.sql
   CALL dw.populate_date_dimension('2010-01-01'::DATE, '2030-12-31'::DATE);
   ```

---

## Verification

After initialization, verify the schema:

```sql
-- List all tables in dw schema
\dt dw.*

-- Check dimension row counts (will be 0 until ETL runs)
SELECT 'dim_player' as table_name, COUNT(*) FROM dw.dim_player
UNION ALL SELECT 'dim_team', COUNT(*) FROM dw.dim_team
UNION ALL SELECT 'dim_competition', COUNT(*) FROM dw.dim_competition
UNION ALL SELECT 'dim_date', COUNT(*) FROM dw.dim_date
UNION ALL SELECT 'dim_season', COUNT(*) FROM dw.dim_season;

-- Check date dimension (should have ~7,670 records for 2010-2030)
SELECT MIN(date_value), MAX(date_value), COUNT(*) FROM dw.dim_date;
```

---

## ETL Notes (Next Steps)

The warehouse schema is now ready. To populate it:

1. **Load Dimensions First** (in this order):
   - `dim_date` (already populated by init script)
   - `dim_agent` (from `player_profiles.player_agent_id`)
   - `dim_team` (from `team_details`)
   - `dim_competition` (from `team_details` and `player_performances`)
   - `dim_season` (derived from `season_name` fields)
   - `dim_player` (from `player_profiles` with SCD2 logic)

2. **Load Facts**:
   - `fact_market_value` (join to `dim_player`, `dim_date`)
   - `fact_transfer` (join to `dim_player`, `dim_team`, `dim_date`)
   - `fact_injury` (join to `dim_player`, `dim_date`)
   - `fact_national_performance` (join to `dim_player`, `dim_team`)
   - `fact_player_performance` (join to `dim_player`, `dim_team`, `dim_competition`, `dim_season`)
   - `fact_teammate_relationship` (join to `dim_player` twice)

3. **Build Aggregates** (optional):
   - `fact_player_season_summary` (aggregated from `fact_player_performance`)

---

## Design Decisions

### SCD Type 2 for Players
- **Why**: Track historical changes to player attributes (club transfers, position changes, contract updates)
- **How**: `valid_from`, `valid_to`, `is_current` fields with surrogate keys
- **Hash**: Use `source_row_hash` to detect changes efficiently

### Team Natural Keys as VARCHAR
- **Why**: Some team_ids in source are non-numeric (e.g., 'FS', '68592')
- **How**: `team_nk VARCHAR(50)` allows flexibility

### Date as Surrogate Key
- **Why**: Faster joins, smaller indexes, consistent with dimensional modeling best practices
- **How**: Use `get_date_sk()` function for lookups

### Degenerate Dimensions
- `season_name` and `competition_name` stored in facts when dimension joins are not available
- Allows queries even if dimension records are missing

### Pre-Aggregated Facts
- `fact_player_season_summary` for fast season-level queries
- Trade-off: storage for query performance

---

## Indexing Strategy

### Dimensions
- Unique index on natural keys
- Index on surrogate keys (primary keys)
- Index on frequently queried attributes (name, country)

### Facts
- Index on each foreign key (player_sk, team_sk, etc.)
- Composite indexes for common query patterns:
  - `(player_sk, season_sk)` for player season queries
  - `(player_sk, date_sk)` for player time-series
- Consider partitioning large facts by season or year

---

## Performance Recommendations

1. **Partitioning**: Partition `fact_player_performance` by `season_name` or year
2. **Materialized Views**: Create for common aggregations
3. **Vacuum**: Regular VACUUM ANALYZE on fact tables
4. **Statistics**: Update statistics after large loads
5. **Connection Pooling**: Use pgBouncer for BI tool connections

---

## Data Quality

Use the built-in view for basic checks:
```sql
SELECT * FROM dw.v_data_quality_checks;
```

Custom validation queries:
```sql
-- Check for orphaned player_sk
SELECT COUNT(*) 
FROM dw.fact_player_performance f
LEFT JOIN dw.dim_player p ON f.player_sk = p.player_sk
WHERE p.player_sk IS NULL;

-- Check for duplicate player records (multiple current versions)
SELECT player_nk, COUNT(*) 
FROM dw.dim_player 
WHERE is_current = TRUE 
GROUP BY player_nk 
HAVING COUNT(*) > 1;
```

---

## Next Steps

1. ✅ Initialize warehouse schema (completed by running init script)
2. ⏳ Develop ETL scripts to load dimensions
3. ⏳ Develop ETL scripts to load facts
4. ⏳ Create validation queries
5. ⏳ Build BI reports/dashboards
6. ⏳ Schedule incremental loads

---

## Support

For questions or issues:
- Review source schema in `TRANSFORM/DATABASE/init-db/01-create-schema.sql`
- Check helper functions in `03-helper-functions.sql`
- Verify source data quality in relational database first
