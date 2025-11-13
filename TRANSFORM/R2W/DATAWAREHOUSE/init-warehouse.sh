#!/bin/bash
# ============================================================
# Initialize Football Data Warehouse
# This script creates the data warehouse schema in PostgreSQL
# ============================================================

# Database configuration
export PGHOST=${DB_HOST:-localhost}
export PGPORT=${DB_PORT:-5432}
export PGDATABASE=${DB_NAME:-football_data_sa}
export PGUSER=${DB_USER:-football_admin}
export PGPASSWORD=${DB_PASSWORD:-football_pass_2025}

echo "============================================================"
echo "Football Data Warehouse - Initialization"
echo "============================================================"
echo "Host: $PGHOST"
echo "Port: $PGPORT"
echo "Database: $PGDATABASE"
echo "User: $PGUSER"
echo "============================================================"
echo ""

# Function to execute SQL file
execute_sql() {
    local file=$1
    echo "Executing: $file"
    psql -f "$file"
    if [ $? -eq 0 ]; then
        echo "✓ Success: $file"
    else
        echo "✗ Error executing: $file"
        exit 1
    fi
    echo ""
}

# Check if running in container or local
if [ -f "/.dockerenv" ]; then
    echo "Running inside Docker container"
    SQL_DIR="/docker-entrypoint-initdb.d/DATAWAREHOUSE"
else
    echo "Running locally"
    SQL_DIR="$(dirname "$0")"
fi

# Execute SQL files in order
echo "Step 1: Creating dimension tables..."
execute_sql "$SQL_DIR/01-create-dimensions.sql"

echo "Step 2: Creating fact tables..."
execute_sql "$SQL_DIR/02-create-facts.sql"

echo "Step 3: Creating helper functions..."
execute_sql "$SQL_DIR/03-helper-functions.sql"

echo "Step 4: Populating date dimension (2010-2030)..."
psql -c "CALL dw.populate_date_dimension('2010-01-01'::DATE, '2030-12-31'::DATE);"

echo ""
echo "============================================================"
echo "Data Warehouse Initialization Complete!"
echo "============================================================"
echo ""
echo "Available schemas:"
psql -c "\dn"
echo ""
echo "Tables in dw schema:"
psql -c "\dt dw.*"
echo ""
echo "============================================================"
