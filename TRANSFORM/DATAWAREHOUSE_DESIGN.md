# Conception du Data Warehouse – Football Data=====================================================================

Conception du Data Warehouse (DW) – Football Data

> **Dernière mise à jour** : 16 novembre 2025  Dernière mise à jour : 2025-11-16

> **Auteur** : FarachaAz / SYSDECPROAuteur : FarachaAz / SYSDECPRO

=====================================================================

---

1) Vision & Objectifs BI

## 📊 1. Vision & Objectifs BI------------------------

- Offrir une vue analytique consolidée sur les joueurs, leurs performances, valeurs de marché, blessures, transferts et relations.

Offrir une vue analytique consolidée sur :- Supporter des cas d’usage : top buteurs par saison, progression de valeur, impact des blessures, historique de transferts, synergies entre coéquipiers.

- Les **joueurs** et leurs performances

- Les **valeurs de marché** et leur évolution2) Principes de modélisation

- Les **blessures** et leur impact----------------------------

- L'**historique des transferts**- Schéma en étoile (star schema)

- Les **relations entre coéquipiers**- Grains clairs et stables pour les tables de faits

- Clés substitutives (surrogate keys, SK) en DW

### Cas d'usage supportés- Dimensions conformes (ex. joueur, saison, date)

- Top buteurs par saison/compétition- SCD Type 2 sur la dimension Joueur (historisation des attributs)

- Progression de valeur de marché- Dimension Date centralisée alimentée par get_date_sk()

- Impact des blessures sur les performances

- Analyse des flux de transferts3) Périmètre fonctionnel

- Synergies entre coéquipiers------------------------

- 8 dimensions : date, joueur, agent, équipe, compétition, saison, type de transfert, type de blessure.

---- 7 faits : performances, valeur de marché, transferts, blessures, perfs en sélection, relations coéquipiers, résumé joueur-saison.



## 🏗️ 2. Principes de modélisation4) Dimensions (détails)

-----------------------

- **Schéma en étoile** (star schema)4.1 dim_date

- **Grains clairs** et stables pour les tables de faits  - Rôle : calendrier de référence (jour)

- **Clés substitutives** (surrogate keys, SK) en DW  - SK : date_sk (int AAAAMMJJ)

- **Dimensions conformes** (joueur, saison, date)  - Attributs : full_date, année, mois, trimestre, jour_semaine, etc.

- **SCD Type 2** sur la dimension Joueur (historisation des attributs)  - Alimentation : fonction dw.get_date_sk(date) à la volée (crée si absent)

- **Dimension Date** centralisée alimentée par `get_date_sk()`

4.2 dim_player (SCD Type 2)

---  - Grain : joueur

  - NK : player_nk (player_id source)

## 🎯 3. Périmètre fonctionnel  - SK : player_sk (surrogate)

  - Attributs : player_name, position, date_of_birth, height_cm, foot, current_club_nk, country_of_birth, citizenship, contract_expires, agent_sk, is_current, valid_from/valid_to, source_row_hash

| Type | Nombre | Détails |  - Politique SCD2 : nouvelles lignes insérées si hash change (valid_to mis à jour sur anciennes)

|------|--------|---------|

| **Dimensions** | 8 | date, joueur, agent, équipe, compétition, saison, type de transfert, type de blessure |4.3 dim_agent

| **Faits** | 7 | performances, valeur de marché, transferts, blessures, perfs en sélection, relations coéquipiers, résumé joueur-saison |  - NK : agent_id

  - SK : agent_sk

---  - Attributs : agent_name



## 📐 4. Dimensions (détails)4.4 dim_team

  - NK : team_nk (club_id source cast en varchar)

### 4.1 `dim_date`  - SK : team_sk

- **Rôle** : Calendrier de référence (jour)  - Attributs : team_name, country_name, primary_competition_id, division_level

- **SK** : `date_sk` (int AAAAMMJJ)

- **Attributs** : `full_date`, année, mois, trimestre, jour_semaine, etc.4.5 dim_competition

- **Alimentation** : Fonction `dw.get_date_sk(date)` à la volée (crée si absent)  - NK : competition_id (dérivé du nom)

  - SK : competition_sk

### 4.2 `dim_player` (SCD Type 2)  - Attributs : competition_name, country_name, tier_level

- **Grain** : Joueur

- **NK** : `player_nk` (player_id source)4.6 dim_season

- **SK** : `player_sk` (surrogate)  - NK/SK : season_name / season_sk

- **Attributs** :  - Attributs : season_start_year, season_end_year, is_current_season

  - `player_name`, `position`, `date_of_birth`, `height_cm`, `foot`  - Parsing des formats : ‘24/25’, ‘99/00’, ‘2024’

  - `current_club_nk`, `country_of_birth`, `citizenship`

  - `contract_expires`, `agent_sk`4.7 dim_transfer_type

  - `is_current`, `valid_from`, `valid_to`, `source_row_hash`  - SK : transfer_type_sk

- **Politique SCD2** : Nouvelles lignes insérées si hash change (valid_to mis à jour sur anciennes)  - Attributs : transfer_type_name (ex: Loan, Permanent, Free…)



### 4.3 `dim_agent`4.8 dim_injury_type

- **NK** : `agent_id`  - SK : injury_type_sk

- **SK** : `agent_sk`  - Attributs : injury_category (Muscular, Joint, Bone/Ligament, Other), injury_severity

- **Attributs** : `agent_name`

5) Faits (grains, mesures, FK)

### 4.4 `dim_team`------------------------------

- **NK** : `team_nk` (club_id source cast en varchar)5.1 fact_player_performance

- **SK** : `team_sk`  - Grain : joueur – match – compétition – saison

- **Attributs** : `team_name`, `country_name`, `primary_competition_id`, `division_level`  - FK : player_sk, team_sk, competition_sk, season_sk, match_date_sk

  - Mesures : minutes_played, goals, assists, yellow_cards, second_yellow_cards, direct_red_cards

### 4.5 `dim_competition`  - Règles : red_cards = second_yellow_cards + direct_red_cards

- **NK** : `competition_id` (dérivé du nom)

- **SK** : `competition_sk`5.2 fact_market_value

- **Attributs** : `competition_name`, `country_name`, `tier_level`  - Grain : joueur – date d’évaluation

  - FK : player_sk, team_sk, valuation_date_sk

### 4.6 `dim_season`  - Mesures : market_value

- **NK/SK** : `season_name` / `season_sk`  - Mappings : date_unix → valuation_date_sk ; value → market_value

- **Attributs** : `season_start_year`, `season_end_year`, `is_current_season`

- **Parsing des formats** : '24/25', '99/00', '2024'5.3 fact_transfer

  - Grain : joueur – évènement de transfert

### 4.7 `dim_transfer_type`  - FK : player_sk, from_team_sk, to_team_sk, season_sk, transfer_date_sk, transfer_type_sk

- **SK** : `transfer_type_sk`  - Mesures : transfer_fee, market_value_at_transfer

- **Attributs** : `transfer_type_name` (ex: Loan, Permanent, Free…)

5.4 fact_injury

### 4.8 `dim_injury_type`  - Grain : joueur – évènement blessure

- **SK** : `injury_type_sk`  - FK : player_sk, team_sk, season_sk, injury_type_sk, injury_from_date_sk, injury_end_date_sk

- **Attributs** : `injury_category` (Muscular, Joint, Bone/Ligament, Other), `injury_severity`  - Mesures : days_missed, games_missed



---5.5 fact_national_performance

  - Grain : joueur – profil sélection nationale (cumul ou snapshot)

## 📈 5. Faits (grains, mesures, FK)  - FK : player_sk, debut_date_sk (optionnel)

  - Mesures : caps (matches), goals

### 5.1 `fact_player_performance`

- **Grain** : Joueur – match – compétition – saison5.6 fact_teammate_relationship

- **FK** : `player_sk`, `team_sk`, `competition_sk`, `season_sk`, `match_date_sk`  - Grain : joueur – coéquipier

- **Mesures** : `minutes_played`, `goals`, `assists`, `yellow_cards`, `second_yellow_cards`, `direct_red_cards`  - FK : player_sk, teammate_sk

- **Règles** : `red_cards = second_yellow_cards + direct_red_cards`  - Mesures : minutes_played_together, joint_goal_participation



### 5.2 `fact_market_value`5.7 fact_player_season_summary (agrégat)

- **Grain** : Joueur – date d'évaluation  - Grain : joueur – saison

- **FK** : `player_sk`, `team_sk`, `valuation_date_sk`  - FK : player_sk, season_sk

- **Mesures** : `market_value`  - Mesures agrégées : total_matches, total_goals, total_assists, total_minutes, total_yellow_cards, total_red_cards, avg_goals_per_match, avg_assists_per_match, total_injury_days, total_games_missed

- **Mappings** : `date_unix` → `valuation_date_sk` ; `value` → `market_value`  - Alimentation : INSERT…SELECT groupé depuis fact_player_performance + sous-requêtes blessures



### 5.3 `fact_transfer`6) Clés & Conformité

- **Grain** : Joueur – évènement de transfert---------------------

- **FK** : `player_sk`, `from_team_sk`, `to_team_sk`, `season_sk`, `transfer_date_sk`, `transfer_type_sk`- NK (Natural Keys) conservées pour mapping (ex: player_id source)

- **Mesures** : `transfer_fee`, `market_value_at_transfer`- SK (Surrogate Keys) pour toutes FK dans les faits

- Conformité : dim_date, dim_season, dim_player partagées par tous les faits

### 5.4 `fact_injury`

- **Grain** : Joueur – évènement blessure7) Fonctions & Aides SQL

- **FK** : `player_sk`, `team_sk`, `season_sk`, `injury_type_sk`, `injury_from_date_sk`, `injury_end_date_sk`------------------------

- **Mesures** : `days_missed`, `games_missed`- dw.get_date_sk(date) : assure l’existence de la date dans dim_date et renvoie date_sk

- calculate_player_hash(...) : hash des attributs pour SCD2

### 5.5 `fact_national_performance`

- **Grain** : Joueur – profil sélection nationale (cumul ou snapshot)8) Contraintes & Index

- **FK** : `player_sk`, `debut_date_sk` (optionnel)----------------------

- **Mesures** : `caps` (matches), `goals`- PK sur toutes les dimensions (SK) et faits (clé technique ou composite selon table)

- FK pour l’intégrité référentielle DW

### 5.6 `fact_teammate_relationship`- Index sur colonnes de jointure clés (player_sk, team_sk, season_sk, date_sk…)

- **Grain** : Joueur – coéquipier- Unicité logique:

- **FK** : `player_sk`, `teammate_sk`  • fact_player_season_summary : unique (player_sk, season_sk)

- **Mesures** : `minutes_played_together`, `joint_goal_participation`

9) Nommage & Standards

### 5.7 `fact_player_season_summary` (agrégat)----------------------

- **Grain** : Joueur – saison- Schéma cible : dw

- **FK** : `player_sk`, `season_sk`- snake_case pour colonnes, préfixe explicite (…_sk, …_nk)

- **Mesures agrégées** :- Tables: dim_…, fact_…

  - `total_matches`, `total_goals`, `total_assists`, `total_minutes`- Mesures numériques en types adéquats (integer/numeric)

  - `total_yellow_cards`, `total_red_cards`

  - `avg_goals_per_match`, `avg_assists_per_match`10) Hypothèses & Limites

  - `total_injury_days`, `total_games_missed`------------------------

- **Alimentation** : `INSERT…SELECT` groupé depuis `fact_player_performance` + sous-requêtes blessures- Saisons de type football (année N/N+1) – règle N2 = N1 + 1

- Certaines colonnes sources diffèrent de la doc → mappées selon le schéma réel

---- Valeurs NULL tolérées sur certaines dates/clé faibles (ex: fin blessure)



## 🔑 6. Clés & Conformité11) Sécurité & DataOps

----------------------

- **NK** (Natural Keys) : Conservées pour mapping (ex: `player_id` source)- Secrets via .env

- **SK** (Surrogate Keys) : Pour toutes FK dans les faits- Exécutions orchestrées par run_etl.py

- **Conformité** : `dim_date`, `dim_season`, `dim_player` partagées par tous les faits- Scripts idempotents (skip si données déjà chargées)

- Logs par sortie console + vérifications post-chargement

---

12) Diagramme (ASCII – simplifié)

## ⚙️ 7. Fonctions & Aides SQL---------------------------------

          [dim_player]   [dim_team]   [dim_competition]   [dim_season]   [dim_date]

| Fonction | Description |                \            |               |                 |              /

|----------|-------------|                 \           |               |                 |             /

| `dw.get_date_sk(date)` | Assure l'existence de la date dans `dim_date` et renvoie `date_sk` |                  \          |               |                 |            /

| `calculate_player_hash(...)` | Hash des attributs pour SCD2 |                   \         |               |                 |           /

                [ fact_player_performance ]  [ fact_transfer ]  [ fact_market_value ]

---                         [ fact_injury ]     [ fact_national_performance ]

                        [ fact_teammate_relationship ]  [ fact_player_season_summary ]

## 🔐 8. Contraintes & Index

13) KPIs & Analyses Types

- **PK** sur toutes les dimensions (SK) et faits (clé technique ou composite selon table)-------------------------

- **FK** pour l'intégrité référentielle DW- Buteurs par saison / compétition

- **Index** sur colonnes de jointure clés (`player_sk`, `team_sk`, `season_sk`, `date_sk`…)- Evolution de la valeur de marché par joueur

- **Unicité logique** :- Impact blessures (jours & matches manqués) vs performances

  - `fact_player_season_summary` : unique (`player_sk`, `season_sk`)- Flux de transferts (montants, types, origines/destinations)

- Synergies coéquipiers (minutes & participations conjointes)

---

14) Évolutions futures

## 📝 9. Nommage & Standards----------------------

- Vues matérialisées pour requêtes lourdes

- **Schéma cible** : `dw`- Partitionnement de certains faits volumineux

- **Convention** : `snake_case` pour colonnes- Chargements incrémentaux

- **Préfixes** : `…_sk`, `…_nk`- Qualité des données (règles & alertes)

- **Tables** : `dim_…`, `fact_…`

- **Types** : Mesures numériques en types adéquats (integer/numeric)=====================================================================

FIN DE DOCUMENT – CONCEPTION DW

---=====================================================================


## ⚠️ 10. Hypothèses & Limites

- Saisons de type football (année N/N+1) – règle N2 = N1 + 1
- Certaines colonnes sources diffèrent de la doc → mappées selon le schéma réel
- Valeurs NULL tolérées sur certaines dates/clé faibles (ex: fin blessure)

---

## 🔒 11. Sécurité & DataOps

- **Secrets** via `.env`
- **Orchestration** par `run_etl.py`
- **Scripts idempotents** (skip si données déjà chargées)
- **Logs** par sortie console + vérifications post-chargement

---

## 📊 12. Diagramme (Architecture simplifiée)

```
          [dim_player]   [dim_team]   [dim_competition]   [dim_season]   [dim_date]
                \            |               |                 |              /
                 \           |               |                 |             /
                  \          |               |                 |            /
                   \         |               |                 |           /
                [ fact_player_performance ]  [ fact_transfer ]  [ fact_market_value ]
                         [ fact_injury ]     [ fact_national_performance ]
                        [ fact_teammate_relationship ]  [ fact_player_season_summary ]
```

---

## 📊 13. KPIs & Analyses Types

- ⚽ **Buteurs** par saison / compétition
- 💰 **Évolution de la valeur** de marché par joueur
- 🏥 **Impact blessures** (jours & matches manqués) vs performances
- 🔄 **Flux de transferts** (montants, types, origines/destinations)
- 🤝 **Synergies coéquipiers** (minutes & participations conjointes)

---

## 🚀 14. Évolutions futures

- [ ] Vues matérialisées pour requêtes lourdes
- [ ] Partitionnement de certains faits volumineux
- [ ] Chargements incrémentaux
- [ ] Qualité des données (règles & alertes)

---

## 📚 Ressources

- [Documentation ETL](./ETL_DOCUMENTATION.md)
- [Scripts R2W](./R2W/)
- [Base de données](./DATABASE/)

---

*Fin de document – Conception DW*
