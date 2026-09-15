-- ============================================================
-- SBR CONVOYAGE — Migration v9
-- À exécuter UNE FOIS dans le SQL Editor, APRÈS les migrations
-- précédentes (v2 à v8).
-- Ajoute les informations légales utilisées dans le contrat de
-- prestation (SIRET, forme juridique, adresse).
-- ============================================================

alter table public.entreprise_config
  add column if not exists forme_juridique text,
  add column if not exists siret text;

alter table public.profiles
  add column if not exists siret text,
  add column if not exists statut_juridique text,
  add column if not exists adresse text;
