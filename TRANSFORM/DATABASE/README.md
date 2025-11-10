# Football Data - PostgreSQL Database Setup

This directory contains the PostgreSQL database setup for the football data operational database.

## 📋 Prerequisites

- Docker Desktop installed and running
- Python 3.8 or higher

## 🗄️ Database Credentials

- **Host**: localhost
- **Port**: 5432
- **Database**: football_data_sa
- **Username**: football_admin
- **Password**: football_pass_2025

## 📊 Database Schema

The database contains 11 tables organized in a relational structure:

### Player Tables
- `player_profiles` - Master player information (40K+ records)
- `player_injuries` - Injury history (77K+ records)
- `player_market_value` - Historical market values (426K+ records)
- `player_latest_market_value` - Current market values (31K+ records)
- `player_national_performances` - National team stats (62K+ records)
- `player_performances` - Club performance statistics (large dataset)
- `player_teammates_played_with` - Teammate relationships (681K+ records)

### Team Tables
- `team_details` - Team information by season (1.3K+ records)
- `team_children` - Parent/child club relationships (4.9K+ records)
- `team_competitions_seasons` - Team competition participation (1.3K+ records)

### Transfer Tables
- `transfer_history` - Complete transfer records (279K+ records)

## 🚀 Quick Start

### Step 1: Start PostgreSQL Database

```powershell
# Navigate to DATABASE directory
cd C:\Users\Fares\Videos\SYSDECPRO\TRANSFORM\DATABASE

# Start Docker container
docker-compose up -d

# Check if container is running
docker ps

# View logs (optional)
docker-compose logs -f postgres
```

### Step 2: Install Python Dependencies

```powershell
# Create virtual environment (recommended)
python -m venv venv

# Activate virtual environment
.\venv\Scripts\Activate

# Install dependencies
pip install -r requirements.txt
```

### Step 3: Load Data

```powershell
# Make sure you're in the DATABASE directory
cd C:\Users\Fares\Videos\SYSDECPRO\TRANSFORM\DATABASE

# Run the data loading script
python load_data.py
```

## 📁 Directory Structure

```
TRANSFORM/DATABASE/
│
├── init-db/
│   └── 01-create-schema.sql    # Database schema creation
│
├── docker-compose.yml           # Docker configuration
├── .env                         # Environment variables
├── requirements.txt             # Python dependencies
├── load_data.py                 # Data loading script
├── README.md                    # This file
└── data_load.log               # Load process logs (generated)
```

## 🔍 Verify Data Load

### Using Python Script
The `load_data.py` script automatically verifies data after loading.

### Using psql Command Line
```powershell
# Connect to database
docker exec -it football_data_postgres psql -U football_admin -d football_data_sa

# Check table counts
SELECT 'player_profiles' as table_name, COUNT(*) FROM player_profiles
UNION ALL
SELECT 'player_injuries', COUNT(*) FROM player_injuries
UNION ALL
SELECT 'transfer_history', COUNT(*) FROM transfer_history;

# Exit psql
\q
```

### Using DBeaver/pgAdmin
1. Create new connection
2. Use credentials from above
3. Browse tables and run queries

## 🛠️ Management Commands

### Stop Database
```powershell
docker-compose down
```

### Stop and Remove Data
```powershell
docker-compose down -v
```

### Restart Database
```powershell
docker-compose restart
```

### View Logs
```powershell
docker-compose logs -f postgres
```

### Backup Database
```powershell
docker exec football_data_postgres pg_dump -U football_admin football_data_sa > backup.sql
```

### Restore Database
```powershell
Get-Content backup.sql | docker exec -i football_data_postgres psql -U football_admin -d football_data_sa
```

## 🔧 Troubleshooting

### Port 5432 Already in Use
```powershell
# Check what's using the port
netstat -ano | findstr :5432

# Stop existing PostgreSQL service or change port in docker-compose.yml
```

### Connection Refused
```powershell
# Check if container is running
docker ps

# Check container logs
docker-compose logs postgres

# Restart container
docker-compose restart
```

### Data Loading Errors
- Check `data_load.log` for detailed error messages
- Verify CSV files exist in `../../Data/` directory
- Ensure database schema is created (check init-db folder)

## 📈 Next Steps

After loading data into PostgreSQL, proceed to:
1. Data quality analysis
2. Star schema design for data warehouse
3. ETL pipeline development

---

**Database Ready! 🚀**
