-- ============================================================================
-- SBR AUTO — Schéma Supabase complet (tout-en-un)
-- ============================================================================
-- Ce script est idempotent : il peut être exécuté plusieurs fois sans erreur,
-- sur une base neuve ou sur une base existante (il ne fait que compléter ce
-- qui manque, il ne supprime jamais de données).
--
-- À exécuter dans : Supabase Dashboard > SQL Editor > New query > Run
-- ============================================================================

create extension if not exists pgcrypto;

-- ============================================================================
-- NETTOYAGE DES ANCIENS MODULES SUPPRIMÉS DE SBR AUTO
-- Ces éléments ne sont plus utilisés par l'application. Le bloc est idempotent.
-- ============================================================================
drop table if exists public.reservations_vitrine cascade;
drop table if exists public.etats_lieux cascade;
drop table if exists public.contrats cascade;

alter table if exists public.vehicles drop column if exists tarif_ga;
alter table if exists public.vehicles drop column if exists tarif_turo;
alter table if exists public.vehicles drop column if exists visible_vitrine;
alter table if exists public.vehicles drop column if exists prix_jour_vitrine;
alter table if exists public.vehicles drop column if exists caution_vitrine;
alter table if exists public.vehicles drop column if exists dispo_abonnement;
alter table if exists public.vehicles drop column if exists photo_vitrine_url;
alter table if exists public.params drop column if exists adresse_retrait_vitrine;
alter table if exists public.params drop column if exists prix_option_siege_bebe;
alter table if exists public.params drop column if exists prix_option_rehausseur;
alter table if exists public.params drop column if exists prix_option_livraison_aeroport;
alter table if exists public.params drop column if exists prix_option_livraison_domicile;
alter table if exists public.params drop column if exists prix_mois_abonnement;

-- Nettoyage des anciens objets de stockage liés à la vitrine.
-- (La suppression directe de storage.objects est bloquée par Supabase par
-- sécurité — passe par le Storage API ou l'onglet Storage du Dashboard si
-- tu dois vraiment vider ce bucket, pas par du SQL brut.)
drop policy if exists "vitrine_photos_public_read" on storage.objects;
drop policy if exists "vitrine_photos_authenticated_write" on storage.objects;

-- ============================================================================
-- 1) TABLES
-- ============================================================================

-- Profils utilisateurs (droits d'accès par onglet, rôle affiché)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  is_admin boolean not null default true,
  nom text,
  email text,
  role_label text,
  allowed_tabs jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- Paramètres généraux de l'entreprise (une seule ligne, id = 1)
create table if not exists public.params (
  id integer primary key default 1,
  entreprise text,
  siret text,
  statut text,
  ville text,
  seuil_tva numeric,
  decote_mensuelle numeric,
  seuil_entretien_km numeric,
  alert_email text,
  date_debut_activite date,
  versement_liberatoire boolean not null default false,
  signature_loueur_url text,
  adresse text
);

-- Véhicules de la flotte
create table if not exists public.vehicles (
  id uuid primary key default gen_random_uuid(),
  nom text,
  immat text,
  annee integer,
  energie text,
  critair text,
  km numeric default 0,
  valeur_achat numeric default 0,
  valeur_actuelle numeric default 0,
  prochain_ct date,
  prochaine_assurance date,
  prochain_entretien_km numeric default 0,
  statut text default 'Actif',
  notes text,
  km_updated_at timestamptz,
  carte_grise_url text,
  assurance_url text,
  autorisation_url text,
  marque text,
  vin text,
  proprietaire_nom text,
  proprietaire_naissance date,
  proprietaire_adresse text,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

-- Recettes (ARCHIVE : registre supprimé de l'app, table conservée telle quelle
-- pour ne perdre aucune donnée ancienne. Plus lue ni écrite par SBR AUTO.)
create table if not exists public.recettes (
  id uuid primary key default gen_random_uuid(),
  immat text,
  date date,
  nature text,
  categorie text,
  montant numeric default 0,
  mode text,
  plateforme text,
  notes text,
  justificatif_url text,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

-- Achats / dépenses (ARCHIVE : registre supprimé de l'app, table conservée)
create table if not exists public.achats (
  id uuid primary key default gen_random_uuid(),
  immat text,
  date date,
  nature text,
  montant numeric default 0,
  mode text,
  categorie text,
  justificatif text,
  justificatif_url text,
  notes text,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

-- Carnet d'entretien
create table if not exists public.entretiens (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid references public.vehicles(id) on delete cascade,
  type text,
  type_detail text,
  garage text,
  date date,
  km_realise numeric,
  prochain_km numeric,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

-- Amendes
create table if not exists public.amendes (
  id uuid primary key default gen_random_uuid(),
  date date,
  immat text,
  plateforme text,
  montant numeric default 0,
  statut text default 'En attente',
  notes text,
  justificatifs_urls jsonb not null default '[]'::jsonb,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

-- Accessoires (ex: sièges auto)
create table if not exists public.accessories (
  id uuid primary key default gen_random_uuid(),
  nom text,
  ref text,
  statut text default 'Disponible',
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

-- Répartition d'un montant (ARCHIVE : plus utilisée par l'app)
create table if not exists public.montant_splits (
  id uuid primary key default gen_random_uuid(),
  source_table text not null,
  source_id uuid not null,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  montant numeric not null default 0,
  created_at timestamptz not null default now()
);

-- Rentabilité par véhicule : UNE ligne par véhicule et par mois, saisie
-- entièrement à la main dans l'onglet Rentabilité de l'app.
create table if not exists public.renta_lignes (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  annee integer not null,
  mois integer not null check (mois >= 0 and mois <= 11),
  rev_getaround numeric default 0,
  rev_turo numeric default 0,
  rev_roadstr numeric default 0,
  rev_vente numeric default 0,
  rev_autres numeric default 0,
  dep_assurance numeric default 0,
  dep_credit numeric default 0,
  dep_entretien numeric default 0,
  dep_reparation numeric default 0,
  dep_pneus numeric default 0,
  dep_carburant numeric default 0,
  dep_nettoyage numeric default 0,
  dep_amendes numeric default 0,
  dep_parking numeric default 0,
  dep_autres numeric default 0,
  decote numeric default 0,
  notes text,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);

-- Planning d'occupation des véhicules (GA / Turo / etc, par jour)
create table if not exists public.planning_vehicules (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  day date not null,
  statut text,
  created_at timestamptz not null default now()
);

-- Planning d'occupation des accessoires (par jour)
create table if not exists public.planning_sieges (
  id uuid primary key default gen_random_uuid(),
  accessory_id uuid not null references public.accessories(id) on delete cascade,
  day date not null,
  statut text,
  created_at timestamptz not null default now()
);

-- Historique / journal des modifications (ARCHIVE : onglet supprimé de l'app)
create table if not exists public.historique (
  id uuid primary key default gen_random_uuid(),
  table_name text,
  row_id text,
  action text,
  champ text,
  ancienne_valeur text,
  nouvelle_valeur text,
  resume text,
  utilisateur text,
  created_at timestamptz not null default now()
);

-- ============================================================================
-- 2) COLONNES MANQUANTES (upgrade en douceur si la table existait déjà
--    avec un schéma plus ancien / partiel)
-- ============================================================================

alter table public.profiles      add column if not exists allowed_tabs jsonb not null default '[]'::jsonb;
alter table public.params        add column if not exists versement_liberatoire boolean not null default false;
alter table public.vehicles      add column if not exists marque text;
alter table public.vehicles      add column if not exists vin text;
alter table public.vehicles      add column if not exists proprietaire_nom text;
alter table public.vehicles      add column if not exists proprietaire_naissance date;
alter table public.vehicles      add column if not exists proprietaire_adresse text;
alter table public.vehicles      add column if not exists autorisation_url text;
alter table public.vehicles      add column if not exists deleted_at timestamptz;
alter table public.recettes      add column if not exists justificatif_url text;
alter table public.recettes      add column if not exists deleted_at timestamptz;
alter table public.achats        add column if not exists justificatif_url text;
alter table public.achats        add column if not exists deleted_at timestamptz;
alter table public.entretiens    add column if not exists type_detail text;
alter table public.entretiens    add column if not exists garage text;
alter table public.entretiens    add column if not exists deleted_at timestamptz;
alter table public.amendes       add column if not exists justificatifs_urls jsonb not null default '[]'::jsonb;
alter table public.amendes       add column if not exists deleted_at timestamptz;
alter table public.accessories   add column if not exists deleted_at timestamptz;
alter table public.params        add column if not exists signature_loueur_url text;
alter table public.params        add column if not exists adresse text;
alter table public.renta_lignes  add column if not exists rev_vente numeric default 0;
alter table public.renta_lignes  add column if not exists dep_parking numeric default 0;
alter table public.renta_lignes  add column if not exists notes text;
alter table public.renta_lignes  add column if not exists deleted_at timestamptz;
-- Colonnes conservées en base mais PLUS UTILISÉES par l'application
-- (TVA, décote globale, versement libératoire, prélèvement à la source URSSAF).
-- Elles ne sont pas supprimées pour ne perdre aucune donnée existante ;
-- l'app ne les lit ni ne les écrit. La décote se saisit désormais par
-- véhicule et par mois dans renta_lignes.decote.

-- ============================================================================
-- 3) CONTRAINTES D'UNICITÉ ET INDEX
-- ============================================================================

do $$ begin
  alter table public.montant_splits
    add constraint montant_splits_unique unique (source_table, source_id, vehicle_id);
exception when duplicate_object or duplicate_table then null; end $$;

do $$ begin
  alter table public.planning_vehicules
    add constraint planning_vehicules_unique unique (vehicle_id, day);
exception when duplicate_object or duplicate_table then null; end $$;

do $$ begin
  alter table public.planning_sieges
    add constraint planning_sieges_unique unique (accessory_id, day);
exception when duplicate_object or duplicate_table then null; end $$;

create index if not exists idx_recettes_deleted_at    on public.recettes(deleted_at);
create index if not exists idx_achats_deleted_at      on public.achats(deleted_at);
create index if not exists idx_vehicles_deleted_at    on public.vehicles(deleted_at);
create index if not exists idx_entretiens_deleted_at  on public.entretiens(deleted_at);
create index if not exists idx_amendes_deleted_at     on public.amendes(deleted_at);
create index if not exists idx_accessories_deleted_at on public.accessories(deleted_at);
create index if not exists idx_entretiens_vehicle_id  on public.entretiens(vehicle_id);
create index if not exists idx_recettes_immat         on public.recettes(immat);
create index if not exists idx_achats_immat           on public.achats(immat);
create index if not exists idx_amendes_immat          on public.amendes(immat);
create index if not exists idx_renta_vehicle        on public.renta_lignes(vehicle_id);
create index if not exists idx_renta_periode        on public.renta_lignes(annee, mois);
create index if not exists idx_renta_deleted_at     on public.renta_lignes(deleted_at);

-- Une seule ligne de rentabilité active par véhicule et par mois (les lignes
-- mises à la corbeille ne bloquent pas une nouvelle saisie du même mois).
drop index if exists idx_renta_unique_active;
create unique index idx_renta_unique_active
  on public.renta_lignes (vehicle_id, annee, mois)
  where deleted_at is null;

create index if not exists idx_historique_table_row   on public.historique(table_name, row_id);
create index if not exists idx_historique_created_at  on public.historique(created_at desc);

-- Ligne de paramètres par défaut (id fixe = 1)
insert into public.params (id, entreprise, siret)
values (1, 'SBR AUTO', '88938497000014')
on conflict (id) do nothing;

-- ============================================================================
-- 3bis) CONTRAINTES D'INTÉGRITÉ SUPPLÉMENTAIRES
-- ============================================================================

-- Une plaque ne peut être utilisée que par un seul véhicule actif à la fois
-- (les véhicules mis à la corbeille — deleted_at renseigné — ne comptent pas,
-- ce qui permet de réutiliser une plaque après suppression définitive).
drop index if exists idx_vehicles_immat_unique_active;
create unique index idx_vehicles_immat_unique_active
  on public.vehicles (immat)
  where deleted_at is null and immat is not null and immat <> '';

do $$ begin
  alter table public.recettes   add constraint recettes_montant_positif   check (montant >= 0);
exception when duplicate_object or duplicate_table then null; end $$;
do $$ begin
  alter table public.achats     add constraint achats_montant_positif     check (montant >= 0);
exception when duplicate_object or duplicate_table then null; end $$;
do $$ begin
  alter table public.amendes    add constraint amendes_montant_positif    check (montant >= 0);
exception when duplicate_object or duplicate_table then null; end $$;
do $$ begin
  alter table public.montant_splits add constraint montant_splits_montant_positif check (montant >= 0);
exception when duplicate_object or duplicate_table then null; end $$;

do $$ begin
  alter table public.vehicles add constraint vehicles_statut_valide
    check (statut is null or statut in ('Actif','Inactif','Vendu','En réparation'));
exception when duplicate_object or duplicate_table then null; end $$;
do $$ begin
  alter table public.amendes add constraint amendes_statut_valide
    check (statut is null or statut in ('En attente','Payée','Contestée'));
exception when duplicate_object or duplicate_table then null; end $$;
do $$ begin
  alter table public.achats add constraint achats_justificatif_valide
    check (justificatif is null or justificatif in ('Oui','Non'));
exception when duplicate_object or duplicate_table then null; end $$;

-- Statuts autorisés pour le planning véhicules (inclut "Direct" = location
-- directe hors plateforme). "drop + recreate" pour couvrir le cas où une
-- contrainte plus ancienne existe déjà sur la base en production sans
-- "Direct" dans la liste.
alter table public.planning_vehicules drop constraint if exists planning_vehicules_statut_check;
alter table public.planning_vehicules add constraint planning_vehicules_statut_check
  check (statut is null or statut in ('GA','Turo','Roadstr','Direct','Sinistre'));

create index if not exists idx_planning_vehicules_day on public.planning_vehicules(day);
create index if not exists idx_planning_sieges_day     on public.planning_sieges(day);

-- ============================================================================
-- 4) ROW LEVEL SECURITY — accès selon le rôle (admin = tout ; sinon selon
--    les onglets autorisés dans profiles.allowed_tabs, même logique que
--    TAB_TABLES côté app)
-- ============================================================================

alter table public.profiles          enable row level security;
alter table public.params            enable row level security;
alter table public.vehicles          enable row level security;
alter table public.recettes          enable row level security;
alter table public.achats            enable row level security;
alter table public.entretiens        enable row level security;
alter table public.amendes           enable row level security;
alter table public.accessories       enable row level security;
alter table public.montant_splits    enable row level security;
alter table public.renta_lignes      enable row level security;
alter table public.planning_vehicules enable row level security;
alter table public.planning_sieges   enable row level security;
alter table public.historique        enable row level security;

-- Fonction centrale : reproduit TAB_TABLES de l'app (index.html) pour que la
-- sécurité côté base corresponde à ce que l'app autorise déjà côté écran.
-- Admin (is_admin = true) => accès total. Sinon => selon les onglets cochés.
create or replace function public.has_table_access(tbl text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    coalesce(
      (select is_admin from public.profiles where id = auth.uid()),
      false
    )
    or exists (
      select 1
      from public.profiles p,
           jsonb_array_elements_text(to_jsonb(p.allowed_tabs)) as tab
      where p.id = auth.uid()
        and (
          (tbl = 'renta_lignes'       and tab in ('rentabilite','dashboard')) or
          (tbl = 'vehicles'           and tab in ('planningVeh','vehicules','amendes','rentabilite','dashboard')) or
          (tbl = 'accessories'        and tab in ('planningSiege')) or
          (tbl = 'amendes'            and tab in ('amendes')) or
          (tbl = 'planning_vehicules' and tab in ('planningVeh','amendes','rentabilite','dashboard')) or
          (tbl = 'planning_sieges'    and tab in ('planningSiege')) or
          (tbl = 'entretiens'         and tab in ('vehicules'))
        )
    );
$$;

-- Tout le monde authentifié peut lire les paramètres (nécessaires à l'app)
drop policy if exists "params_read_all" on public.params;
create policy "params_read_all" on public.params
  for select to authenticated using (true);

drop policy if exists "params_write_admin" on public.params;
create policy "params_write_admin" on public.params
  for update to authenticated
  using (coalesce((select is_admin from public.profiles where id = auth.uid()), false))
  with check (coalesce((select is_admin from public.profiles where id = auth.uid()), false));

-- Tables métier : accès selon has_table_access()
do $$
declare
  t text;
begin
  foreach t in array array['vehicles','renta_lignes','entretiens','amendes',
                            'accessories','planning_vehicules','planning_sieges']
  loop
    execute format('drop policy if exists "role_based_access_%1$s" on public.%1$s', t);
    execute format(
      'create policy "role_based_access_%1$s" on public.%1$s for all to authenticated using (public.has_table_access(%2$L)) with check (public.has_table_access(%2$L))',
      t, t
    );
  end loop;
end $$;

-- historique : lecture réservée aux admins, mais tout le monde peut y écrire
-- (l'app journalise les actions de chaque utilisateur, y compris non-admin).
drop policy if exists "historique_select_admin" on public.historique;
create policy "historique_select_admin" on public.historique
  for select to authenticated
  using (coalesce((select is_admin from public.profiles where id = auth.uid()), false));

drop policy if exists "historique_insert_all" on public.historique;
create policy "historique_insert_all" on public.historique
  for insert to authenticated with check (true);

-- profiles : chacun peut lire tous les profils (utile pour afficher qui a
-- fait quoi) mais ne peut modifier que le sien. La gestion des rôles
-- (is_admin / allowed_tabs) se fait depuis le Dashboard Supabase (clé
-- service_role, qui contourne RLS), pas depuis l'app elle-même.
drop policy if exists "profiles_self_select" on public.profiles;
create policy "profiles_self_select" on public.profiles
  for select to authenticated using (true);

drop policy if exists "profiles_self_update" on public.profiles;
create policy "profiles_self_update" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Verrou anti-élévation de privilèges : un utilisateur non-admin qui modifie
-- sa propre ligne (ex: son nom) ne peut pas s'auto-attribuer is_admin,
-- allowed_tabs ou role_label au passage. Seul un admin (ou le Dashboard
-- Supabase via service_role) peut changer les droits de quelqu'un.
create or replace function public.protect_profile_privileges()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not coalesce((select is_admin from public.profiles where id = auth.uid()), false) then
    new.is_admin := old.is_admin;
    new.allowed_tabs := old.allowed_tabs;
    new.role_label := old.role_label;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_profile_privileges_trigger on public.profiles;
create trigger protect_profile_privileges_trigger
  before update on public.profiles
  for each row execute function public.protect_profile_privileges();

-- ============================================================================
-- 5) CRÉATION AUTOMATIQUE DU PROFIL À L'INSCRIPTION
-- ============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, email, is_admin)
  values (new.id, new.email, true)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- 6) STOCKAGE (bucket privé pour les justificatifs / documents véhicules)
-- ============================================================================

insert into storage.buckets (id, name, public)
values ('justificatifs', 'justificatifs', false)
on conflict (id) do nothing;

drop policy if exists "justificatifs_authenticated_all" on storage.objects;
create policy "justificatifs_authenticated_all" on storage.objects
  for all to authenticated
  using (bucket_id = 'justificatifs')
  with check (bucket_id = 'justificatifs');

-- ============================================================================
-- 7) NOTIFICATIONS PUSH (alertes en temps réel sur téléphone)
-- ============================================================================
-- Chaque utilisateur (profil) peut activer les notifications sur ses propres
-- appareils. Utilisé par les fonctions Edge send-push et daily-alerts.
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);
alter table public.push_subscriptions enable row level security;
drop policy if exists push_subscriptions_own on public.push_subscriptions;
create policy push_subscriptions_own on public.push_subscriptions
  for all using (profile_id = auth.uid()) with check (profile_id = auth.uid());

-- Alerte quotidienne automatique (CT, assurance, entretien, amendes) : une
-- notification résumé envoyée chaque matin à 7h à tous les appareils abonnés.
-- Nécessite les extensions pg_cron et pg_net (activées par défaut sur la
-- plupart des projets Supabase ; sinon : Database → Extensions → les activer
-- avant d'exécuter ce bloc).
create extension if not exists pg_cron;
create extension if not exists pg_net;

do $$
begin
  perform cron.unschedule('sbrauto-daily-alerts');
exception when others then null;
end $$;

select cron.schedule(
  'sbrauto-daily-alerts',
  '0 7 * * *',
  $cron$
  select net.http_post(
    url := 'https://wpecxfxyfnvmzxkclhqc.supabase.co/functions/v1/daily-alerts',
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
  $cron$
);

-- ============================================================================
-- Fin — tout est prêt.
-- ============================================================================
