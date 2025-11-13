"""
Master ETL Runner
Executes complete ETL process: Dimensions → Facts → Verification
"""

import subprocess
import sys
from datetime import datetime

def run_script(script_name, description):
    """Run a Python ETL script"""
    print("\n" + "=" * 70)
    print(f"RUNNING: {description}")
    print("=" * 70)
    
    try:
        result = subprocess.run(
            [sys.executable, script_name],
            cwd=".",
            capture_output=False,
            text=True
        )
        
        if result.returncode == 0:
            print(f"\n✅ {description} - COMPLETED SUCCESSFULLY")
            return True
        else:
            print(f"\n❌ {description} - FAILED (Exit Code: {result.returncode})")
            return False
    
    except Exception as e:
        print(f"\n❌ ERROR running {script_name}: {e}")
        return False


def main():
    """Run complete ETL process"""
    start_time = datetime.now()
    
    print("╔" + "=" * 68 + "╗")
    print("║" + " " * 15 + "FOOTBALL DATA WAREHOUSE ETL" + " " * 25 + "║")
    print("╚" + "=" * 68 + "╝")
    print(f"\nStart Time: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("\nETL Process:")
    print("  1. Load Dimension Tables (8 tables)")
    print("  2. Load Fact Tables (7 tables)")
    print("  3. Verify Data Warehouse")
    print()
    
    # ETL Pipeline
    steps = [
        ('load_dimensions.py', 'Load Dimension Tables'),
        ('load_facts.py', 'Load Fact Tables'),
        ('verify_warehouse.py', 'Verify Data Warehouse')
    ]
    
    results = []
    for script, description in steps:
        success = run_script(script, description)
        results.append((description, success))
        
        if not success:
            print(f"\n⚠️  ETL process stopped at: {description}")
            break
    
    # Summary
    end_time = datetime.now()
    duration = end_time - start_time
    
    print("\n\n" + "=" * 70)
    print("ETL PROCESS SUMMARY")
    print("=" * 70)
    
    for description, success in results:
        status = "✅ SUCCESS" if success else "❌ FAILED"
        print(f"  {description:40s} {status}")
    
    print(f"\nDuration: {duration}")
    print(f"End Time: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 70)
    
    if all(success for _, success in results):
        print("\n🎉 ETL PROCESS COMPLETED SUCCESSFULLY!")
        return 0
    else:
        print("\n❌ ETL PROCESS FAILED - Check errors above")
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)
