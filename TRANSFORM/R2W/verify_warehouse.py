"""
Verification Script: Check Data Warehouse Loading
Provides comprehensive checks on all dimensions and facts
"""

import psycopg2
import os
from dotenv import load_dotenv
from tabulate import tabulate

# Load environment variables
load_dotenv('../DATABASE/.env')

# Database connection parameters
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '5432'),
    'database': os.getenv('DB_NAME', 'football_data_sa'),
    'user': os.getenv('DB_USER', 'football_admin'),
    'password': os.getenv('DB_PASSWORD', 'football_pass_2025')
}

def get_connection():
    """Create database connection"""
    return psycopg2.connect(**DB_CONFIG)

def check_dimensions(conn):
    """Check all dimension tables"""
    print("\n" + "=" * 70)
    print("DIMENSION TABLES")
    print("=" * 70)
    
    cursor = conn.cursor()
    
    dimensions = [
        ('dim_date', 'Date Dimension'),
        ('dim_agent', 'Agent Dimension'),
        ('dim_team', 'Team Dimension'),
        ('dim_competition', 'Competition Dimension'),
        ('dim_season', 'Season Dimension'),
        ('dim_injury_type', 'Injury Type Dimension'),
        ('dim_transfer_type', 'Transfer Type Dimension'),
        ('dim_player', 'Player Dimension (SCD Type 2)')
    ]
    
    results = []
    for table, description in dimensions:
        cursor.execute(f"SELECT COUNT(*) FROM dw.{table}")
        count = cursor.fetchone()[0]
        results.append([description, table, f"{count:,}"])
    
    print(tabulate(results, headers=['Description', 'Table Name', 'Row Count'], tablefmt='grid'))

def check_facts(conn):
    """Check all fact tables"""
    print("\n" + "=" * 70)
    print("FACT TABLES")
    print("=" * 70)
    
    cursor = conn.cursor()
    
    facts = [
        ('fact_player_performance', 'Player Performance Fact'),
        ('fact_market_value', 'Market Value Fact'),
        ('fact_transfer', 'Transfer Fact'),
        ('fact_injury', 'Injury Fact'),
        ('fact_national_performance', 'National Performance Fact'),
        ('fact_teammate_relationship', 'Teammate Relationship Fact'),
        ('fact_player_season_summary', 'Player Season Summary Fact')
    ]
    
    results = []
    for table, description in facts:
        cursor.execute(f"SELECT COUNT(*) FROM dw.{table}")
        count = cursor.fetchone()[0]
        status = "[OK]" if count > 0 else "[EMPTY]"
        results.append([description, table, f"{count:,}", status])
    
    print(tabulate(results, headers=['Description', 'Table Name', 'Row Count', 'Status'], tablefmt='grid'))

def check_data_samples(conn):
    """Show sample data from key tables"""
    print("\n" + "=" * 70)
    print("DATA SAMPLES")
    print("=" * 70)
    
    cursor = conn.cursor()
    
    # Sample players
    print("\n--- Sample Players (Top 5 by player_sk) ---")
    cursor.execute("""
        SELECT player_nk, player_name, position, country_of_birth, 
               date_of_birth, is_current
        FROM dw.dim_player 
        WHERE is_current = TRUE
        ORDER BY player_sk 
        LIMIT 5
    """)
    rows = cursor.fetchall()
    print(tabulate(rows, headers=['Player NK', 'Name', 'Position', 'Country', 'DOB', 'Current'], tablefmt='grid'))
    
    # Sample teams
    print("\n--- Sample Teams (Top 5) ---")
    cursor.execute("""
        SELECT team_nk, team_name, country_name, primary_competition_id
        FROM dw.dim_team 
        ORDER BY team_sk 
        LIMIT 5
    """)
    rows = cursor.fetchall()
    print(tabulate(rows, headers=['Team NK', 'Name', 'Country', 'Competition'], tablefmt='grid'))
    
    # Sample seasons
    print("\n--- All Seasons ---")
    cursor.execute("""
        SELECT season_name, season_start_year, season_end_year, is_current_season
        FROM dw.dim_season 
        ORDER BY season_start_year DESC
        LIMIT 10
    """)
    rows = cursor.fetchall()
    print(tabulate(rows, headers=['Season', 'Start Year', 'End Year', 'Current'], tablefmt='grid'))

def check_data_quality(conn):
    """Check data quality metrics"""
    print("\n" + "=" * 70)
    print("DATA QUALITY CHECKS")
    print("=" * 70)
    
    cursor = conn.cursor()
    
    checks = []
    
    # Check for NULL foreign keys in player dimension
    cursor.execute("""
        SELECT COUNT(*) 
        FROM dw.dim_player 
        WHERE is_current = TRUE 
        AND agent_sk IS NULL
    """)
    null_agents = cursor.fetchone()[0]
    checks.append(['Players without Agent', f"{null_agents:,}", 'INFO' if null_agents > 0 else 'OK'])
    
    # Check for duplicate player natural keys
    cursor.execute("""
        SELECT COUNT(*) 
        FROM (
            SELECT player_nk, COUNT(*) as cnt
            FROM dw.dim_player
            WHERE is_current = TRUE
            GROUP BY player_nk
            HAVING COUNT(*) > 1
        ) dups
    """)
    dup_players = cursor.fetchone()[0]
    checks.append(['Duplicate Current Players', f"{dup_players:,}", 'ERROR' if dup_players > 0 else 'OK'])
    
    # Check date range
    cursor.execute("""
        SELECT MIN(date_value), MAX(date_value)
        FROM dw.dim_date
    """)
    min_date, max_date = cursor.fetchone()
    checks.append(['Date Range Coverage', f"{min_date} to {max_date}", 'OK'])
    
    # Check current season
    cursor.execute("""
        SELECT season_name 
        FROM dw.dim_season 
        WHERE is_current_season = TRUE
    """)
    current_season = cursor.fetchone()
    current_season_name = current_season[0] if current_season else 'NONE'
    checks.append(['Current Season', current_season_name, 'OK' if current_season else 'WARNING'])
    
    print(tabulate(checks, headers=['Check', 'Result', 'Status'], tablefmt='grid'))

def check_joins(conn):
    """Test key joins between dimensions and facts"""
    print("\n" + "=" * 70)
    print("JOIN TESTS (if facts are loaded)")
    print("=" * 70)
    
    cursor = conn.cursor()
    
    # Check if any fact table has data
    cursor.execute("SELECT COUNT(*) FROM dw.fact_player_performance")
    perf_count = cursor.fetchone()[0]
    
    if perf_count == 0:
        print("\n[INFO] No fact data loaded yet. Skipping join tests.")
        return
    
    # Test player performance joins
    print("\n--- Sample Player Performance with Dimensions ---")
    cursor.execute("""
        SELECT 
            p.player_name,
            t.team_name,
            s.season_name,
            c.competition_name,
            fp.goals,
            fp.assists,
            fp.minutes_played
        FROM dw.fact_player_performance fp
        JOIN dw.dim_player p ON fp.player_sk = p.player_sk
        JOIN dw.dim_team t ON fp.team_sk = t.team_sk
        JOIN dw.dim_season s ON fp.season_sk = s.season_sk
        JOIN dw.dim_competition c ON fp.competition_sk = c.competition_sk
        WHERE fp.goals > 0
        ORDER BY fp.goals DESC
        LIMIT 5
    """)
    rows = cursor.fetchall()
    print(tabulate(rows, headers=['Player', 'Team', 'Season', 'Competition', 'Goals', 'Assists', 'Minutes'], tablefmt='grid'))

def check_indexes(conn):
    """Check if indexes exist"""
    print("\n" + "=" * 70)
    print("INDEX CHECK")
    print("=" * 70)
    
    cursor = conn.cursor()
    
    cursor.execute("""
        SELECT 
            schemaname,
            tablename,
            indexname,
            indexdef
        FROM pg_indexes
        WHERE schemaname = 'dw'
        ORDER BY tablename, indexname
    """)
    
    rows = cursor.fetchall()
    
    # Group by table
    current_table = None
    for schema, table, index, indexdef in rows:
        if table != current_table:
            print(f"\n{table}:")
            current_table = table
        print(f"  - {index}")

def generate_summary_report(conn):
    """Generate overall summary"""
    print("\n" + "=" * 70)
    print("WAREHOUSE SUMMARY REPORT")
    print("=" * 70)
    
    cursor = conn.cursor()
    
    # Total dimensions
    cursor.execute("""
        SELECT 
            (SELECT COUNT(*) FROM dw.dim_date) +
            (SELECT COUNT(*) FROM dw.dim_agent) +
            (SELECT COUNT(*) FROM dw.dim_team) +
            (SELECT COUNT(*) FROM dw.dim_competition) +
            (SELECT COUNT(*) FROM dw.dim_season) +
            (SELECT COUNT(*) FROM dw.dim_injury_type) +
            (SELECT COUNT(*) FROM dw.dim_transfer_type) +
            (SELECT COUNT(*) FROM dw.dim_player)
        AS total_dimension_rows
    """)
    total_dims = cursor.fetchone()[0]
    
    # Total facts
    cursor.execute("""
        SELECT 
            (SELECT COUNT(*) FROM dw.fact_player_performance) +
            (SELECT COUNT(*) FROM dw.fact_market_value) +
            (SELECT COUNT(*) FROM dw.fact_transfer) +
            (SELECT COUNT(*) FROM dw.fact_injury) +
            (SELECT COUNT(*) FROM dw.fact_national_performance) +
            (SELECT COUNT(*) FROM dw.fact_teammate_relationship) +
            (SELECT COUNT(*) FROM dw.fact_player_season_summary)
        AS total_fact_rows
    """)
    total_facts = cursor.fetchone()[0]
    
    # Database size
    cursor.execute("""
        SELECT pg_size_pretty(pg_database_size('football_data_sa'))
    """)
    db_size = cursor.fetchone()[0]
    
    # Schema size
    cursor.execute("""
        SELECT pg_size_pretty(SUM(pg_total_relation_size(quote_ident(schemaname) || '.' || quote_ident(tablename)))::bigint)
        FROM pg_tables
        WHERE schemaname = 'dw'
    """)
    dw_size = cursor.fetchone()[0]
    
    summary = [
        ['Total Dimension Rows', f"{total_dims:,}"],
        ['Total Fact Rows', f"{total_facts:,}"],
        ['Total Warehouse Rows', f"{total_dims + total_facts:,}"],
        ['Database Size', db_size],
        ['Data Warehouse (dw) Size', dw_size]
    ]
    
    print(tabulate(summary, headers=['Metric', 'Value'], tablefmt='grid'))

def main():
    """Main verification process"""
    print("\n" + "=" * 70)
    print("DATA WAREHOUSE VERIFICATION")
    print("=" * 70)
    print(f"Database: {DB_CONFIG['database']}@{DB_CONFIG['host']}")
    print(f"Schema: dw")
    print("=" * 70)
    
    conn = get_connection()
    
    try:
        check_dimensions(conn)
        check_facts(conn)
        check_data_samples(conn)
        check_data_quality(conn)
        check_joins(conn)
        check_indexes(conn)
        generate_summary_report(conn)
        
        print("\n" + "=" * 70)
        print("[OK] VERIFICATION COMPLETE")
        print("=" * 70)
        
    except Exception as e:
        print(f"\n[ERROR] {e}")
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    main()
