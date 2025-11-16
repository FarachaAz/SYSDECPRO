# ETL – Runbook Technique (Football Data Warehouse)=====================================================================

ETL – Runbook TECHNIQUE (Football Data Warehouse)

> **Dernière mise à jour** : 16 novembre 2025  Dernière mise à jour : 2025-11-16

> **Auteur** : FarachaAz / SYSDECPROAuteur : FarachaAz / SYSDECPRO

=====================================================================

---

But de ce document (focus technique)

## 📘 But de ce document (focus technique)------------------------------------

Décrire exactement COMMENT les chargements ont été réalisés (scripts, commandes, SQL, ordre d’exécution, règles de mapping, relance/récupération), sans refaire la présentation du projet.

Décrire **exactement COMMENT** les chargements ont été réalisés :

- 🔧 Scripts, commandes, SQL0) Pré-requis exécutés

- 📋 Ordre d'exécution----------------------

- 🗺️ Règles de mapping• Variables d’env: TRANSFORM/DATABASE/.env

- 🔄 Relance/récupération  DB_HOST=localhost | DB_PORT=5432 | DB_NAME=football_data_sa | DB_USER=football_admin | DB_PASSWORD=football_pass_2025

• Conteneur PostgreSQL lancé via docker-compose (TRANSFORM/DATABASE/docker-compose.yml)

---• Libs Python installées (pandas, psycopg2-binary, sqlalchemy, tqdm, tabulate, python-dotenv)



## 🎯 0. Pré-requis exécutés1) EXTRACT – Chargement CSV → Staging (relationnel)

---------------------------------------------------

### Variables d'environnement1.1 Création du schéma de staging

Fichier : `TRANSFORM/DATABASE/.env`    - Script SQL: TRANSFORM/DATABASE/init-db/01-create-schema.sql

    - Exécuté au démarrage docker-compose (healthcheck + init SQL)

```env

DB_HOST=localhost1.2 Ingestion des 11 CSV

DB_PORT=5432    - Script Python: TRANSFORM/DATABASE/load_data.py

DB_NAME=football_data_sa    - Action: lecture CSV (Data/…/) → insertion bulk dans tables staging

DB_USER=football_admin    - Volume: ~2,36 M lignes (toutes tables confondues)

DB_PASSWORD=football_pass_2025

```2) TRANSFORM – Initialisation DW (DDL & fonctions)

--------------------------------------------------

### Infrastructure2.1 Création des objets DW

- ✅ Conteneur PostgreSQL lancé via `docker-compose` (`TRANSFORM/DATABASE/docker-compose.yml`)    - Script PowerShell: TRANSFORM/R2W/DATAWAREHOUSE/init-warehouse.ps1

- ✅ Libs Python installées : `pandas`, `psycopg2-binary`, `sqlalchemy`, `tqdm`, `tabulate`, `python-dotenv`      • Exécute:

        - 01-create-dimensions.sql (création 8 dimensions)

---        - 02-create-facts.sql      (création 7 faits)

        - 03-helper-functions.sql  (fonctions dw.get_date_sk(), etc.)

## 📥 1. EXTRACT – Chargement CSV → Staging (relationnel)

2.2 Points techniques clés

### 1.1 Création du schéma de staging    - dw.get_date_sk(date DATE) crée/retourne date_sk (dim_date) à la volée

    - Contrainte d’unicité et index sur colonnes FK et NK clés

| Élément | Détail |

|---------|--------|3) TRANSFORM/LOAD – Dimensions (R2W/load_dimensions.py)

| **Script SQL** | `TRANSFORM/DATABASE/init-db/01-create-schema.sql` |-------------------------------------------------------

| **Exécution** | Au démarrage docker-compose (healthcheck + init SQL) |Ordre exécuté et opérations réalisées:



### 1.2 Ingestion des 11 CSV3.1 dim_agent

    - Source: player_profiles

| Élément | Détail |    - SQL (logique): SELECT DISTINCT player_agent_id, player_agent_name WHERE player_agent_id IS NOT NULL

|---------|--------|    - Chargement: INSERT … ON CONFLICT (agent_id) DO UPDATE agent_name

| **Script Python** | `TRANSFORM/DATABASE/load_data.py` |

| **Action** | Lecture CSV (`Data/…/`) → insertion bulk dans tables staging |3.2 dim_team

| **Volume** | **~2,36 M lignes** (toutes tables confondues) |    - Source: team_details

    - Mappings: team_nk = CAST(club_id AS VARCHAR), team_name = club_name, country_name, primary_competition_id = competition_name, division_level = REGEXP club_division

---    - Chargement: INSERT … ON CONFLICT (team_nk) DO UPDATE (name, country, competition, level)



## 🔄 2. TRANSFORM – Initialisation DW (DDL & fonctions)3.3 dim_competition

    - Source: team_details

### 2.1 Création des objets DW    - Mappings: competition_id = LOWER(REPLACE(competition_name,' ', '_'))

    - Chargement: INSERT … ON CONFLICT (competition_id) DO UPDATE (name, country, tier)

**Script PowerShell** : `TRANSFORM/R2W/DATAWAREHOUSE/init-warehouse.ps1`

3.4 dim_season

Exécute dans l'ordre :    - Source: player_performances (distinct season_name)

1. `01-create-dimensions.sql` → Création de 8 dimensions    - Parsing: ‘YY/YY’ → début = 19YY/20YY selon seuil 50, fin = début+1 ; ‘YYYY’ → fin = YYYY+1

2. `02-create-facts.sql` → Création de 7 faits    - Chargement: INSERT … ON CONFLICT (season_name) DO UPDATE (start_year, end_year, is_current)

3. `03-helper-functions.sql` → Fonctions utilitaires (`dw.get_date_sk()`, etc.)

3.5 dim_injury_type

### 2.2 Points techniques clés    - Source: player_injuries (DISTINCT injury_reason)

    - Catégorisation: Muscular / Bone-Ligament / Joint / Other

- 🔑 `dw.get_date_sk(date DATE)` : Crée/retourne `date_sk` (`dim_date`) à la volée    - Chargement: INSERT si combinaison (category,severity) absente

- 🔒 Contraintes d'unicité et index sur colonnes FK et NK clés

3.6 dim_player (SCD Type 2)

---    - Source: player_profiles + LEFT JOIN dim_agent

    - Hash SCD2: MD5(player_name, position, current_club_id, contract_expires, agent_sk)

## 🗂️ 3. TRANSFORM/LOAD – Dimensions    - Insert courant: (is_current=TRUE, valid_from=NOW(), valid_to=NULL, source_row_hash)

    - Conversions: current_club_id → VARCHAR, agent_sk nullable

**Script** : `R2W/load_dimensions.py`

4) LOAD – Faits (R2W/load_facts.py)

### Ordre d'exécution et opérations-----------------------------------

Notes d’implémentation:

#### 3.1 `dim_agent`• Méthode: INSERT … SELECT SQL (bulk); conversion dates via dw.get_date_sk()

• Joins sur dimensions via NK → SK (ex: player_id → dim_player.player_sk)

| Élément | Détail |• Casts explicites: club_id::varchar pour joindre dim_team.team_nk

|---------|--------|

| **Source** | `player_profiles` |Ordre exécuté:

| **Logique SQL** | `SELECT DISTINCT player_agent_id, player_agent_name WHERE player_agent_id IS NOT NULL` |4.1 fact_player_performance

| **Chargement** | `INSERT … ON CONFLICT (agent_id) DO UPDATE agent_name` |    - Joins: dim_player (player_id), dim_team (club_id::varchar), dim_competition (competition_name), dim_season (season_name)

    - Règles: red_cards = second_yellow_cards + direct_red_cards ; match_date_sk = dw.get_date_sk(date)

#### 3.2 `dim_team`

4.2 fact_market_value

| Élément | Détail |    - Joins: dim_player, dim_team

|---------|--------|    - Règles: valuation_date_sk = dw.get_date_sk(TO_TIMESTAMP(date_unix)::date); market_value = value

| **Source** | `team_details` |

| **Mappings** | `team_nk = CAST(club_id AS VARCHAR)`<br>`team_name = club_name`<br>`country_name`<br>`primary_competition_id = competition_name`<br>`division_level = REGEXP club_division` |4.3 fact_transfer

| **Chargement** | `INSERT … ON CONFLICT (team_nk) DO UPDATE` |    - Joins: dim_player, dim_team (from/to), dim_season, dim_transfer_type

    - Règles: transfer_date_sk = dw.get_date_sk(transfer_date); market_value_at_transfer = value_at_transfer

#### 3.3 `dim_competition`

4.4 fact_injury

| Élément | Détail |    - Joins: dim_player, dim_team, dim_season, dim_injury_type

|---------|--------|    - Règles: from_date/end_date → injury_from_date_sk / injury_end_date_sk (CASE WHEN … THEN get_date_sk … ELSE NULL)

| **Source** | `team_details` |

| **Mappings** | `competition_id = LOWER(REPLACE(competition_name,' ', '_'))` |4.5 fact_national_performance

| **Chargement** | `INSERT … ON CONFLICT (competition_id) DO UPDATE` |    - Joins: dim_player

    - Règles: national_team_name = team_name ; debut_date_sk = get_date_sk(first_game_date) ; caps = matches

#### 3.4 `dim_season`

4.6 fact_teammate_relationship

| Élément | Détail |    - Joins: dim_player (dp1 sur player_id, dp2 sur played_with_id)

|---------|--------|    - Règles: minutes_played_together = minutes_played_with ; joint_goal_participation conservée

| **Source** | `player_performances` (distinct `season_name`) |

| **Parsing** | `'YY/YY'` → début = 19YY/20YY selon seuil 50, fin = début+1<br>`'YYYY'` → fin = YYYY+1 |4.7 fact_player_season_summary (AGRÉGAT)

| **Chargement** | `INSERT … ON CONFLICT (season_name) DO UPDATE` |    - Source: dw.fact_player_performance (agrégations) + sous-requêtes sur dw.fact_injury

    - SQL (logique):

#### 3.5 `dim_injury_type`      INSERT INTO dw.fact_player_season_summary (

        player_sk, season_sk, total_matches, total_goals, total_assists,

| Élément | Détail |        total_minutes, total_yellow_cards, total_red_cards,

|---------|--------|        avg_goals_per_match, avg_assists_per_match,

| **Source** | `player_injuries` (`DISTINCT injury_reason`) |        total_injury_days, total_games_missed, load_datetime)

| **Catégorisation** | Muscular / Bone-Ligament / Joint / Other |      SELECT fp.player_sk, fp.season_sk,

| **Chargement** | `INSERT` si combinaison `(category, severity)` absente |             COUNT(DISTINCT fp.performance_sk),

             SUM(fp.goals), SUM(fp.assists), SUM(fp.minutes_played),

#### 3.6 `dim_player` (SCD Type 2)             SUM(fp.yellow_cards),

             SUM(fp.second_yellow_cards + fp.direct_red_cards),

| Élément | Détail |             AVG(fp.goals), AVG(fp.assists::numeric),

|---------|--------|             COALESCE((SELECT SUM(fi.days_missed) FROM dw.fact_injury fi WHERE fi.player_sk=fp.player_sk AND fi.season_sk=fp.season_sk),0),

| **Source** | `player_profiles` + `LEFT JOIN dim_agent` |             COALESCE((SELECT SUM(fi.games_missed) FROM dw.fact_injury fi WHERE fi.player_sk=fp.player_sk AND fi.season_sk=fp.season_sk),0),

| **Hash SCD2** | `MD5(player_name, position, current_club_id, contract_expires, agent_sk)` |             CURRENT_TIMESTAMP

| **Insert courant** | `is_current=TRUE`, `valid_from=NOW()`, `valid_to=NULL`, `source_row_hash` |      FROM dw.fact_player_performance fp

| **Conversions** | `current_club_id` → VARCHAR, `agent_sk` nullable |      GROUP BY fp.player_sk, fp.season_sk;



---5) ORCHESTRATION – Exécution contrôlée

--------------------------------------

## 📊 4. LOAD – FaitsOption A (pipeline complet):

  PowerShell (dossier TRANSFORM/R2W/):

**Script** : `R2W/load_facts.py`    python run_etl.py



### Notes d'implémentationOption B (pas-à-pas):

  1) python load_dimensions.py

- ✅ Méthode : `INSERT … SELECT` SQL (bulk)  2) python load_facts.py

- ✅ Conversion dates via `dw.get_date_sk()`  3) python verify_warehouse.py

- ✅ Joins sur dimensions via NK → SK

- ✅ Casts explicites : `club_id::varchar` pour joindre `dim_team.team_nk`Comportement d’idempotence:

  - Dimensions: UPSERT (ON CONFLICT) / mise à jour des champs clés

### Ordre d'exécution  - Faits: chargement bulk; relance possible après TRUNCATE ciblé si nécessaire



#### 4.1 `fact_player_performance`6) RELANCE / RÉCUPÉRATION (patterns)

------------------------------------

```sql• Vider et recharger une table de faits:

-- Joins: dim_player (player_id), dim_team (club_id::varchar),   - TRUNCATE TABLE dw.fact_player_performance RESTART IDENTITY CASCADE;

--        dim_competition (competition_name), dim_season (season_name)  - Relancer load_facts.py (ou l’étape concernée)

-- Règles: red_cards = second_yellow_cards + direct_red_cards

--         match_date_sk = dw.get_date_sk(date)• Rejouer les DDL DW (si drift):

```  - Exécuter à nouveau: DATAWAREHOUSE/init-warehouse.ps1



#### 4.2 `fact_market_value`• Full reload contrôlé:

  - Dimensions → Faits → Vérification (dans cet ordre)

```sql

-- Joins: dim_player, dim_team7) CONTRÔLES – Ce qui est vérifié (verify_warehouse.py)

-- Règles: valuation_date_sk = dw.get_date_sk(TO_TIMESTAMP(date_unix)::date)--------------------------------------------------------

--         market_value = value• Comptages par table (8 dims, 7 faits) et total

```• Échantillons et tests de jointure SK/FK

• Présence des index/contraintes

#### 4.3 `fact_transfer`• Valeurs NULL attendues/acceptées selon table



```sql8) DÉCISIONS TECHNIQUES CLÉS

-- Joins: dim_player, dim_team (from/to), dim_season, dim_transfer_type----------------------------

-- Règles: transfer_date_sk = dw.get_date_sk(transfer_date)• INSERT … SELECT SQL pour les gros volumes (bien plus rapide que boucles Python)

--         market_value_at_transfer = value_at_transfer• Conversion explicite des types pour joins (club_id::varchar)

```• Gestion NULL des dates lors d’appels à get_date_sk()

• SCD Type 2 sur dim_player avec hash pour détection de changement

#### 4.4 `fact_injury`

9) DÉPANNAGE (erreurs fréquentes et résolutions)

```sql------------------------------------------------

-- Joins: dim_player, dim_team, dim_season, dim_injury_type• « schema/colonne introuvable » → Vérifier schémas réels, adapter mapping

-- Règles: injury_from_date_sk = CASE WHEN ... THEN get_date_sk(...) ELSE NULL• « date null » avec get_date_sk → Encadrer par CASE WHEN … THEN … ELSE NULL

--         injury_end_date_sk = CASE WHEN ... THEN get_date_sk(...) ELSE NULL• Performances faibles → Préférer INSERT … SELECT, vérifier index FK

```• Unicode Windows → Affichage console uniquement; données correctes côté DB



#### 4.5 `fact_national_performance`10) COMMANDES RÉCAP (Windows PowerShell)

----------------------------------------

```sql• Lancer pipeline complet:            python TRANSFORM/R2W/run_etl.py

-- Joins: dim_player• Charger dimensions uniquement:      python TRANSFORM/R2W/load_dimensions.py

-- Règles: national_team_name = team_name• Charger faits uniquement:           python TRANSFORM/R2W/load_facts.py

--         debut_date_sk = get_date_sk(first_game_date)• Vérifier l’entrepôt:                python TRANSFORM/R2W/verify_warehouse.py

--         caps = matches• Réinitialiser une table de faits:   psql -c "TRUNCATE TABLE dw.<fact_table> RESTART IDENTITY CASCADE;"

```

=====================================================================

#### 4.6 `fact_teammate_relationship`FIN – Runbook technique ETL

=====================================================================

```sql
-- Joins: dim_player (dp1 sur player_id, dp2 sur played_with_id)
-- Règles: minutes_played_together = minutes_played_with
--         joint_goal_participation conservée
```

#### 4.7 `fact_player_season_summary` (AGRÉGAT)

**Source** : `dw.fact_player_performance` + sous-requêtes sur `dw.fact_injury`

```sql
INSERT INTO dw.fact_player_season_summary (
  player_sk, season_sk, total_matches, total_goals, total_assists,
  total_minutes, total_yellow_cards, total_red_cards,
  avg_goals_per_match, avg_assists_per_match,
  total_injury_days, total_games_missed, load_datetime
)
SELECT 
  fp.player_sk, fp.season_sk,
  COUNT(DISTINCT fp.performance_sk),
  SUM(fp.goals), SUM(fp.assists), SUM(fp.minutes_played),
  SUM(fp.yellow_cards),
  SUM(fp.second_yellow_cards + fp.direct_red_cards),
  AVG(fp.goals), AVG(fp.assists::numeric),
  COALESCE((SELECT SUM(fi.days_missed) 
            FROM dw.fact_injury fi 
            WHERE fi.player_sk=fp.player_sk AND fi.season_sk=fp.season_sk), 0),
  COALESCE((SELECT SUM(fi.games_missed) 
            FROM dw.fact_injury fi 
            WHERE fi.player_sk=fp.player_sk AND fi.season_sk=fp.season_sk), 0),
  CURRENT_TIMESTAMP
FROM dw.fact_player_performance fp
GROUP BY fp.player_sk, fp.season_sk;
```

---

## 🎼 5. ORCHESTRATION – Exécution contrôlée

### Option A : Pipeline complet

```powershell
# Dossier: TRANSFORM/R2W/
python run_etl.py
```

### Option B : Pas-à-pas

```powershell
# 1. Charger les dimensions
python load_dimensions.py

# 2. Charger les faits
python load_facts.py

# 3. Vérifier l'entrepôt
python verify_warehouse.py
```

### Comportement d'idempotence

- **Dimensions** : UPSERT (`ON CONFLICT`) / mise à jour des champs clés
- **Faits** : Chargement bulk ; relance possible après `TRUNCATE` ciblé si nécessaire

---

## 🔄 6. RELANCE / RÉCUPÉRATION (patterns)

### Vider et recharger une table de faits

```sql
TRUNCATE TABLE dw.fact_player_performance RESTART IDENTITY CASCADE;
```

Puis relancer `load_facts.py` (ou l'étape concernée)

### Rejouer les DDL DW (si drift)

```powershell
# Exécuter à nouveau
DATAWAREHOUSE/init-warehouse.ps1
```

### Full reload contrôlé

1. **Dimensions** → `load_dimensions.py`
2. **Faits** → `load_facts.py`
3. **Vérification** → `verify_warehouse.py`

---

## ✅ 7. CONTRÔLES – Ce qui est vérifié

**Script** : `verify_warehouse.py`

- ✅ Comptages par table (8 dims, 7 faits) et total
- ✅ Échantillons et tests de jointure SK/FK
- ✅ Présence des index/contraintes
- ✅ Valeurs NULL attendues/acceptées selon table

---

## 🔑 8. DÉCISIONS TECHNIQUES CLÉS

| Décision | Justification |
|----------|---------------|
| `INSERT … SELECT` SQL | Bien plus rapide que boucles Python pour gros volumes |
| Conversion explicite des types | Nécessaire pour joins (`club_id::varchar`) |
| Gestion NULL des dates | Encadrement par `CASE WHEN … THEN … ELSE NULL` |
| SCD Type 2 avec hash | Détection automatique des changements sur `dim_player` |

---

## 🛠️ 9. DÉPANNAGE (erreurs fréquentes et résolutions)

| Erreur | Solution |
|--------|----------|
| « schema/colonne introuvable » | Vérifier schémas réels, adapter mapping |
| « date null » avec `get_date_sk` | Encadrer par `CASE WHEN … THEN … ELSE NULL` |
| Performances faibles | Préférer `INSERT … SELECT`, vérifier index FK |
| Unicode Windows | Affichage console uniquement ; données correctes côté DB |

---

## 💻 10. COMMANDES RÉCAP (Windows PowerShell)

```powershell
# Lancer pipeline complet
python TRANSFORM/R2W/run_etl.py

# Charger dimensions uniquement
python TRANSFORM/R2W/load_dimensions.py

# Charger faits uniquement
python TRANSFORM/R2W/load_facts.py

# Vérifier l'entrepôt
python TRANSFORM/R2W/verify_warehouse.py

# Réinitialiser une table de faits
psql -c "TRUNCATE TABLE dw.<fact_table> RESTART IDENTITY CASCADE;"
```

---

## 📊 Résumé du flux de données

```
┌─────────────┐
│   CSV Files │ (11 fichiers, ~2.36M lignes)
└──────┬──────┘
       │ load_data.py
       ▼
┌─────────────┐
│   Staging   │ (PostgreSQL - schéma staging)
└──────┬──────┘
       │ load_dimensions.py
       ▼
┌─────────────┐
│ Dimensions  │ (8 tables - schéma dw)
└──────┬──────┘
       │ load_facts.py
       ▼
┌─────────────┐
│    Faits    │ (7 tables - schéma dw)
└──────┬──────┘
       │ verify_warehouse.py
       ▼
┌─────────────┐
│  Validation │ ✓
└─────────────┘
```

---

## 📚 Ressources

- [Conception DW](./DATAWAREHOUSE_DESIGN.md)
- [Scripts Database](./DATABASE/)
- [Scripts R2W](./R2W/)

---

*Fin – Runbook technique ETL*
