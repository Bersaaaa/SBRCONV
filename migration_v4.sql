-- ============================================================
-- SBR AUTO — Migration v4
-- À exécuter UNE FOIS dans le SQL Editor, APRÈS schema.sql (ou
-- migration_v2.sql + migration_v3.sql si déjà passées).
-- Ajoute : contrat cadre par prestataire (autorisation à travailler
-- avec SBR AUTO), date d'arrivée prévue pour les convoyages.
-- ============================================================

alter table public.profiles
  add column if not exists contrat_url text,
  add column if not exists contrat_ajoute_le timestamptz;

alter table public.missions
  add column if not exists date_arrivee_prevue timestamptz;

-- Rappel : le contrat cadre prestataire utilise le bucket "contrats"
-- déjà créé par migration_v3.sql (ou schema.sql). Si tu n'as jamais
-- exécuté migration_v3.sql, exécute-le avant celui-ci.
