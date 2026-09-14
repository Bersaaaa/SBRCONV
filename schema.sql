-- ============================================================
-- SBR AUTO — Schéma Supabase
-- À exécuter dans le SQL Editor d'un NOUVEAU projet Supabase
-- (créer ce projet séparément de SBRAUTO / SBRCOMPTA / SBRCARTEGRISE)
-- ============================================================

-- 1) Profils (1 ligne par utilisateur Supabase Auth)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'prestataire')),
  nom text not null,
  telephone text,
  actif boolean not null default true,
  specialites text[] not null default '{}', -- ex: {convoyage,nettoyage}
  contrat_url text,              -- contrat cadre autorisant le prestataire à travailler avec SBR AUTO
  contrat_ajoute_le timestamptz,
  created_at timestamptz not null default now()
);

-- 2) Missions
create table public.missions (
  id uuid primary key default gen_random_uuid(),
  type text not null check (type in ('convoyage', 'nettoyage', 'inspection', 'autre')),
  titre text not null,
  description text,
  vehicule text,               -- ex: "Peugeot 208 - AB-123-CD"
  lieu_depart text,
  lieu_arrivee text,
  date_prevue timestamptz,
  date_arrivee_prevue timestamptz,  -- convoyage uniquement
  prix_ht numeric(10,2) not null check (prix_ht >= 0),
  taux_tva numeric(5,2) not null default 20,
  statut text not null default 'disponible'
    check (statut in ('disponible', 'acceptee', 'en_cours', 'terminee', 'annulee')),
  prestataire_id uuid references public.profiles(id),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  termine_at timestamptz,
  facture_numero text,
  facture_url text,
  facture_emise_le timestamptz,
  contrat_url text,
  contrat_genere_le timestamptz
);

-- 3) Fonction utilitaire : l'utilisateur connecté est-il admin ?
create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- 4) Activation RLS
alter table public.profiles enable row level security;
alter table public.missions enable row level security;

-- 5) Policies profiles
create policy "profil visible par soi-meme ou admin"
  on public.profiles for select
  using (id = auth.uid() or public.is_admin());

create policy "admin gere les profils"
  on public.profiles for all
  using (public.is_admin())
  with check (public.is_admin());

-- 6) Policies missions
-- Lecture : admin voit tout / prestataire voit les missions dispo dans SA
-- spécialité + les siennes déjà attribuées
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

-- Création/édition/suppression : admin uniquement
create policy "admin cree missions"
  on public.missions for insert
  with check (public.is_admin());

create policy "admin edite missions"
  on public.missions for update
  using (public.is_admin())
  with check (public.is_admin());

create policy "admin supprime missions"
  on public.missions for delete
  using (public.is_admin());

-- Acceptation par un prestataire : autorisé UNIQUEMENT à passer
-- une mission "disponible" -> "acceptee" en se l'attribuant à lui-même,
-- et seulement si le type de la mission fait partie de ses spécialités
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

-- Le prestataire peut aussi mettre à jour ses propres missions acceptées
-- (ex: passer en "en_cours" ou "terminee")
create policy "prestataire avance ses missions"
  on public.missions for update
  using (prestataire_id = auth.uid())
  with check (prestataire_id = auth.uid());

-- 7) États des lieux (avant / après mission), remplis par le prestataire
create table public.etats_lieux (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references public.missions(id) on delete cascade,
  type text not null check (type in ('avant', 'apres')),
  kilometrage integer,
  carburant text check (carburant in ('reserve', 'quart', 'moitie', 'trois_quarts', 'plein')),
  etat_exterieur text,
  etat_interieur text,
  commentaire text,
  photos text[] default '{}',
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (mission_id, type)
);

alter table public.etats_lieux enable row level security;

create policy "lecture etats_lieux"
  on public.etats_lieux for select
  using (
    public.is_admin()
    or created_by = auth.uid()
    or exists (
      select 1 from public.missions
      where missions.id = etats_lieux.mission_id
      and missions.prestataire_id = auth.uid()
    )
  );

create policy "prestataire cree etat_lieux de sa mission"
  on public.etats_lieux for insert
  with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.missions
      where missions.id = mission_id
      and missions.prestataire_id = auth.uid()
    )
  );

-- 8) Stockage des photos d'état des lieux
insert into storage.buckets (id, name, public)
values ('etats-lieux', 'etats-lieux', true)
on conflict (id) do nothing;

create policy "lecture publique photos etats-lieux"
  on storage.objects for select
  using (bucket_id = 'etats-lieux');

create policy "upload photos etats-lieux par utilisateurs connectes"
  on storage.objects for insert
  with check (bucket_id = 'etats-lieux' and auth.uid() is not null);

-- 9) Stockage des factures (PDF), déposées par l'admin
insert into storage.buckets (id, name, public)
values ('factures', 'factures', true)
on conflict (id) do nothing;

create policy "lecture publique factures"
  on storage.objects for select
  using (bucket_id = 'factures');

create policy "upload factures par admin"
  on storage.objects for insert
  with check (bucket_id = 'factures' and public.is_admin());

-- 10) Évaluations des prestataires par l'admin (une par mission)
create table public.evaluations (
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

create policy "lecture evaluations"
  on public.evaluations for select
  using (public.is_admin() or prestataire_id = auth.uid());

create policy "admin gere les evaluations"
  on public.evaluations for all
  using (public.is_admin())
  with check (public.is_admin());

-- 11) Stockage des contrats (PDF), générés automatiquement à l'acceptation
insert into storage.buckets (id, name, public)
values ('contrats', 'contrats', true)
on conflict (id) do nothing;

create policy "lecture publique contrats"
  on storage.objects for select
  using (bucket_id = 'contrats');

create policy "upload contrats par utilisateurs connectes"
  on storage.objects for insert
  with check (bucket_id = 'contrats' and auth.uid() is not null);

-- ============================================================
-- Création des comptes prestataires :
-- Se fait manuellement depuis le Dashboard Supabase
-- (Authentication > Users > Add user), puis insérer la ligne
-- correspondante dans "profiles" avec role = 'prestataire'.
-- Idem pour ton propre compte admin, avec role = 'admin'.
-- Ensuite, va dans admin.html > "Prestataires" pour cocher les
-- spécialités de chaque prestataire (convoyage/nettoyage/inspection/
-- autre) : un prestataire ne voit que les missions disponibles dans
-- ses spécialités.
-- ============================================================
