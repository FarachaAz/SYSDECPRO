# Automatisation ETL - Guide d'Utilisation

## 🎯 Objectif
Script d'automatisation complète du chargement ETL post-transformations avec:
- Gestion d'erreurs avancée
- Logs détaillés
- Retry automatique
- Checkpoints
- Validation qualité
- Snapshots avant chargement

## 🚀 Utilisation

### Exécution simple (recommandée)
```powershell
cd TRANSFORM/R2W
python autoload_etl.py
```

### Avec environnement virtuel
```powershell
cd TRANSFORM/R2W
.venv\Scripts\Activate.ps1
python autoload_etl.py
```

## 📋 Ce que fait le script

### Phase 0: Vérifications pré-chargement
- ✅ Test connexion PostgreSQL
- 💾 Snapshot des comptages actuels (pour rollback)

### Phase 1: Chargement Dimensions
- Exécute `load_dimensions.py`
- Charge 8 dimensions (Agent, Team, Competition, Season, Injury Type, Transfer Type, Player, Date)
- Retry automatique en cas d'échec (max 3 tentatives)

### Phase 2: Chargement Faits
- Exécute `load_facts.py`
- Charge 7 tables de faits (Performance, Market Value, Transfer, Injury, National Performance, Teammate Relationship, Player Season Summary)
- Retry automatique

### Phase 3: Validation Qualité
- Vérification comptages non-nuls
- Test intégrité référentielle (FK valides)
- Détection enregistrements orphelins

### Phase 4: Vérification Finale
- Exécute `verify_warehouse.py`
- Rapport complet sur toutes les tables

## 📊 Logs & Outputs

### Logs détaillés
- Fichier: `logs/etl_auto_YYYYMMDD_HHMMSS.log`
- Console + fichier simultanément
- Timestamps sur toutes les opérations

### Checkpoint
- Fichier: `etl_checkpoint.json`
- Sauvegarde progression à chaque étape
- Permet reprise en cas d'interruption

### Snapshot
- Fichier: `logs/snapshot_YYYYMMDD_HHMMSS.json`
- Comptages tables avant chargement
- Utilisable pour rollback manuel

## ⚙️ Configuration

Éditez les variables dans `autoload_etl.py`:

```python
ETL_CONFIG = {
    'max_retries': 3,              # Nombre de tentatives par script
    'retry_delay': 5,              # Délai entre tentatives (sec)
    'enable_rollback': True,       # Créer snapshot avant chargement
    'enable_notifications': False, # Notifications email/Slack (TODO)
    'parallel_load': False,        # Chargement parallèle (future)
    'checkpoint_file': 'etl_checkpoint.json'
}
```

## 🔄 Reprise après échec

Si le script échoue à une étape:

1. **Vérifier les logs**
   ```powershell
   Get-Content logs\etl_auto_YYYYMMDD_HHMMSS.log -Tail 50
   ```

2. **Consulter checkpoint**
   ```powershell
   Get-Content etl_checkpoint.json
   ```

3. **Corriger le problème** (connexion DB, données, etc.)

4. **Relancer le script**
   ```powershell
   python autoload_etl.py
   ```

## 📈 Exemple de sortie

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    AUTOMATISATION ETL POST-TRANSFORMATIONS                   ║
╚══════════════════════════════════════════════════════════════════════════════╝

⏰ Début: 2025-11-18 14:30:00

================================================================================
PHASE 0: VÉRIFICATIONS PRÉ-CHARGEMENT
================================================================================
🔍 Vérification de la connexion à la base de données...
✅ Connexion établie: PostgreSQL 15.3
💾 Création du snapshot de sauvegarde...
✅ Snapshot sauvegardé: logs/snapshot_20251118_143000.json

================================================================================
PHASE 1: CHARGEMENT DES DIMENSIONS (8 tables)
================================================================================
▶️  EXÉCUTION: Dimensions (Agent, Team, Competition, Season, Injury, Player)
📄 Script: load_dimensions.py
...
✅ Dimensions (Agent, Team, Competition, Season, Injury, Player) - SUCCÈS

================================================================================
PHASE 2: CHARGEMENT DES FAITS (7 tables)
================================================================================
▶️  EXÉCUTION: Faits (Performance, Market Value, Transfer, Injury, etc.)
📄 Script: load_facts.py
...
✅ Faits (Performance, Market Value, Transfer, Injury, etc.) - SUCCÈS

================================================================================
PHASE 3: VALIDATION QUALITÉ
================================================================================
🔍 Validation de la qualité des données...
  ✅ dim_player: 40,547 lignes
  ✅ fact_player_performance: 139,444 lignes
  ✅ fact_market_value: 425,302 lignes
  ✅ Intégrité référentielle: OK

================================================================================
PHASE 4: VÉRIFICATION FINALE
================================================================================
▶️  EXÉCUTION: Vérification complète du Data Warehouse
📄 Script: verify_warehouse.py
...
✅ Vérification complète du Data Warehouse - SUCCÈS

================================================================================
RÉSUMÉ DE L'EXÉCUTION ETL
================================================================================
  ✅ Dimensions                      SUCCÈS
  ✅ Faits                           SUCCÈS
  ✅ Validation Qualité              SUCCÈS
  ✅ Vérification                    SUCCÈS

⏱️  Durée totale: 0:08:32
📅 Fin: 2025-11-18 14:38:32
📄 Log détaillé: logs/etl_auto_20251118_143000.log

📊 VOLUMÉTRIE FINALE:
  dim_agent                          :        3,397 lignes
  dim_competition                    :          107 lignes
  dim_date                           :        9,085 lignes
  dim_injury_type                    :            4 lignes
  dim_player                         :       40,547 lignes
  dim_season                         :           56 lignes
  dim_team                           :        1,304 lignes
  dim_transfer_type                  :            6 lignes
  fact_injury                        :       77,543 lignes
  fact_market_value                  :      425,302 lignes
  fact_national_performance          :       62,144 lignes
  fact_player_performance            :      139,444 lignes
  fact_player_season_summary         :      126,869 lignes
  fact_teammate_relationship         :      437,371 lignes
  fact_transfer                      :      277,676 lignes

================================================================================
🎉 ETL AUTOMATISÉ COMPLÉTÉ AVEC SUCCÈS!
================================================================================
```

## 🛠️ Dépannage

### Erreur: "Connexion DB impossible"
```powershell
# Vérifier Docker
docker ps | findstr football_data_postgres

# Redémarrer conteneur si nécessaire
cd TRANSFORM/DATABASE
docker-compose up -d
```

### Erreur: "Module not found"
```powershell
# Installer dépendances
pip install psycopg2-binary pandas python-dotenv tqdm tabulate
```

### Erreur: Fichier .env manquant
```powershell
# Vérifier présence
Test-Path TRANSFORM/DATABASE/.env

# Si absent, créer avec:
# DB_HOST=localhost
# DB_PORT=5432
# DB_NAME=football_data_sa
# DB_USER=football_admin
# DB_PASSWORD=football_pass_2025
```

## 📅 Planification automatique (Windows)

### Tâche planifiée quotidienne
```powershell
# Créer script batch: run_etl_scheduled.bat
@echo off
cd C:\Users\Fares\Videos\SYSDECPRO\TRANSFORM\R2W
C:\Users\Fares\AppData\Local\Programs\Python\Python311\python.exe autoload_etl.py
pause

# Créer tâche planifiée (Task Scheduler)
schtasks /create /tn "ETL_Football_Daily" /tr "C:\path\to\run_etl_scheduled.bat" /sc daily /st 02:00
```

## 🔮 Évolutions futures

- [ ] Notifications email/Slack en cas d'échec
- [ ] Chargement parallèle des faits indépendants
- [ ] Rollback automatique en cas d'échec critique
- [ ] Dashboard web temps réel
- [ ] Support chargements incrémentaux
- [ ] Métriques Prometheus/Grafana

## 📚 Fichiers générés

```
TRANSFORM/R2W/
├── autoload_etl.py           # Script principal
├── etl_checkpoint.json        # Checkpoint progression
└── logs/
    ├── etl_auto_*.log         # Logs détaillés par exécution
    └── snapshot_*.json        # Snapshots pré-chargement
```

## ✅ Checklist pré-exécution

- [ ] Docker PostgreSQL démarré
- [ ] Fichier .env présent et correct
- [ ] Python 3.11+ installé
- [ ] Librairies installées (requirements.txt)
- [ ] Données staging chargées (DATABASE/load_data.py exécuté)
- [ ] Schéma DW initialisé (DATAWAREHOUSE/init-warehouse.ps1 exécuté)

---

**Auteur:** FarachaAz / SYSDECPRO  
**Version:** 1.0.0  
**Date:** 2025-11-18
