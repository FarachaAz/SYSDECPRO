=====================================================================
Conception du Data Warehouse (DW) – Football Data
Dernière mise à jour : 2025-11-16
Auteur : FarachaAz / SYSDECPRO
=====================================================================

1) Vision & Objectifs BI
------------------------
- Offrir une vue analytique consolidée sur les joueurs, leurs performances, valeurs de marché, blessures, transferts et relations.
- Supporter des cas d’usage : top buteurs par saison, progression de valeur, impact des blessures, historique de transferts, synergies entre coéquipiers.

2) Principes de modélisation
----------------------------
- Schéma en étoile (star schema)
- Grains clairs et stables pour les tables de faits
- Clés substitutives (surrogate keys, SK) en DW
- Dimensions conformes (ex. joueur, saison, date)
- SCD Type 2 sur la dimension Joueur (historisation des attributs)
- Dimension Date centralisée alimentée par get_date_sk()

3) Périmètre fonctionnel
------------------------
- 8 dimensions : date, joueur, agent, équipe, compétition, saison, type de transfert, type de blessure.
- 7 faits : performances, valeur de marché, transferts, blessures, perfs en sélection, relations coéquipiers, résumé joueur-saison.

4) Dimensions (détails)
-----------------------
4.1 dim_date
  - Rôle : calendrier de référence (jour)
  - SK : date_sk (int AAAAMMJJ)
  - Attributs : full_date, année, mois, trimestre, jour_semaine, etc.
  - Alimentation : fonction dw.get_date_sk(date) à la volée (crée si absent)

4.2 dim_player (SCD Type 2)
  - Grain : joueur
  - NK : player_nk (player_id source)
  - SK : player_sk (surrogate)
  - Attributs : player_name, position, date_of_birth, height_cm, foot, current_club_nk, country_of_birth, citizenship, contract_expires, agent_sk, is_current, valid_from/valid_to, source_row_hash
  - Politique SCD2 : nouvelles lignes insérées si hash change (valid_to mis à jour sur anciennes)

4.3 dim_agent
  - NK : agent_id
  - SK : agent_sk
  - Attributs : agent_name

4.4 dim_team
  - NK : team_nk (club_id source cast en varchar)
  - SK : team_sk
  - Attributs : team_name, country_name, primary_competition_id, division_level

4.5 dim_competition
  - NK : competition_id (dérivé du nom)
  - SK : competition_sk
  - Attributs : competition_name, country_name, tier_level

4.6 dim_season
  - NK/SK : season_name / season_sk
  - Attributs : season_start_year, season_end_year, is_current_season
  - Parsing des formats : ‘24/25’, ‘99/00’, ‘2024’

4.7 dim_transfer_type
  - SK : transfer_type_sk
  - Attributs : transfer_type_name (ex: Loan, Permanent, Free…)

4.8 dim_injury_type
  - SK : injury_type_sk
  - Attributs : injury_category (Muscular, Joint, Bone/Ligament, Other), injury_severity

5) Faits (grains, mesures, FK)
------------------------------
5.1 fact_player_performance
  - Grain : joueur – match – compétition – saison
  - FK : player_sk, team_sk, competition_sk, season_sk, match_date_sk
  - Mesures : minutes_played, goals, assists, yellow_cards, second_yellow_cards, direct_red_cards
  - Règles : red_cards = second_yellow_cards + direct_red_cards

5.2 fact_market_value
  - Grain : joueur – date d’évaluation
  - FK : player_sk, team_sk, valuation_date_sk
  - Mesures : market_value
  - Mappings : date_unix → valuation_date_sk ; value → market_value

5.3 fact_transfer
  - Grain : joueur – évènement de transfert
  - FK : player_sk, from_team_sk, to_team_sk, season_sk, transfer_date_sk, transfer_type_sk
  - Mesures : transfer_fee, market_value_at_transfer

5.4 fact_injury
  - Grain : joueur – évènement blessure
  - FK : player_sk, team_sk, season_sk, injury_type_sk, injury_from_date_sk, injury_end_date_sk
  - Mesures : days_missed, games_missed

5.5 fact_national_performance
  - Grain : joueur – profil sélection nationale (cumul ou snapshot)
  - FK : player_sk, debut_date_sk (optionnel)
  - Mesures : caps (matches), goals

5.6 fact_teammate_relationship
  - Grain : joueur – coéquipier
  - FK : player_sk, teammate_sk
  - Mesures : minutes_played_together, joint_goal_participation

5.7 fact_player_season_summary (agrégat)
  - Grain : joueur – saison
  - FK : player_sk, season_sk
  - Mesures agrégées : total_matches, total_goals, total_assists, total_minutes, total_yellow_cards, total_red_cards, avg_goals_per_match, avg_assists_per_match, total_injury_days, total_games_missed
  - Alimentation : INSERT…SELECT groupé depuis fact_player_performance + sous-requêtes blessures

6) Clés & Conformité
---------------------
- NK (Natural Keys) conservées pour mapping (ex: player_id source)
- SK (Surrogate Keys) pour toutes FK dans les faits
- Conformité : dim_date, dim_season, dim_player partagées par tous les faits

7) Fonctions & Aides SQL
------------------------
- dw.get_date_sk(date) : assure l’existence de la date dans dim_date et renvoie date_sk
- calculate_player_hash(...) : hash des attributs pour SCD2

8) Contraintes & Index
----------------------
- PK sur toutes les dimensions (SK) et faits (clé technique ou composite selon table)
- FK pour l’intégrité référentielle DW
- Index sur colonnes de jointure clés (player_sk, team_sk, season_sk, date_sk…)
- Unicité logique:
  • fact_player_season_summary : unique (player_sk, season_sk)

9) Nommage & Standards
----------------------
- Schéma cible : dw
- snake_case pour colonnes, préfixe explicite (…_sk, …_nk)
- Tables: dim_…, fact_…
- Mesures numériques en types adéquats (integer/numeric)

10) Hypothèses & Limites
------------------------
- Saisons de type football (année N/N+1) – règle N2 = N1 + 1
- Certaines colonnes sources diffèrent de la doc → mappées selon le schéma réel
- Valeurs NULL tolérées sur certaines dates/clé faibles (ex: fin blessure)

11) Sécurité & DataOps
----------------------
- Secrets via .env
- Exécutions orchestrées par run_etl.py
- Scripts idempotents (skip si données déjà chargées)
- Logs par sortie console + vérifications post-chargement

12) Diagramme (ASCII – simplifié)
---------------------------------
          [dim_player]   [dim_team]   [dim_competition]   [dim_season]   [dim_date]
                \            |               |                 |              /
                 \           |               |                 |             /
                  \          |               |                 |            /
                   \         |               |                 |           /
                [ fact_player_performance ]  [ fact_transfer ]  [ fact_market_value ]
                         [ fact_injury ]     [ fact_national_performance ]
                        [ fact_teammate_relationship ]  [ fact_player_season_summary ]

13) KPIs & Analyses Types
-------------------------
- Buteurs par saison / compétition
- Evolution de la valeur de marché par joueur
- Impact blessures (jours & matches manqués) vs performances
- Flux de transferts (montants, types, origines/destinations)
- Synergies coéquipiers (minutes & participations conjointes)

14) Évolutions futures
----------------------
- Vues matérialisées pour requêtes lourdes
- Partitionnement de certains faits volumineux
- Chargements incrémentaux
- Qualité des données (règles & alertes)

=====================================================================
FIN DE DOCUMENT – CONCEPTION DW
=====================================================================
