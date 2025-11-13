# ETL Quick Reference Guide

## 📋 File Purpose

| File | Purpose | Rows Loaded |
|------|---------|-------------|
| `load_dimensions.py` | Load all 8 dimension tables | 54,506 |
| `load_facts.py` | Load all 7 fact tables | 1,546,349 |
| `verify_warehouse.py` | Validate warehouse integrity | N/A |
| `run_etl.py` | Master orchestrator - runs all scripts | N/A |

## 🎯 Usage

### Option 1: Run Complete Pipeline (Recommended)
```bash
python run_etl.py
```
**Output:**
- ✅ Loads all dimensions
- ✅ Loads all facts  
- ✅ Verifies warehouse
- ✅ Shows summary statistics

### Option 2: Run Individual Scripts
```bash
# Step 1: Load dimensions
python load_dimensions.py

# Step 2: Load facts
python load_facts.py

# Step 3: Verify warehouse
python verify_warehouse.py
```

## 📊 What Gets Loaded

### Dimensions (54,506 rows)
- dim_date (auto-populated via get_date_sk)
- dim_player (40,547) - SCD Type 2
- dim_agent (3,397)
- dim_team (1,304)
- dim_competition (107)
- dim_season (56)
- dim_transfer_type (6)
- dim_injury_type (4)

### Facts (1,546,349 rows)
- fact_teammate_relationship (437,371)
- fact_market_value (425,302)
- fact_transfer (277,676)
- fact_player_performance (139,444)
- fact_player_season_summary (126,869)
- fact_injury (77,543)
- fact_national_performance (62,144)

## ⚡ Performance Notes

- **Dimension Loading:** ~2-3 minutes (uses pandas iteration)
- **Fact Loading:** ~5-10 minutes (uses direct SQL INSERT...SELECT)
- **Verification:** ~30 seconds
- **Total ETL Time:** ~8-15 minutes

## 🔧 Requirements

```bash
pip install psycopg2-binary pandas python-dotenv tqdm tabulate
```

## 🎓 Script Details

### load_dimensions.py
**Key Functions:**
- `load_dim_agent()` - Loads player agents
- `load_dim_team()` - Loads teams from team_details
- `load_dim_competition()` - Extracts unique competitions
- `load_dim_season()` - Handles mixed season formats
- `load_dim_injury_type()` - Categorizes injury types
- `load_dim_player()` - Implements SCD Type 2 for players

**Special Features:**
- Parses season formats: '24/25', '99/00', '2024'
- Handles NULL agents gracefully
- Calculates MD5 hash for SCD Type 2
- Unicode-safe string handling

### load_facts.py
**Method:** Direct SQL INSERT...SELECT (faster than pandas)

**Key Features:**
- Checks existing data before loading
- Skips reload if data exists
- Uses proper column mappings
- Handles NULL dates with CASE statements
- Aggregates fact_player_season_summary from performance data

### verify_warehouse.py
**Checks:**
- Row counts for all tables
- Sample data from each table
- Join integrity tests
- Index verification
- Data quality validation

**Output:** Formatted table with statistics

## 🚨 Troubleshooting

### Issue: "Table already contains X rows"
**Solution:** Data already loaded - safe to skip

### Issue: Unicode display errors
**Solution:** Cosmetic only - data loads correctly

### Issue: Connection error
**Solution:** Check Docker container is running:
```bash
docker ps | findstr football_data_postgres
```

### Issue: Missing .env file
**Solution:** Create `../DATABASE/.env` with:
```ini
DB_HOST=localhost
DB_PORT=5432
DB_NAME=football_data_sa
DB_USER=football_admin
DB_PASSWORD=football_pass_2025
```

## ✅ Success Indicators

You'll see:
```
=============================================================
[OK] ALL DIMENSIONS LOADED SUCCESSFULLY
=============================================================

Dimension Summary:
  dim_date                      :     54,506 rows
  dim_agent                     :      3,397 rows
  ...
```

```
=============================================================
[OK] ALL FACT TABLES LOADED SUCCESSFULLY
=============================================================

Fact Table Summary:
  fact_player_performance       :    139,444 rows
  fact_market_value             :    425,302 rows
  ...
  
  TOTAL FACT ROWS               :  1,546,349 rows
```

## 📈 Next Steps After ETL

1. **Connect BI Tool** (Power BI, Tableau, Looker)
2. **Create Analytical Views**
3. **Build Dashboards**
4. **Run Sample Queries** (see README.md)
5. **Set up Incremental Loads** (future)

---

**Note:** All data is already loaded in your warehouse. Running scripts again will skip existing data.

**Status:** ✅ Warehouse fully operational with 1.6M+ rows
