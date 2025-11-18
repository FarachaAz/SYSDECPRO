@echo off
REM Script batch pour exécution planifiée de l'ETL automatisé
REM Auteur: FarachaAz / SYSDECPRO
REM Date: 2025-11-18

echo ========================================
echo   ETL Automatise - Execution planifiee
echo ========================================
echo.

REM Définir le chemin du projet
set PROJECT_PATH=C:\Users\Fares\Videos\SYSDECPRO\TRANSFORM\R2W
set PYTHON_EXE=C:\Users\Fares\AppData\Local\Programs\Python\Python311\python.exe

echo Repertoire: %PROJECT_PATH%
echo Python: %PYTHON_EXE%
echo.

REM Se déplacer dans le répertoire du projet
cd /d "%PROJECT_PATH%"

REM Vérifier que Docker est lancé
echo Verification Docker...
docker ps | findstr football_data_postgres >nul 2>&1
if errorlevel 1 (
    echo ERREUR: Conteneur PostgreSQL non demarre!
    echo Demarrage du conteneur...
    cd ..\DATABASE
    docker-compose up -d
    timeout /t 10
    cd ..\R2W
)

REM Exécuter le script ETL
echo.
echo Lancement ETL automatise...
echo.
"%PYTHON_EXE%" autoload_etl.py

REM Vérifier le code de sortie
if errorlevel 1 (
    echo.
    echo ========================================
    echo   ERREUR: ETL termine avec des erreurs
    echo ========================================
    echo.
    echo Consultez les logs dans: %PROJECT_PATH%\logs\
    pause
    exit /b 1
) else (
    echo.
    echo ========================================
    echo   SUCCES: ETL complete avec succes
    echo ========================================
    echo.
)

REM Afficher les dernières lignes du log
echo Dernieres lignes du log:
echo.
for /f "delims=" %%i in ('dir /b /od logs\etl_auto_*.log') do set LAST_LOG=%%i
if defined LAST_LOG (
    powershell -Command "Get-Content logs\%LAST_LOG% -Tail 20"
)

echo.
echo Script termine.
pause
