-- ============================================================
-- SBR CONVOYAGE — Migration v12
-- À exécuter UNE FOIS, après les migrations précédentes (v2 à v11).
-- Ajoute : nom du client final sur la mission (pour le contrat de
-- mission, façon lettre de voiture / CMR).
-- ============================================================

alter table public.missions
  add column if not exists nom_client text;
