-- ============================================================
-- SBR AUTO — Migration v7
-- À exécuter UNE FOIS dans le SQL Editor, APRÈS les migrations
-- précédentes (v2 à v6).
-- Ajoute : auto-inscription des prestataires (avec validation admin),
-- suivi de la relance automatique des missions non prises.
-- ============================================================

-- 1) Champs pour l'auto-inscription
alter table public.profiles
  add column if not exists email text,
  add column if not exists en_attente_validation boolean not null default false;

-- 2) Un utilisateur qui vient de s'inscrire peut créer SA propre ligne
-- de profil, mais seulement en tant que prestataire, désactivé et en
-- attente de validation — impossible de s'auto-promouvoir admin ou de
-- s'auto-activer.
drop policy if exists "auto-inscription prestataire" on public.profiles;
create policy "auto-inscription prestataire"
  on public.profiles for insert
  with check (
    id = auth.uid()
    and role = 'prestataire'
    and actif = false
    and en_attente_validation = true
  );

-- 3) Suivi de la relance automatique (pour ne pas relancer 10 fois/jour)
alter table public.missions
  add column if not exists relance_envoyee_le timestamptz;
