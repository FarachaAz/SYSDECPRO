"""
Football Data ETL - Load CSV data into PostgreSQL
This script loads all CSV files from the Data directory into the PostgreSQL database.
"""

import os
import pandas as pd
import psycopg2
from psycopg2 import sql
from sqlalchemy import create_engine
from dotenv import load_dotenv
from tqdm import tqdm
import logging
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('data_load.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '5432'),
    'database': os.getenv('DB_NAME', 'football_data_sa'),
    'user': os.getenv('DB_USER', 'football_admin'),
    'password': os.getenv('DB_PASSWORD', 'football_pass_2025')
}

DATA_DIR = os.getenv('DATA_DIR', '../../Data')

# Mapping of CSV files to database tables
TABLE_MAPPING = {
    'player_profiles': {
        'file': 'player_profiles/player_profiles.csv',
        'table': 'player_profiles',
        'chunk_size': 5000,
        'date_columns': ['date_of_birth', 'joined', 'contract_expires', 
                        'date_of_last_contract_extension', 'contract_there_expires', 'date_of_death']
    },
    'player_injuries': {
        'file': 'player_injuries/player_injuries.csv',
        'table': 'player_injuries',
        'chunk_size': 10000,
        'date_columns': ['from_date', 'end_date']
    },
    'player_market_value': {
        'file': 'player_market_value/player_market_value.csv',
        'table': 'player_market_value',
        'chunk_size': 20000,
        'date_columns': []
    },
    'player_latest_market_value': {
        'file': 'player_latest_market_value/player_latest_market_value.csv',
        'table': 'player_latest_market_value',
        'chunk_size': 10000,
        'date_columns': []
    },
    'player_national_performances': {
        'file': 'player_national_performances/player_national_performances.csv',
        'table': 'player_national_performances',
        'chunk_size': 10000,
        'date_columns': ['first_game_date']
    },
    'player_performances': {
        'file': 'player_performances/player_performances.csv',
        'table': 'player_performances',
        'chunk_size': 50000,
        'date_columns': []
    },
    'player_teammates_played_with': {
        'file': 'player_teammates_played_with/player_teammates_played_with.csv',
        'table': 'player_teammates_played_with',
        'chunk_size': 50000,
        'date_columns': []
    },
    'team_details': {
        'file': 'team_details/team_details.csv',
        'table': 'team_details',
        'chunk_size': 5000,
        'date_columns': []
    },
    'team_children': {
        'file': 'team_children/team_children.csv',
        'table': 'team_children',
        'chunk_size': 5000,
        'date_columns': []
    },
    'team_competitions_seasons': {
        'file': 'team_competitions_seasons/team_competitions_seasons.csv',
        'table': 'team_competitions_seasons',
        'chunk_size': 5000,
        'date_columns': []
    },
    'transfer_history': {
        'file': 'transfer_history/transfer_history.csv',
        'table': 'transfer_history',
        'chunk_size': 20000,
        'date_columns': ['transfer_date']
    }
}


def create_connection():
    """Create database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        logger.info("✓ Database connection established")
        return conn
    except Exception as e:
        logger.error(f"✗ Error connecting to database: {e}")
        raise


def create_sqlalchemy_engine():
    """Create SQLAlchemy engine for pandas to_sql"""
    connection_string = f"postgresql://{DB_CONFIG['user']}:{DB_CONFIG['password']}@{DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}"
    return create_engine(connection_string)


def check_database_connection():
    """Test database connection and verify schema"""
    try:
        conn = create_connection()
        cursor = conn.cursor()
        
        # Check if tables exist
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public'
            ORDER BY table_name;
        """)
        
        tables = cursor.fetchall()
        logger.info(f"✓ Found {len(tables)} tables in database")
        for table in tables:
            logger.info(f"  - {table[0]}")
        
        cursor.close()
        conn.close()
        return True
    except Exception as e:
        logger.error(f"✗ Database connection check failed: {e}")
        return False


def clean_dataframe(df, date_columns=None):
    """Clean DataFrame before loading"""
    # Replace empty strings with None
    df = df.replace('', None)
    df = df.replace('nan', None)
    
    # Convert date columns
    if date_columns:
        for col in date_columns:
            if col in df.columns:
                df[col] = pd.to_datetime(df[col], errors='coerce')
    
    return df


def load_csv_to_table(config_key, engine, conn):
    """Load a CSV file into its corresponding database table"""
    config = TABLE_MAPPING[config_key]
    file_path = os.path.join(DATA_DIR, config['file'])
    table_name = config['table']
    chunk_size = config['chunk_size']
    date_columns = config['date_columns']
    
    if not os.path.exists(file_path):
        logger.warning(f"⚠ File not found: {file_path}")
        return False
    
    try:
        # Get total rows for progress bar
        total_rows = sum(1 for _ in open(file_path, encoding='utf-8')) - 1  # Subtract header
        logger.info(f"Loading {config_key}: {total_rows:,} rows from {config['file']}")
        
        # Truncate table before loading (optional - remove if you want to append)
        cursor = conn.cursor()
        cursor.execute(f"TRUNCATE TABLE {table_name} RESTART IDENTITY CASCADE;")
        conn.commit()
        cursor.close()
        logger.info(f"  Truncated table {table_name}")
        
        # Load data in chunks
        chunks_processed = 0
        rows_loaded = 0
        
        with tqdm(total=total_rows, desc=f"  Loading {table_name}") as pbar:
            for chunk in pd.read_csv(file_path, chunksize=chunk_size, low_memory=False):
                # Clean the chunk
                chunk = clean_dataframe(chunk, date_columns)
                
                # Load to database
                chunk.to_sql(
                    table_name,
                    engine,
                    if_exists='append',
                    index=False,
                    method='multi'
                )
                
                chunks_processed += 1
                rows_loaded += len(chunk)
                pbar.update(len(chunk))
        
        logger.info(f"✓ Loaded {rows_loaded:,} rows into {table_name} ({chunks_processed} chunks)")
        return True
        
    except Exception as e:
        logger.error(f"✗ Error loading {config_key}: {e}")
        return False


def verify_data_load(conn):
    """Verify data has been loaded correctly"""
    logger.info("\n" + "="*60)
    logger.info("VERIFYING DATA LOAD")
    logger.info("="*60)
    
    cursor = conn.cursor()
    
    for config_key, config in TABLE_MAPPING.items():
        table_name = config['table']
        try:
            cursor.execute(f"SELECT COUNT(*) FROM {table_name};")
            count = cursor.fetchone()[0]
            logger.info(f"✓ {table_name}: {count:,} rows")
        except Exception as e:
            logger.error(f"✗ Error checking {table_name}: {e}")
    
    cursor.close()


def main():
    """Main ETL process"""
    logger.info("="*60)
    logger.info("FOOTBALL DATA ETL - LOADING PROCESS STARTED")
    logger.info("="*60)
    logger.info(f"Start Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    # Check database connection
    if not check_database_connection():
        logger.error("Cannot proceed without database connection")
        return
    
    # Create connections
    engine = create_sqlalchemy_engine()
    conn = create_connection()
    
    # Disable foreign key constraints for the session
    try:
        cursor = conn.cursor()
        logger.info("⚙️  Disabling foreign key constraints for data load...")
        cursor.execute("SET session_replication_role = 'replica';")
        conn.commit()
        logger.info("✓ Foreign key constraints disabled\n")
        cursor.close()
    except Exception as e:
        logger.error(f"✗ Failed to disable foreign key constraints: {e}")
        conn.close()
        engine.dispose()
        return
    
    # Load order matters due to foreign keys
    load_order = [
        'player_profiles',           # Must be first (referenced by others)
        'team_details',              # Independent
        'team_children',             # Independent
        'team_competitions_seasons', # Independent
        'player_injuries',           # Depends on player_profiles
        'player_market_value',       # Depends on player_profiles
        'player_latest_market_value',# Depends on player_profiles
        'player_national_performances', # Depends on player_profiles
        'player_performances',       # Depends on player_profiles (large file)
        'player_teammates_played_with', # Depends on player_profiles
        'transfer_history'           # Depends on player_profiles
    ]
    
    logger.info("\n" + "="*60)
    logger.info("STARTING DATA LOAD")
    logger.info("="*60 + "\n")
    
    success_count = 0
    failed_count = 0
    
    for config_key in load_order:
        if load_csv_to_table(config_key, engine, conn):
            success_count += 1
        else:
            failed_count += 1
        logger.info("")  # Empty line for readability
    
    # Verify data load
    verify_data_load(conn)
    
    # Re-enable foreign key constraints
    try:
        cursor = conn.cursor()
        logger.info("\n⚙️  Re-enabling foreign key constraints...")
        cursor.execute("SET session_replication_role = 'origin';")
        conn.commit()
        logger.info("✓ Foreign key constraints re-enabled")
        cursor.close()
    except Exception as e:
        logger.error(f"✗ Failed to re-enable foreign key constraints: {e}")
    
    # Close connections
    conn.close()
    engine.dispose()
    
    # Summary
    logger.info("\n" + "="*60)
    logger.info("LOAD PROCESS COMPLETED")
    logger.info("="*60)
    logger.info(f"End Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    logger.info(f"Tables loaded successfully: {success_count}")
    logger.info(f"Tables failed: {failed_count}")
    logger.info("="*60 + "\n")


if __name__ == "__main__":
    main()
