import subprocess
import sys
import os
import json
import logging
from datetime import datetime
from pathlib import Path
import psycopg2
from dotenv import load_dotenv

# Chargement variables d'environnement
load_dotenv('../DATABASE/.env')

# Configuration logging
LOG_DIR = Path('logs')
LOG_DIR.mkdir(exist_ok=True)
LOG_FILE = LOG_DIR / f'etl_auto_{datetime.now().strftime("%Y%m%d_%H%M%S")}.log'

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE, encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

# Configuration DB
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'port': os.getenv('DB_PORT', '5432'),
    'database': os.getenv('DB_NAME', 'football_data_sa'),
    'user': os.getenv('DB_USER', 'football_admin'),
    'password': os.getenv('DB_PASSWORD', 'football_pass_2025')
}

# Configuration ETL
ETL_CONFIG = {
    'max_retries': 3,
    'retry_delay': 5,  # secondes
    'enable_rollback': True,
    'enable_notifications': False,
    'parallel_load': False,
    'checkpoint_file': 'etl_checkpoint.json'
}


class ETLAutomation:
    """Classe principale pour l'automatisation ETL"""
    
    def __init__(self):
        self.start_time = None
        self.end_time = None
        self.checkpoint = self.load_checkpoint()
        self.results = []
        
    def load_checkpoint(self):
        """Charge le dernier checkpoint ETL"""
        checkpoint_path = Path(ETL_CONFIG['checkpoint_file'])
        if checkpoint_path.exists():
            with open(checkpoint_path, 'r', encoding='utf-8') as f:
                return json.load(f)
        return {}
    
    def save_checkpoint(self, step, status, details=None):
        """Sauvegarde un checkpoint ETL"""
        self.checkpoint[step] = {
            'status': status,
            'timestamp': datetime.now().isoformat(),
            'details': details or {}
        }
        with open(ETL_CONFIG['checkpoint_file'], 'w', encoding='utf-8') as f:
            json.dump(self.checkpoint, f, indent=2, ensure_ascii=False)
    
    def check_db_connection(self):
        """Vérifie la connexion à la base de données"""
        logger.info("🔍 Vérification de la connexion à la base de données...")
        try:
            conn = psycopg2.connect(**DB_CONFIG)
            cursor = conn.cursor()
            cursor.execute("SELECT version();")
            version = cursor.fetchone()[0]
            logger.info(f"✅ Connexion établie: {version}")
            cursor.close()
            conn.close()
            return True
        except Exception as e:
            logger.error(f"❌ Échec de connexion DB: {e}")
            return False
    
    def get_table_counts(self, schema='dw'):
        """Récupère les comptages actuels des tables DW"""
        logger.info(f"📊 Récupération des comptages tables (schéma: {schema})...")
        counts = {}
        try:
            conn = psycopg2.connect(**DB_CONFIG)
            cursor = conn.cursor()
            
            # Liste des tables
            cursor.execute(f"""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = '{schema}' 
                  AND table_type = 'BASE TABLE'
                ORDER BY table_name
            """)
            tables = [row[0] for row in cursor.fetchall()]
            
            # Comptages
            for table in tables:
                cursor.execute(f"SELECT COUNT(*) FROM {schema}.{table}")
                counts[table] = cursor.fetchone()[0]
            
            cursor.close()
            conn.close()
            logger.info(f"✅ Comptages récupérés: {len(counts)} tables")
            return counts
        except Exception as e:
            logger.error(f"❌ Erreur récupération comptages: {e}")
            return {}
    
    def create_backup_snapshot(self):
        """Crée un snapshot des comptages avant chargement"""
        logger.info("💾 Création du snapshot de sauvegarde...")
        snapshot = {
            'timestamp': datetime.now().isoformat(),
            'counts': self.get_table_counts()
        }
        
        snapshot_file = LOG_DIR / f'snapshot_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
        with open(snapshot_file, 'w', encoding='utf-8') as f:
            json.dump(snapshot, f, indent=2, ensure_ascii=False)
        
        logger.info(f"✅ Snapshot sauvegardé: {snapshot_file}")
        return snapshot
    
    def run_script(self, script_name, description, retries=0):
        """Exécute un script Python ETL avec gestion d'erreurs"""
        logger.info("=" * 80)
        logger.info(f"▶️  EXÉCUTION: {description}")
        logger.info(f"📄 Script: {script_name}")
        logger.info("=" * 80)
        
        attempt = 0
        max_attempts = ETL_CONFIG['max_retries'] if retries else 1
        
        while attempt < max_attempts:
            attempt += 1
            if attempt > 1:
                logger.warning(f"🔄 Tentative {attempt}/{max_attempts}")
                import time
                time.sleep(ETL_CONFIG['retry_delay'])
            
            try:
                result = subprocess.run(
                    [sys.executable, script_name],
                    cwd=Path(__file__).parent,
                    capture_output=True,
                    text=True,
                    encoding='utf-8'
                )
                
                # Log output
                if result.stdout:
                    logger.info(f"📝 Output:\n{result.stdout}")
                
                if result.returncode == 0:
                    logger.info(f"✅ {description} - SUCCÈS")
                    self.save_checkpoint(script_name, 'success', {
                        'attempt': attempt,
                        'description': description
                    })
                    return True, result.stdout
                else:
                    logger.error(f"❌ {description} - ÉCHEC (Code: {result.returncode})")
                    if result.stderr:
                        logger.error(f"Erreur: {result.stderr}")
                    
                    if attempt >= max_attempts:
                        self.save_checkpoint(script_name, 'failed', {
                            'error': result.stderr,
                            'returncode': result.returncode
                        })
                        return False, result.stderr
            
            except Exception as e:
                logger.error(f"❌ Exception lors de l'exécution: {e}")
                if attempt >= max_attempts:
                    self.save_checkpoint(script_name, 'error', {'exception': str(e)})
                    return False, str(e)
        
        return False, "Max retries reached"
    
    def validate_data_quality(self):
        """Valide la qualité des données chargées"""
        logger.info("🔍 Validation de la qualité des données...")
        
        checks = []
        try:
            conn = psycopg2.connect(**DB_CONFIG)
            cursor = conn.cursor()
            
            # Check 1: Comptages non-nuls
            cursor.execute("""
                SELECT 'dim_player' as table_name, COUNT(*) as cnt FROM dw.dim_player
                UNION ALL
                SELECT 'fact_player_performance', COUNT(*) FROM dw.fact_player_performance
                UNION ALL
                SELECT 'fact_market_value', COUNT(*) FROM dw.fact_market_value
            """)
            
            for table, count in cursor.fetchall():
                if count == 0:
                    checks.append(f"❌ {table}: 0 lignes (attendu > 0)")
                else:
                    checks.append(f"✅ {table}: {count:,} lignes")
            
            # Check 2: Intégrité référentielle (FK valides)
            cursor.execute("""
                SELECT COUNT(*) 
                FROM dw.fact_player_performance fp
                LEFT JOIN dw.dim_player dp ON fp.player_sk = dp.player_sk
                WHERE dp.player_sk IS NULL
            """)
            orphans = cursor.fetchone()[0]
            if orphans > 0:
                checks.append(f"⚠️  {orphans} enregistrements orphelins dans fact_player_performance")
            else:
                checks.append("✅ Intégrité référentielle: OK")
            
            cursor.close()
            conn.close()
            
            # Log résultats
            for check in checks:
                logger.info(f"  {check}")
            
            return all('✅' in check for check in checks)
        
        except Exception as e:
            logger.error(f"❌ Erreur validation qualité: {e}")
            return False
    
    def send_notification(self, status, details):
        """Envoie une notification (email, Slack, etc.)"""
        if not ETL_CONFIG['enable_notifications']:
            return
        
        logger.info(f"📧 Envoi notification: {status}")
        # TODO: Implémenter l'envoi d'email/Slack/Teams
        # Exemple: send_email(subject=f"ETL {status}", body=details)
    
    def run_full_pipeline(self):
        """Exécute le pipeline ETL complet"""
        self.start_time = datetime.now()
        
        logger.info("╔" + "=" * 78 + "╗")
        logger.info("║" + " " * 20 + "AUTOMATISATION ETL POST-TRANSFORMATIONS" + " " * 19 + "║")
        logger.info("╚" + "=" * 78 + "╝")
        logger.info(f"\n⏰ Début: {self.start_time.strftime('%Y-%m-%d %H:%M:%S')}")
        
        # Étape 0: Vérification pré-chargement
        logger.info("\n" + "=" * 80)
        logger.info("PHASE 0: VÉRIFICATIONS PRÉ-CHARGEMENT")
        logger.info("=" * 80)
        
        if not self.check_db_connection():
            logger.error("❌ Arrêt: connexion DB impossible")
            return False
        
        # Snapshot avant chargement
        if ETL_CONFIG['enable_rollback']:
            snapshot = self.create_backup_snapshot()
        
        # Étape 1: Chargement des dimensions
        logger.info("\n" + "=" * 80)
        logger.info("PHASE 1: CHARGEMENT DES DIMENSIONS (8 tables)")
        logger.info("=" * 80)
        
        success, output = self.run_script(
            'load_dimensions.py',
            'Dimensions (Agent, Team, Competition, Season, Injury, Player)',
            retries=ETL_CONFIG['max_retries']
        )
        self.results.append(('Dimensions', success))
        
        if not success:
            logger.error("❌ Échec chargement dimensions - Arrêt du pipeline")
            self.send_notification('FAILED', f"Échec phase Dimensions: {output}")
            return False
        
        # Étape 2: Chargement des faits
        logger.info("\n" + "=" * 80)
        logger.info("PHASE 2: CHARGEMENT DES FAITS (7 tables)")
        logger.info("=" * 80)
        
        success, output = self.run_script(
            'load_facts.py',
            'Faits (Performance, Market Value, Transfer, Injury, etc.)',
            retries=ETL_CONFIG['max_retries']
        )
        self.results.append(('Faits', success))
        
        if not success:
            logger.error("❌ Échec chargement faits - Arrêt du pipeline")
            self.send_notification('FAILED', f"Échec phase Faits: {output}")
            return False
        
        # Étape 3: Validation de la qualité
        logger.info("\n" + "=" * 80)
        logger.info("PHASE 3: VALIDATION QUALITÉ")
        logger.info("=" * 80)
        
        quality_ok = self.validate_data_quality()
        self.results.append(('Validation Qualité', quality_ok))
        
        if not quality_ok:
            logger.warning("⚠️  Problèmes de qualité détectés")
        
        # Étape 4: Vérification finale
        logger.info("\n" + "=" * 80)
        logger.info("PHASE 4: VÉRIFICATION FINALE")
        logger.info("=" * 80)
        
        success, output = self.run_script(
            'verify_warehouse.py',
            'Vérification complète du Data Warehouse',
            retries=False
        )
        self.results.append(('Vérification', success))
        
        # Résumé final
        self.end_time = datetime.now()
        duration = self.end_time - self.start_time
        
        logger.info("\n\n" + "=" * 80)
        logger.info("RÉSUMÉ DE L'EXÉCUTION ETL")
        logger.info("=" * 80)
        
        for phase, status in self.results:
            icon = "✅" if status else "❌"
            logger.info(f"  {icon} {phase:30s} {'SUCCÈS' if status else 'ÉCHEC'}")
        
        logger.info(f"\n⏱️  Durée totale: {duration}")
        logger.info(f"📅 Fin: {self.end_time.strftime('%Y-%m-%d %H:%M:%S')}")
        logger.info(f"📄 Log détaillé: {LOG_FILE}")
        
        # Comptages finaux
        final_counts = self.get_table_counts()
        logger.info("\n📊 VOLUMÉTRIE FINALE:")
        for table, count in sorted(final_counts.items()):
            logger.info(f"  {table:35s}: {count:>12,} lignes")
        
        # Statut global
        all_success = all(status for _, status in self.results)
        
        if all_success:
            logger.info("\n" + "=" * 80)
            logger.info("🎉 ETL AUTOMATISÉ COMPLÉTÉ AVEC SUCCÈS!")
            logger.info("=" * 80)
            self.send_notification('SUCCESS', f"ETL complété en {duration}")
            return True
        else:
            logger.error("\n" + "=" * 80)
            logger.error("❌ ETL AUTOMATISÉ TERMINÉ AVEC ERREURS")
            logger.error("=" * 80)
            self.send_notification('PARTIAL', f"ETL terminé avec erreurs (durée: {duration})")
            return False


def main():
    """Point d'entrée principal"""
    try:
        etl = ETLAutomation()
        success = etl.run_full_pipeline()
        sys.exit(0 if success else 1)
    
    except KeyboardInterrupt:
        logger.warning("\n⚠️  Interruption utilisateur - Arrêt ETL")
        sys.exit(2)
    
    except Exception as e:
        logger.error(f"\n❌ Erreur critique: {e}", exc_info=True)
        sys.exit(3)


if __name__ == "__main__":
    main()
