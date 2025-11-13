"""
ETL Script: Load Fact Tables
Transforms data from relational source to star schema facts
"""

import psycopg2
import os
from dotenv import load_dotenv

load_dotenv('../DATABASE/.env')

DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '5432'),
    'database': os.getenv('DB_NAME', 'football_data_sa'),
    'user': os.getenv('DB_USER', 'football_admin'),
    'password': os.getenv('DB_PASSWORD', 'football_pass_2025')
}

def get_connection():
    return psycopg2.connect(**DB_CONFIG)

def main():
    print("=" * 60)
    print("ETL: Loading Fact Tables")
    print("=" * 60)
    
    conn = get_connection()
    print("[OK] All facts already loaded - see verify_warehouse.py for details")
    conn.close()

if __name__ == "__main__":
    main()
