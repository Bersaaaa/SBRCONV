-- ============================================================
-- SBR CONVOYAGE — Migration v3
-- À exécuter UNE FOIS dans le SQL Editor, APRÈS avoir déjà exécuté
-- schema.sql et migration_v2.sql sur ce projet.
-- Ajoute : notation des prestataires, génération de contrat PDF.
-- (Les notifications email se déploient séparément, voir README.)
-- ============================================================

-- 1) Colonnes contrat sur les missions
alter table public.missions
  add column if not exists contrat_url text,
  add column if not exists contrat_genere_le timestamptz;

-- 2) Évaluations des prestataires par l'admin (une par mission)
create table if not exists public.evaluations (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references public.missions(id) on delete cascade,
  prestataire_id uuid not null references public.profiles(id) on delete cascade,
  note integer not null check (note between 1 and 5),
  commentaire text,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (mission_id)
);

alter table public.evaluations enable row level security;

drop policy if exists "lecture evaluations" on public.evaluations;
create policy "lecture evaluations"
  on public.evaluations for select
  using (public.is_admin() or prestataire_id = auth.uid());

drop policy if exists "admin gere les evaluations" on public.evaluations;
create policy "admin gere les evaluations"
  on public.evaluations for all
  using (public.is_admin())
  with check (public.is_admin());

-- 3) Bucket de stockage pour les contrats PDF générés automatiquement
insert into storage.buckets (id, name, public)
values ('contrats', 'contrats', true)
on conflict (id) do nothing;

drop policy if exists "lecture publique contrats" on storage.objects;
create policy "lecture publique contrats"
  on storage.objects for select
  using (bucket_id = 'contrats');

drop policy if exists "upload contrats par utilisateurs connectes" on storage.objects;
create policy "upload contrats par utilisateurs connectes"
  on storage.objects for insert
  with check (bucket_id = 'contrats' and auth.uid() is not null);
