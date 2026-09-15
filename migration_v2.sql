-- ============================================================
-- SBR CONVOYAGE — Migration v2
-- À exécuter UNE FOIS dans le SQL Editor de ton projet Supabase
-- EXISTANT (celui déjà configuré avec schema.sql).
-- Ajoute : spécialités prestataires, facture par mission,
-- missions visibles filtrées par spécialité.
-- ============================================================

-- 1) Spécialités des prestataires
alter table public.profiles
  add column if not exists specialites text[] not null default '{}';

-- 2) Facture par mission
alter table public.missions
  add column if not exists facture_numero text,
  add column if not exists facture_url text,
  add column if not exists facture_emise_le timestamptz;

-- 3) Remplace la policy de lecture des missions : un prestataire ne voit
-- désormais que les missions disponibles dans SA/SES spécialité(s)
drop policy if exists "lecture missions" on public.missions;
create policy "lecture missions"
  on public.missions for select
  using (
    public.is_admin()
    or prestataire_id = auth.uid()
    or (
      statut = 'disponible'
      and exists (
        select 1 from public.profiles p
        where p.id = auth.uid() and missions.type = any(p.specialites)
      )
    )
  );

-- 4) Remplace la policy d'acceptation : idem, restreinte à la spécialité
drop policy if exists "prestataire accepte mission disponible" on public.missions;
create policy "prestataire accepte mission disponible"
  on public.missions for update
  using (
    statut = 'disponible'
    and exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and missions.type = any(p.specialites)
    )
  )
  with check (
    prestataire_id = auth.uid()
    and statut = 'acceptee'
  );

-- 5) Bucket de stockage pour les factures (PDF), déposées par l'admin
insert into storage.buckets (id, name, public)
values ('factures', 'factures', true)
on conflict (id) do nothing;

drop policy if exists "lecture publique factures" on storage.objects;
create policy "lecture publique factures"
  on storage.objects for select
  using (bucket_id = 'factures');

drop policy if exists "upload factures par admin" on storage.objects;
create policy "upload factures par admin"
  on storage.objects for insert
  with check (bucket_id = 'factures' and public.is_admin());

-- ============================================================
-- IMPORTANT : une fois cette migration exécutée, tous tes
-- prestataires ont "specialites = {}" (tableau vide) — donc PLUS
-- AUCUNE mission disponible ne leur sera visible tant que tu ne
-- leur as pas coché au moins une spécialité.
-- Va dans admin.html > bouton "Prestataires" pour les cocher.
-- ============================================================
