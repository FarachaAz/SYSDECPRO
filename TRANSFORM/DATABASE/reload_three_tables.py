"""
Reload the 3 tables with fixed schema
"""
from load_data import *

print("Starting reload of 3 tables with fixed schema...")

# Create connections
engine = create_sqlalchemy_engine()
conn = create_connection()

# Disable foreign key constraints
cursor = conn.cursor()
cursor.execute("SET session_replication_role = 'replica';")
conn.commit()
cursor.close()
print("✓ Foreign key constraints disabled\n")

# Load the 3 tables
tables_to_load = [
    'player_market_value',
    'player_latest_market_value',
    'player_national_performances'
]

success_count = 0
for table in tables_to_load:
    print(f"\n{'='*60}")
    print(f"Loading {table}...")
    print('='*60)
    if load_csv_to_table(table, engine, conn):
        success_count += 1
        print(f"✓ {table} loaded successfully")
    else:
        print(f"✗ {table} failed")

# Re-enable foreign key constraints
cursor = conn.cursor()
cursor.execute("SET session_replication_role = 'origin';")
conn.commit()
cursor.close()
print("\n✓ Foreign key constraints re-enabled")

# Verify
print("\n" + "="*60)
print("VERIFICATION")
print("="*60)
cursor = conn.cursor()
for table in tables_to_load:
    cursor.execute(f"SELECT COUNT(*) FROM {TABLE_MAPPING[table]['table']};")
    count = cursor.fetchone()[0]
    print(f"  {table}: {count:,} rows")
cursor.close()

conn.close()
engine.dispose()

print(f"\n✓ Reload completed: {success_count}/{len(tables_to_load)} tables loaded successfully")
