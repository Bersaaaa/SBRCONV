-- ============================================================================
-- SBR AUTO — NETTOYAGE DE L'ANCIENNE VERSION
--
--   ⚠️  CE SCRIPT EFFACE DES DONNÉES DÉFINITIVEMENT. IL N'Y A PAS DE RETOUR
--       EN ARRIÈRE POSSIBLE, MÊME PAR LE SUPPORT SUPABASE.
--
--   À exécuter UNIQUEMENT si :
--     1. tu as déjà fait tourner schema.sql (la nouvelle version) ;
--     2. la nouvelle app fonctionne correctement ;
--     3. tu as téléchargé une sauvegarde Excel (Paramètres → Sauvegarde) ou
--        exporté à la main les tables ci-dessous depuis Supabase
--        (Table Editor → la table → ⋯ → Export as CSV) ;
--     4. tu n'as plus besoin de tes anciennes recettes / achats pour ta
--        comptabilité. Rappel : les registres légaux doivent être conservés
--        10 ans. En cas de doute, NE LANCE PAS CE SCRIPT — ces tables ne
--        gênent rien, elles dorment dans la base sans rien coûter.
--
--   Comment faire : Supabase → SQL Editor → New query → coller → Run.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 1. Anciens registres et journaux (Livre Recettes, Livre Achats, répartition
--    d'un montant entre plusieurs plaques, journal des modifications).
-- ---------------------------------------------------------------------------
drop table if exists public.montant_splits cascade;
drop table if exists public.historique     cascade;
drop table if exists public.recettes       cascade;
drop table if exists public.achats         cascade;


-- ---------------------------------------------------------------------------
-- 2. Anciens réglages devenus inutiles dans la table params
--    (TVA, décote globale, versement libératoire, prélèvement à la source).
-- ---------------------------------------------------------------------------
alter table public.params drop column if exists seuil_tva;
alter table public.params drop column if exists decote_mensuelle;
alter table public.params drop column if exists versement_liberatoire;
alter table public.params drop column if exists prelevement_source_ga;
alter table public.params drop column if exists prelevement_source_turo;
alter table public.params drop column if exists prelevement_source_roadstr;


-- ---------------------------------------------------------------------------
-- 3. Colonne « location directe » de la rentabilité (supprimée de l'app).
--    À ne lancer que si tu n'as jamais rien saisi dedans.
-- ---------------------------------------------------------------------------
alter table public.renta_lignes drop column if exists rev_direct;


-- ---------------------------------------------------------------------------
-- 4. Vérification : la liste ci-dessous ne doit plus contenir
--    recettes, achats, montant_splits ni historique.
-- ---------------------------------------------------------------------------
select table_name
from information_schema.tables
where table_schema = 'public'
order by table_name;
