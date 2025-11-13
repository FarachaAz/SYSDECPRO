# Football Data Warehouse - ETL Documentation

## 📁 Project Structure

```
TRANSFORM/R2W/
│
├── load_dimensions.py      # Loads all 8 dimension tables
├── load_facts_clean.py     # Loads all 7 fact tables
├── verify_warehouse.py     # Validates warehouse integrity
├── run_etl.py             # Master ETL orchestrator
│
└── DATAWAREHOUSE/
    ├── 01-create-dimensions.sql    # DDL for dimensions
    ├── 02-create-facts.sql         # DDL for facts
    ├── 03-helper-functions.sql     # Helper functions
    ├── init-warehouse.ps1          # Initialize warehouse schema
    └── README.md                   # Warehouse schema documentation
```

## 🎯 ETL Process Overview

### Phase 1: Warehouse Initialization
```powershell
cd DATAWAREHOUSE
.\init-warehouse.ps1
```

**Creates:**
- `dw` schema
- 8 dimension tables
- 7 fact tables
- Helper functions (get_date_sk, calculate_player_hash, etc.)

### Phase 2: Load Dimensions
```python
python load_dimensions.py
```

**Loads:**
1. `dim_agent` (3,397 rows) - Player agents
2. `dim_team` (1,304 rows) - Football teams
3. `dim_competition` (107 rows) - Competitions/leagues
4. `dim_season` (56 rows) - Football seasons (handles '24/25', '99/00', '2024' formats)
5. `dim_injury_type` (4 rows) - Injury categories
6. `dim_transfer_type` (6 rows) - Transfer types
7. `dim_player` (40,547 rows) - Players with SCD Type 2
8. `dim_date` (auto-populated via get_date_sk())

**Key Features:**
- SCD Type 2 for player dimension
- Dynamic date dimension expansion
- NULL handling for agents
- Season parsing for multiple formats
- Unicode-safe data loading

### Phase 3: Load Facts
```python
python load_facts_clean.py
```

**Loads:**
1. `fact_player_performance` (139,444 rows) - Match statistics
2. `fact_market_value` (425,302 rows) - Player valuations
3. `fact_transfer` (277,676 rows) - Transfer history
4. `fact_injury` (77,543 rows) - Injury records
5. `fact_national_performance` (62,144 rows) - National team stats
6. `fact_teammate_relationship` (437,371 rows) - Player partnerships
7. `fact_player_season_summary` (126,869 rows) - Aggregated season stats

**Method:** Direct SQL INSERT...SELECT for performance

### Phase 4: Verification
```python
python verify_warehouse.py
```

**Validates:**
- Row counts for all tables
- Data samples
- Join integrity
- Index creation
- Data quality checks

## 🚀 Quick Start

### Run Complete ETL Pipeline
```python
python run_etl.py
```

This executes all phases automatically:
1. Loads dimensions
2. Loads facts
3. Verifies warehouse

## 📊 Data Warehouse Stats

### Total Data Loaded
- **Source Database:** 2,363,786 rows (11 tables)
- **Warehouse:** 1,600,855 rows (15 tables)
- **Database Size:** ~375 MB
- **Warehouse Size:** ~50+ MB

### Star Schema Design

```
          ┌─────────────────┐
          │   dim_player    │◄──┐
          │  (40,547 rows)  │   │
          └─────────────────┘   │
                 ▲                │
                 │                │
          ┌─────────────────┐   │
          │    dim_team     │◄──┼──┐
          │  (1,304 rows)   │   │  │
          └─────────────────┘   │  │
                 ▲                │  │
                 │                │  │
          ┌─────────────────┐   │  │
          │ dim_competition │◄──┼──┼──┐
          │   (107 rows)    │   │  │  │
          └─────────────────┘   │  │  │
                 ▲                │  │  │
                 │                │  │  │
          ┌─────────────────┐   │  │  │  
          │   dim_season    │◄──┼──┼──┼──┐
          │   (56 rows)     │   │  │  │  │
          └─────────────────┘   │  │  │  │
                 ▲                │  │  │  │
                 │                │  │  │  │
    ┌────────────────────────────┴──┴──┴──┴───┐
    │     fact_player_performance (139K)      │
    │     fact_market_value (425K)            │
    │     fact_transfer (278K)                │
    │     fact_injury (78K)                   │
    │     fact_national_performance (62K)     │
    │     fact_teammate_relationship (437K)   │
    │     fact_player_season_summary (127K)   │
    └─────────────────────────────────────────┘
```

## 🔧 Technical Details

### Database Connection
**File:** `../DATABASE/.env`
```ini
DB_HOST=localhost
DB_PORT=5432
DB_NAME=football_data_sa
DB_USER=football_admin
DB_PASSWORD=football_pass_2025
```

### Key Functions

#### `load_dimensions.py`
- **`parse_season(season_str)`** - Handles '24/25', '99/00', '2024' formats
- **`calculate_hash(*args)`** - MD5 hash for SCD Type 2
- **`load_dim_agent()`** - Load agents with NULL handling
- **`load_dim_player()`** - Load players with SCD Type 2

#### Helper Functions (SQL)
- **`get_date_sk(date)`** - Dynamic date dimension management
- **`calculate_player_hash()`** - SCD Type 2 change detection

### Column Mappings Discovered

| Source Table | Source Column | Warehouse Column |
|-------------|---------------|------------------|
| player_performances | second_yellow_cards + direct_red_cards | total_red_cards |
| player_market_value | date_unix | valuation_date_sk |
| player_market_value | value | market_value |
| transfer_history | value_at_transfer | market_value_at_transfer |
| player_injuries | from_date | injury_from_date_sk |
| player_injuries | end_date | injury_end_date_sk |
| player_national_performances | team_name | national_team_name |
| player_national_performances | first_game_date | debut_date_sk |
| player_national_performances | matches | caps |
| player_teammates_played_with | minutes_played_with | minutes_played_together |

## 📈 Sample Queries

### Top Scorers by Season
```sql
SELECT 
    p.player_name,
    s.season_name,
    ps.total_goals,
    ps.total_assists,
    ps.total_matches
FROM dw.fact_player_season_summary ps
JOIN dw.dim_player p ON ps.player_sk = p.player_sk
JOIN dw.dim_season s ON ps.season_sk = s.season_sk
WHERE ps.total_goals > 0
ORDER BY ps.total_goals DESC
LIMIT 10;
```

### Player Market Value Trends
```sql
SELECT 
    p.player_name,
    dd.full_date,
    mv.market_value
FROM dw.fact_market_value mv
JOIN dw.dim_player p ON mv.player_sk = p.player_sk
JOIN dw.dim_date dd ON mv.valuation_date_sk = dd.date_sk
WHERE p.player_name LIKE '%Messi%'
ORDER BY dd.full_date;
```

### Injury Impact Analysis
```sql
SELECT 
    p.player_name,
    s.season_name,
    ps.total_injury_days,
    ps.total_games_missed,
    ps.total_matches
FROM dw.fact_player_season_summary ps
JOIN dw.dim_player p ON ps.player_sk = p.player_sk
JOIN dw.dim_season s ON ps.season_sk = s.season_sk
WHERE ps.total_injury_days > 100
ORDER BY ps.total_injury_days DESC;
```

## ⚠️ Known Issues & Solutions

### Issue 1: Unicode Characters
**Problem:** Windows console displays special characters incorrectly  
**Solution:** Scripts use `.replace()` to handle Unicode gracefully

### Issue 2: NULL Agent Values
**Problem:** Some players have NULL agent_id  
**Solution:** LEFT JOIN and explicit NULL handling in SQL

### Issue 3: Season Format Variations
**Problem:** Mixed formats ('24/25', '99/00', '2024')  
**Solution:** `parse_season()` function with year boundary logic

### Issue 4: Column Name Mismatches
**Problem:** Source columns don't match documentation  
**Solution:** Schema verification before INSERT, explicit column mapping

## 🔍 Verification Checklist

- [x] All 8 dimensions loaded
- [x] All 7 facts loaded
- [x] Foreign key relationships valid
- [x] Indexes created
- [x] No duplicate records
- [x] NULL values handled correctly
- [x] SCD Type 2 working for players
- [x] Date dimension auto-expands
- [x] Aggregate table populated

## 📚 Additional Resources

- **Schema Diagram:** `DATAWAREHOUSE/README.md` (includes Mermaid ER diagram)
- **Docker Setup:** `../DATABASE/README.md`
- **Source Data:** `../../Data/` (11 CSV files)

## 🎓 Lessons Learned

1. **Always verify schema** before writing INSERT statements
2. **Direct SQL outperforms pandas** for bulk loads (10x faster)
3. **Column names in docs ≠ reality** - always check actual tables
4. **NULL handling must be explicit** in function calls
5. **Aggregate tables need explicit population** - not auto-generated

## 🚧 Future Enhancements

- [ ] Materialized views for common queries
- [ ] Partitioning for large fact tables
- [ ] Incremental load support
- [ ] Data quality monitoring
- [ ] Performance optimization
- [ ] BI dashboard templates

---

**Status:** ✅ Production Ready  
**Last Updated:** November 11, 2025  
**Version:** 1.0.0
