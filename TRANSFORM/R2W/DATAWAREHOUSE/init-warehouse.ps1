# ============================================================
# Initialize Football Data Warehouse (PowerShell)
# This script creates the data warehouse schema in PostgreSQL
# ============================================================

# Database configuration
$DB_HOST = if ($env:DB_HOST) { $env:DB_HOST } else { "localhost" }
$DB_PORT = if ($env:DB_PORT) { $env:DB_PORT } else { "5432" }
$DB_NAME = if ($env:DB_NAME) { $env:DB_NAME } else { "football_data_sa" }
$DB_USER = if ($env:DB_USER) { $env:DB_USER } else { "football_admin" }
$DB_PASSWORD = if ($env:DB_PASSWORD) { $env:DB_PASSWORD } else { "football_pass_2025" }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Football Data Warehouse - Initialization" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Host: $DB_HOST"
Write-Host "Port: $DB_PORT"
Write-Host "Database: $DB_NAME"
Write-Host "User: $DB_USER"
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Function to execute SQL file via Docker
function Execute-SqlFile {
    param (
        [string]$FileName,
        [string]$Description
    )
    
    Write-Host "Executing: $Description" -ForegroundColor Yellow
    
    # Copy file to container
    $localPath = Join-Path $PSScriptRoot $FileName
    docker cp $localPath "football_data_postgres:/tmp/$FileName"
    
    # Execute the SQL file
    $result = docker exec football_data_postgres psql -U $DB_USER -d $DB_NAME -f "/tmp/$FileName" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Success: $Description" -ForegroundColor Green
    } else {
        Write-Host "Error executing: $Description" -ForegroundColor Red
        Write-Host $result
        exit 1
    }
    Write-Host ""
}

# Execute SQL files in order
Write-Host "Step 1: Creating dimension tables..." -ForegroundColor Cyan
Execute-SqlFile "01-create-dimensions.sql" "Dimension Tables"

Write-Host "Step 2: Creating fact tables..." -ForegroundColor Cyan
Execute-SqlFile "02-create-facts.sql" "Fact Tables"

Write-Host "Step 3: Creating helper functions..." -ForegroundColor Cyan
Execute-SqlFile "03-helper-functions.sql" "Helper Functions"

Write-Host "Step 4: Populating date dimension (2010-2030)..." -ForegroundColor Cyan
$dateCmd = "CALL dw.populate_date_dimension('2010-01-01'::DATE, '2030-12-31'::DATE);"
docker exec football_data_postgres psql -U $DB_USER -d $DB_NAME -c $dateCmd

Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Data Warehouse Initialization Complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Available schemas:" -ForegroundColor Cyan
docker exec football_data_postgres psql -U $DB_USER -d $DB_NAME -c "\dn"

Write-Host ""
Write-Host "Tables in dw schema:" -ForegroundColor Cyan
docker exec football_data_postgres psql -U $DB_USER -d $DB_NAME -c "\dt dw.*"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
