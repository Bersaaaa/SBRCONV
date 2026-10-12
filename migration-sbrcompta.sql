-- ============================================================
-- MIGRATION : ajout des tables SBR COMPTA dans la base SBRAUTO
-- À coller dans : Supabase Dashboard du projet SBRAUTO
-- (wpecxfxyfnvmzxkclhqc) > SQL Editor > New query > Run
-- Sûr à rejouer plusieurs fois (tout est en "if not exists").
-- Aucune collision de nom de table avec le schéma SBRAUTO existant.
-- auth.users est déjà partagé (même compte de connexion pour les
-- deux volets Location/Compta de l'app fusionnée).
-- ============================================================


-- ---------- TRANSACTIONS (recettes / dépenses / rémunération) ----------
create table if not exists public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  libelle text not null,
  montant numeric(12,2) not null,
  type text not null check (type in ('recette','depense','prelevement')),
  categorie text,
  justificatif text, -- chemin dans le bucket "justificatifs" (ou data URL en mode local)
  statut_rapprochement text default 'manuel',
  pointe boolean not null default false,
  cotisations_prelevees boolean not null default false,
  deleted boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now()
);
alter table public.transactions add column if not exists pointe boolean not null default false;
alter table public.transactions add column if not exists cotisations_prelevees boolean not null default false;
alter table public.transactions add column if not exists deleted boolean not null default false;
alter table public.transactions add column if not exists deleted_at timestamptz;
-- ---------- Module TVA (ROOT IA) ----------
alter table public.transactions add column if not exists fournisseur text;
alter table public.transactions add column if not exists siret text;
alter table public.transactions add column if not exists numero_facture text;
alter table public.transactions add column if not exists montant_ht numeric(12,2);
alter table public.transactions add column if not exists taux_tva numeric(5,2);
alter table public.transactions add column if not exists montant_tva numeric(12,2);
alter table public.transactions add column if not exists montant_ttc numeric(12,2);
alter table public.transactions add column if not exists tva_deductible numeric(12,2);
alter table public.transactions add column if not exists tva_non_deductible numeric(12,2);
alter table public.transactions add column if not exists ia_justification text;
alter table public.transactions add column if not exists ia_source text;
alter table public.transactions add column if not exists ia_confiance text; -- 'elevee' | 'moyenne' | 'faible'
alter table public.transactions add column if not exists verification_necessaire boolean not null default false;
alter table public.transactions add column if not exists tva_verifiee boolean not null default false;
alter table public.transactions add column if not exists tva_modifie_manuel boolean not null default false;

create index if not exists transactions_user_date_idx on public.transactions(user_id, date desc);
create index if not exists transactions_user_type_idx on public.transactions(user_id, type);
create index if not exists transactions_user_deleted_idx on public.transactions(user_id, deleted);

-- ---------- DÉCLARATIONS URSSAF ----------
create table if not exists public.declarations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  periode text not null, -- ex: "2026-T3" ou "2026-08"
  statut_declare boolean not null default false,
  statut_paye boolean not null default false,
  date_declare date,
  date_paye date,
  reference text, -- numéro de référence du paiement URSSAF, pour rapprochement auto
  unique (user_id, periode)
);
alter table public.declarations add column if not exists reference text;
create index if not exists declarations_user_idx on public.declarations(user_id);

-- ---------- RÈGLES DE CATÉGORISATION AUTOMATIQUE ----------
create table if not exists public.rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  motcle text not null,
  type text not null check (type in ('recette','depense','prelevement')),
  categorie text not null
);
create index if not exists rules_user_idx on public.rules(user_id);

-- SBR CARTE GRISE a été retirée : SBR COMPTA ne suit plus qu'une seule activité
-- (SBR AUTO), donc la notion d'"activité" par écriture/règle n'a plus lieu d'être.
alter table public.rules drop column if exists entite;
alter table public.transactions drop constraint if exists transactions_entite_check;
alter table public.transactions drop column if exists entite;

-- apport personnel : argent remis par toi sur le compte pro, hors CA et non déclaré à l'URSSAF
-- (nouveau type 'apport', à côté de recette / dépense / prélèvement)
alter table public.transactions drop constraint if exists transactions_type_check;
alter table public.transactions add constraint transactions_type_check
  check (type in ('recette','depense','prelevement','apport'));
alter table public.rules drop constraint if exists rules_type_check;
alter table public.rules add constraint rules_type_check
  check (type in ('recette','depense','prelevement','apport'));

-- ---------- RÉGLAGES (une ligne par utilisateur) ----------
create table if not exists public.settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  periodicite text not null default 'trimestriel',
  taux_service numeric(5,2) not null default 21.2,
  taux_vente numeric(5,2) not null default 12.3,
  taux_cfp_service numeric(5,2) not null default 0.2,
  taux_cfp_vente numeric(5,2) not null default 0.1,
  versement_liberatoire_actif boolean not null default false,
  taux_vl_service numeric(5,2) not null default 1.7,
  taux_vl_vente numeric(5,2) not null default 1.0,
  tva_actif boolean not null default false
);
alter table public.settings add column if not exists tva_actif boolean not null default false;

-- ---------- NOTIFICATIONS ----------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null default 'info', -- 'urssaf' | 'info'
  ref_id text, -- pour éviter les doublons de notification
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_unread_idx on public.notifications(user_id, read, created_at desc);
create index if not exists notifications_ref_idx on public.notifications(user_id, ref_id);

-- ============================================================
-- ROW LEVEL SECURITY — chacun ne voit/modifie que ses propres données
-- ============================================================
alter table public.transactions enable row level security;
alter table public.declarations enable row level security;
alter table public.rules enable row level security;
alter table public.settings enable row level security;
alter table public.notifications enable row level security;

-- Crée les policies "CRUD only own rows" pour chaque table, sans erreur si elles existent déjà
do $$
declare t text;
begin
  foreach t in array array['transactions','declarations','rules','notifications']
  loop
    if not exists (select 1 from pg_policies where schemaname='public' and tablename=t and policyname='select own') then
      execute format('create policy "select own" on public.%I for select using (auth.uid() = user_id)', t);
    end if;
    if not exists (select 1 from pg_policies where schemaname='public' and tablename=t and policyname='insert own') then
      execute format('create policy "insert own" on public.%I for insert with check (auth.uid() = user_id)', t);
    end if;
    if not exists (select 1 from pg_policies where schemaname='public' and tablename=t and policyname='update own') then
      execute format('create policy "update own" on public.%I for update using (auth.uid() = user_id)', t);
    end if;
    if not exists (select 1 from pg_policies where schemaname='public' and tablename=t and policyname='delete own') then
      execute format('create policy "delete own" on public.%I for delete using (auth.uid() = user_id)', t);
    end if;
  end loop;

  if not exists (select 1 from pg_policies where schemaname='public' and tablename='settings' and policyname='select own settings') then
    create policy "select own settings" on public.settings for select using (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='settings' and policyname='insert own settings') then
    create policy "insert own settings" on public.settings for insert with check (auth.uid() = user_id);
  end if;
  if not exists (select 1 from pg_policies where schemaname='public' and tablename='settings' and policyname='update own settings') then
    create policy "update own settings" on public.settings for update using (auth.uid() = user_id);
  end if;
end $$;

-- ============================================================
-- REALTIME — pour que la cloche 🔔 reçoive les notifications en direct
-- ============================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public' and tablename='notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- ============================================================
-- STOCKAGE des justificatifs (photos/PDF)
-- ============================================================
insert into storage.buckets (id, name, public)
values ('justificatifs', 'justificatifs', false)
on conflict (id) do nothing;

do $$
begin
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='select own justificatifs') then
    create policy "select own justificatifs" on storage.objects for select
      using (bucket_id = 'justificatifs' and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='insert own justificatifs') then
    create policy "insert own justificatifs" on storage.objects for insert
      with check (bucket_id = 'justificatifs' and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
  if not exists (select 1 from pg_policies where schemaname='storage' and tablename='objects' and policyname='delete own justificatifs') then
    create policy "delete own justificatifs" on storage.objects for delete
      using (bucket_id = 'justificatifs' and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
end $$;

-- ============================================================
-- NOTES
-- ============================================================
-- 1. Active "Email confirmations" dans Authentication > Providers > Email
--    selon si tu veux forcer la confirmation par email à l'inscription.
-- 2. L'URL et la clé "anon public" du projet sont déjà codées en dur dans
--    index.html (SUPABASE_URL / SUPABASE_ANON_KEY) — rien à configurer dans l'app.
-- 3. Pour ROOT IA (classification à l'import, module TVA et assistant), une Edge
--    Function est fournie : root-ia-edge-function.ts, à déployer/redéployer depuis
--    le dashboard Supabase (Edge Functions > Deploy a new function) à chaque mise
--    à jour de ce fichier. Le module TVA envoie en plus une image/un PDF et active
--    la recherche web (impots.gouv.fr, BOFiP, Légifrance, service-public.fr) pour
--    déterminer la déductibilité. Aucun email n'est envoyé par l'app,
--    les rappels URSSAF arrivent dans la cloche de l'application.
-- 4. Ce fichier ne crée QUE les tables utilisées par l'app actuelle
--    (pas de véhicules/dossiers/échéances — modules retirés pour rester simple).
