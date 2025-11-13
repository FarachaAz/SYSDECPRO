"""
ETL Script: Load Dimension Tables
Transforms data from source relational database to star schema dimensions
"""

import psycopg2
import pandas as pd
from datetime import datetime
import hashlib
from tqdm import tqdm
import os
from dotenv import load_dotenv

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

def calculate_hash(*args):
    """Calculate MD5 hash for SCD Type 2 change detection"""
    concat_str = ''.join([str(arg) if arg is not None else '' for arg in args])
    return hashlib.md5(concat_str.encode()).hexdigest()

def load_dim_agent(conn):
    """Load Agent Dimension from player_profiles"""
    print("\n=== Loading dim_agent ===")
    
    cursor = conn.cursor()
    
    # Extract unique agents from source
    query = """
    SELECT DISTINCT 
        player_agent_id,
        player_agent_name
    FROM player_profiles
    WHERE player_agent_id IS NOT NULL
    ORDER BY player_agent_id
    """
    
    df = pd.read_sql(query, conn)
    print(f"Found {len(df)} unique agents")
    
    # Insert into dimension
    insert_query = """
    INSERT INTO dw.dim_agent (agent_id, agent_name)
    VALUES (%s, %s)
    ON CONFLICT (agent_id) DO UPDATE 
    SET agent_name = EXCLUDED.agent_name
    """
    
    for _, row in tqdm(df.iterrows(), total=len(df), desc="Loading agents"):
        cursor.execute(insert_query, (row['player_agent_id'], row['player_agent_name']))
    
    conn.commit()
    cursor.execute("SELECT COUNT(*) FROM dw.dim_agent")
    count = cursor.fetchone()[0]
    print(f"[OK] Loaded {count} agents")

def load_dim_team(conn):
    """Load Team Dimension from team_details"""
    print("\n=== Loading dim_team ===")
    
    cursor = conn.cursor()
    
    # Extract teams from source
    query = """
    SELECT DISTINCT 
        CAST(club_id AS VARCHAR) as team_id,
        club_name as team_name,
        COALESCE(country_name, 'Unknown') as team_country,
        COALESCE(competition_name, 'Unknown') as competition_name,
        COALESCE(CAST(SUBSTRING(club_division FROM '[0-9]+') AS INTEGER), 99) as tier_level
    FROM team_details
    WHERE club_id IS NOT NULL
    ORDER BY team_id
    """
    
    df = pd.read_sql(query, conn)
    print(f"Found {len(df)} teams from team_details")
    
    # Insert into dimension
    insert_query = """
    INSERT INTO dw.dim_team (team_nk, team_name, country_name, primary_competition_id, division_level)
    VALUES (%s, %s, %s, %s, %s)
    ON CONFLICT (team_nk) DO UPDATE 
    SET team_name = EXCLUDED.team_name,
        country_name = EXCLUDED.country_name,
        primary_competition_id = EXCLUDED.primary_competition_id,
        division_level = EXCLUDED.division_level
    """
    
    for _, row in tqdm(df.iterrows(), total=len(df), desc="Loading teams"):
        cursor.execute(insert_query, (
            row['team_id'],
            row['team_name'],
            row['team_country'],
            row['competition_name'],
            row['tier_level']
        ))
    
    conn.commit()
    cursor.execute("SELECT COUNT(*) FROM dw.dim_team")
    count = cursor.fetchone()[0]
    print(f"[OK] Loaded {count} teams")

def load_dim_competition(conn):
    """Load Competition Dimension from team_details"""
    print("\n=== Loading dim_competition ===")
    
    cursor = conn.cursor()
    
    # Extract unique competitions
    query = """
    SELECT DISTINCT 
        competition_name,
        country_name as country,
        COALESCE(CAST(SUBSTRING(club_division FROM '[0-9]+') AS INTEGER), 99) as tier_level
    FROM team_details
    WHERE competition_name IS NOT NULL
    ORDER BY competition_name
    """
    
    df = pd.read_sql(query, conn)
    print(f"Found {len(df)} unique competitions")
    
    # Generate competition_id from name
    df['competition_id'] = df['competition_name'].str.lower().str.replace(' ', '_')
    
    insert_query = """
    INSERT INTO dw.dim_competition (competition_id, competition_name, country_name, tier_level)
    VALUES (%s, %s, %s, %s)
    ON CONFLICT (competition_id) DO UPDATE 
    SET competition_name = EXCLUDED.competition_name,
        country_name = EXCLUDED.country_name,
        tier_level = EXCLUDED.tier_level
    """
    
    for _, row in tqdm(df.iterrows(), total=len(df), desc="Loading competitions"):
        cursor.execute(insert_query, (
            row['competition_id'],
            row['competition_name'],
            row['country'],
            row['tier_level']
        ))
    
    conn.commit()
    cursor.execute("SELECT COUNT(*) FROM dw.dim_competition")
    count = cursor.fetchone()[0]
    print(f"[OK] Loaded {count} competitions")

def load_dim_season(conn):
    """Load Season Dimension from player_performances"""
    print("\n=== Loading dim_season ===")
    
    cursor = conn.cursor()
    
    # Extract unique seasons
    query = """
    SELECT DISTINCT season_name
    FROM player_performances
    WHERE season_name IS NOT NULL
    ORDER BY season_name DESC
    """
    
    df = pd.read_sql(query, conn)
    print(f"Found {len(df)} unique seasons")
    
    # Parse season_name to extract years
    def parse_season(season_str):
        try:
            if '/' in season_str:
                # Handle season format like '24/25' or '99/00'
                parts = season_str.split('/')
                year1 = int(parts[0])
                year2 = int(parts[1])
                
                # Handle 2-digit years: >= 50 means 19xx, < 50 means 20xx
                start_year = (1900 + year1) if year1 >= 50 else (2000 + year1)
                
                # Second year is always start_year + 1 for football seasons
                end_year = start_year + 1
            else:
                # Handle single year format like '2020'
                year = int(season_str)
                start_year = year
                end_year = year + 1
            
            return start_year, end_year
        except:
            return None, None
    
    df[['start_year', 'end_year']] = df['season_name'].apply(
        lambda x: pd.Series(parse_season(x))
    )
    
    # Mark current season (24/25 or latest)
    current_season = df.iloc[0]['season_name'] if len(df) > 0 else None
    
    insert_query = """
    INSERT INTO dw.dim_season (season_name, season_start_year, season_end_year, is_current_season)
    VALUES (%s, %s, %s, %s)
    ON CONFLICT (season_name) DO UPDATE 
    SET season_start_year = EXCLUDED.season_start_year,
        season_end_year = EXCLUDED.season_end_year,
        is_current_season = EXCLUDED.is_current_season
    """
    
    for _, row in tqdm(df.iterrows(), total=len(df), desc="Loading seasons"):
        is_current = (row['season_name'] == current_season)
        cursor.execute(insert_query, (
            row['season_name'],
            row['start_year'],
            row['end_year'],
            is_current
        ))
    
    conn.commit()
    cursor.execute("SELECT COUNT(*) FROM dw.dim_season")
    count = cursor.fetchone()[0]
    print(f"[OK] Loaded {count} seasons")

def load_dim_injury_type(conn):
    """Load Injury Type Dimension from player_injuries"""
    print("\n=== Loading dim_injury_type ===")
    
    cursor = conn.cursor()
    
    # Extract unique injury types (using injury_reason as injury type)
    query = """
    SELECT DISTINCT 
        injury_reason as injury_type,
        COUNT(*) as frequency
    FROM player_injuries
    WHERE injury_reason IS NOT NULL
    GROUP BY injury_reason
    ORDER BY frequency DESC
    """
    
    df = pd.read_sql(query, conn)
    print(f"Found {len(df)} unique injury types")
    
    # Categorize injuries (simple categorization)
    def categorize_injury(injury_type):
        injury_lower = injury_type.lower() if injury_type else ''
        if any(word in injury_lower for word in ['muscle', 'strain', 'tear']):
            return 'Muscular', 'Medium'
        elif any(word in injury_lower for word in ['fracture', 'break', 'rupture']):
            return 'Bone/Ligament', 'High'
        elif any(word in injury_lower for word in ['ankle', 'knee', 'hip']):
            return 'Joint', 'Medium'
        else:
            return 'Other', 'Low'
    
    df[['category', 'severity']] = df['injury_type'].apply(
        lambda x: pd.Series(categorize_injury(x))
    )
    
    # Insert unique categories only
    unique_categories = df[['category', 'severity']].drop_duplicates()
    
    for _, row in tqdm(unique_categories.iterrows(), total=len(unique_categories), desc="Loading injury types"):
        # Check if this combination already exists
        check_query = """
        SELECT injury_type_sk FROM dw.dim_injury_type 
        WHERE injury_category = %s AND injury_severity = %s
        """
        cursor.execute(check_query, (row['category'], row['severity']))
        
        if cursor.fetchone() is None:
            # Insert if not exists
            insert_query = """
            INSERT INTO dw.dim_injury_type (injury_category, injury_severity)
            VALUES (%s, %s)
            """
            cursor.execute(insert_query, (row['category'], row['severity']))
    
    conn.commit()
    cursor.execute("SELECT COUNT(*) FROM dw.dim_injury_type")
    count = cursor.fetchone()[0]
    print(f"[OK] Loaded {count} injury types")

def load_dim_player(conn):
    """Load Player Dimension with SCD Type 2 from player_profiles"""
    print("\n=== Loading dim_player (SCD Type 2) ===")
    
    cursor = conn.cursor()
    
    # Extract player data with agent lookup
    query = """
    SELECT 
        p.player_id,
        p.player_name,
        p.position,
        p.date_of_birth,
        p.height,
        p.foot,
        p.current_club_id,
        p.current_club_name,
        p.country_of_birth,
        p.citizenship,
        p.contract_expires,
        p.player_agent_id,
        a.agent_sk
    FROM player_profiles p
    LEFT JOIN dw.dim_agent a ON p.player_agent_id = a.agent_id
    WHERE p.player_id IS NOT NULL
      AND p.player_name IS NOT NULL
    ORDER BY p.player_id
    """
    
    df = pd.read_sql(query, conn)
    print(f"Found {len(df)} players")
    
    # Calculate hash for SCD detection
    df['source_row_hash'] = df.apply(
        lambda row: calculate_hash(
            row['player_name'],
            row['position'],
            row['current_club_id'],
            row['contract_expires'],
            row['agent_sk']
        ),
        axis=1
    )
    
    insert_query = """
    INSERT INTO dw.dim_player (
        player_nk, player_name, position, date_of_birth, height_cm, 
        foot, current_club_nk, current_club_name,
        country_of_birth, citizenship, contract_expires,
        agent_sk, valid_from, valid_to, is_current, source_row_hash
    )
    VALUES (
        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
    )
    """
    
    valid_from = datetime.now().date()
    
    for idx, row in tqdm(df.iterrows(), total=len(df), desc="Loading players"):
        try:
            cursor.execute(insert_query, (
                row['player_id'],
                row['player_name'],
                row['position'],
                row['date_of_birth'],
                row['height'],
                row['foot'],
                str(row['current_club_id']) if pd.notna(row['current_club_id']) else None,
                row['current_club_name'],
                row['country_of_birth'],
                row['citizenship'],
                row['contract_expires'],
                int(row['agent_sk']) if pd.notna(row['agent_sk']) else None,
                valid_from,
                None,  # valid_to (NULL for current records)
                True,  # is_current
                row['source_row_hash']
            ))
        except Exception as e:
            print(f"\n[ERROR] Failed on player {row['player_id']} - {row['player_name']}")
            print(f"agent_sk value: {row['agent_sk']} (type: {type(row['agent_sk'])})")
            print(f"Error: {e}")
            raise
    
    conn.commit()
    cursor.execute("SELECT COUNT(*) FROM dw.dim_player WHERE is_current = TRUE")
    count = cursor.fetchone()[0]
    print(f"[OK] Loaded {count} current player records")

def main():
    """Main ETL process for dimensions"""
    print("=" * 60)
    print("ETL: Loading Dimension Tables")
    print("=" * 60)
    print(f"Source: {DB_CONFIG['database']}@{DB_CONFIG['host']}")
    print(f"Target: dw schema in same database")
    print("=" * 60)
    
    try:
        conn = get_connection()
        
        # Load dimensions in dependency order
        load_dim_agent(conn)
        load_dim_team(conn)
        load_dim_competition(conn)
        load_dim_season(conn)
        load_dim_injury_type(conn)
        load_dim_player(conn)  # Last because it depends on agent
        
        conn.close()
        
        print("\n" + "=" * 60)
        print("[OK] ALL DIMENSIONS LOADED SUCCESSFULLY")
        print("=" * 60)
        
        # Show summary
        conn = get_connection()
        cursor = conn.cursor()
        
        print("\nDimension Summary:")
        dimensions = [
            'dim_date', 'dim_agent', 'dim_team', 'dim_competition', 
            'dim_season', 'dim_injury_type', 'dim_transfer_type', 'dim_player'
        ]
        
        for dim in dimensions:
            cursor.execute(f"SELECT COUNT(*) FROM dw.{dim}")
            count = cursor.fetchone()[0]
            print(f"  {dim:30s}: {count:>10,} rows")
        
        conn.close()
        
    except Exception as e:
        print(f"\n[ERROR] ERROR: {e}")
        raise

if __name__ == "__main__":
    main()
