-- ============================================================
-- SBR CONVOYAGE — Schéma Supabase
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
  contrat_url text,              -- contrat cadre autorisant le prestataire à travailler avec SBR CONVOYAGE
  contrat_ajoute_le timestamptz,
  contrat_statut text not null default 'non_envoye'
    check (contrat_statut in ('non_envoye', 'en_attente_signature', 'signe')),
  contrat_signature_url text,
  contrat_signe_le timestamptz,
  email text,
  en_attente_validation boolean not null default false,
  missions_acceptees_total integer not null default 0,
  missions_desistees_total integer not null default 0,
  missions_annulees_total integer not null default 0,
  siret text,
  statut_juridique text,
  nom_societe text,
  site_web text,
  doc_kbis_path text,
  doc_assurance_path text,
  doc_cni_path text,
  doc_permis_path text,
  adresse text,
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
  relance_envoyee_le timestamptz,
  paye boolean not null default false,
  paye_le timestamptz,
  nom_client text,
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

-- Un utilisateur qui vient de s'inscrire peut créer SA propre ligne de
-- profil, uniquement en tant que prestataire, désactivé et en attente
-- de validation — impossible de s'auto-promouvoir admin
create policy "auto-inscription prestataire"
  on public.profiles for insert
  with check (
    id = auth.uid()
    and role = 'prestataire'
    and actif = false
    and en_attente_validation = true
  );

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

-- Le prestataire peut se désister d'une mission acceptée avant de la
-- démarrer : elle redevient disponible pour les autres
create policy "prestataire se desiste avant demarrage"
  on public.missions for update
  using (prestataire_id = auth.uid() and statut = 'acceptee')
  with check (statut = 'disponible' and prestataire_id is null);

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

-- 12) Paramètres de l'entreprise (une seule ligne, id = 1)
create table public.entreprise_config (
  id integer primary key default 1,
  nom text,
  adresse text,
  forme_juridique text,
  siret text,
  signature_url text,
  updated_at timestamptz default now()
);

alter table public.entreprise_config enable row level security;

create policy "lecture entreprise_config"
  on public.entreprise_config for select
  using (auth.uid() is not null);

create policy "admin gere entreprise_config"
  on public.entreprise_config for all
  using (public.is_admin())
  with check (public.is_admin());

-- 13) Stockage des images de signature (société + prestataires)
insert into storage.buckets (id, name, public)
values ('signatures', 'signatures', true)
on conflict (id) do nothing;

create policy "lecture publique signatures"
  on storage.objects for select
  using (bucket_id = 'signatures');

create policy "upload signatures utilisateurs connectes"
  on storage.objects for insert
  with check (bucket_id = 'signatures' and auth.uid() is not null);

-- 14) Fonction sécurisée : le prestataire signe SON contrat cadre,
-- sans pouvoir toucher aux autres champs de son profil (rôle, actif...)
create or replace function public.signer_contrat_cadre(p_contrat_url text, p_signature_url text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set contrat_url = p_contrat_url,
      contrat_statut = 'signe',
      contrat_signature_url = p_signature_url,
      contrat_signe_le = now()
  where id = auth.uid() and role = 'prestataire';
end;
$$;

grant execute on function public.signer_contrat_cadre(text, text) to authenticated;

-- 16) Documents prestataire (Kbis, assurance pro, CNI, permis) —
-- bucket PRIVÉ, jamais public (pièces d'identité)
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

create policy "upload documents proprietaire"
  on storage.objects for insert
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "lecture documents proprietaire ou admin"
  on storage.objects for select
  using (
    bucket_id = 'documents'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );

create or replace function public.update_mes_documents_prestataire(
  p_nom_societe text,
  p_site_web text,
  p_doc_kbis_path text,
  p_doc_assurance_path text,
  p_doc_cni_path text,
  p_doc_permis_path text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set nom_societe = p_nom_societe,
      site_web = p_site_web,
      doc_kbis_path = coalesce(p_doc_kbis_path, doc_kbis_path),
      doc_assurance_path = coalesce(p_doc_assurance_path, doc_assurance_path),
      doc_cni_path = coalesce(p_doc_cni_path, doc_cni_path),
      doc_permis_path = coalesce(p_doc_permis_path, doc_permis_path)
  where id = auth.uid() and role = 'prestataire';
end;
$$;

grant execute on function public.update_mes_documents_prestataire(text, text, text, text, text, text) to authenticated;

-- 15) Trigger qui tient à jour les compteurs de fiabilité des prestataires
-- (acceptées / désistées / annulées) à chaque changement de statut
create or replace function public.track_mission_stats()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if TG_OP = 'UPDATE' and OLD.statut = 'disponible' and NEW.statut = 'acceptee' and NEW.prestataire_id is not null then
    update public.profiles set missions_acceptees_total = missions_acceptees_total + 1 where id = NEW.prestataire_id;
  end if;

  if TG_OP = 'UPDATE' and OLD.statut = 'acceptee' and NEW.statut = 'disponible' and OLD.prestataire_id is not null then
    update public.profiles set missions_desistees_total = missions_desistees_total + 1 where id = OLD.prestataire_id;
  end if;

  if TG_OP = 'UPDATE' and NEW.statut = 'annulee' and OLD.statut in ('acceptee', 'en_cours') and OLD.prestataire_id is not null then
    update public.profiles set missions_annulees_total = missions_annulees_total + 1 where id = OLD.prestataire_id;
  end if;

  return NEW;
end;
$$;

create trigger missions_stats_trigger
  after update on public.missions
  for each row execute function public.track_mission_stats();

-- 17) Résultats de vérification IA des documents prestataire
create table public.document_verifications (
  id uuid primary key default gen_random_uuid(),
  prestataire_id uuid not null references public.profiles(id) on delete cascade,
  doc_type text not null check (doc_type in ('kbis', 'assurance', 'cni', 'permis')),
  statut text not null default 'a_verifier' check (statut in ('conforme', 'a_verifier', 'suspect')),
  commentaire text,
  verifie_le timestamptz not null default now(),
  unique (prestataire_id, doc_type)
);

alter table public.document_verifications enable row level security;

create policy "lecture document_verifications"
  on public.document_verifications for select
  using (public.is_admin() or prestataire_id = auth.uid());

create policy "service role ecrit document_verifications"
  on public.document_verifications for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- 18) Ajouts migration v13 : RGPD, expiration assurance, push,
-- historique contrats, suivi + signature client public
-- 1) Consentement RGPD à l'inscription
alter table public.profiles
  add column if not exists rgpd_consentement boolean not null default false,
  add column if not exists rgpd_consentement_le timestamptz;

-- 2) Date de validité de l'assurance pro (pour l'alerte d'expiration)
alter table public.profiles
  add column if not exists assurance_validite_le date;

-- La fonction update_mes_documents_prestataire (migration v10) doit
-- accepter ce nouveau champ : on la supprime et la recrée avec le
-- paramètre en plus
drop function if exists public.update_mes_documents_prestataire(text, text, text, text, text, text);
create or replace function public.update_mes_documents_prestataire(
  p_nom_societe text,
  p_site_web text,
  p_doc_kbis_path text,
  p_doc_assurance_path text,
  p_doc_cni_path text,
  p_doc_permis_path text,
  p_assurance_validite_le date default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set nom_societe = p_nom_societe,
      site_web = p_site_web,
      doc_kbis_path = coalesce(p_doc_kbis_path, doc_kbis_path),
      doc_assurance_path = coalesce(p_doc_assurance_path, doc_assurance_path),
      doc_cni_path = coalesce(p_doc_cni_path, doc_cni_path),
      doc_permis_path = coalesce(p_doc_permis_path, doc_permis_path),
      assurance_validite_le = coalesce(p_assurance_validite_le, assurance_validite_le)
  where id = auth.uid() and role = 'prestataire';
end;
$$;

grant execute on function public.update_mes_documents_prestataire(text, text, text, text, text, text, date) to authenticated;

-- 3) Notifications push (web push standard, sans dépendance propriétaire)
create table if not exists public.push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

alter table public.push_subscriptions enable row level security;

drop policy if exists "gestion de ses propres abonnements push" on public.push_subscriptions;
create policy "gestion de ses propres abonnements push"
  on public.push_subscriptions for all
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid());

-- 4) Historique des versions de contrat cadre (au lieu d'écraser à chaque fois)
create table if not exists public.contrats_historique (
  id uuid primary key default gen_random_uuid(),
  prestataire_id uuid not null references public.profiles(id) on delete cascade,
  contrat_url text not null,
  statut text not null,
  cree_le timestamptz not null default now()
);

alter table public.contrats_historique enable row level security;

drop policy if exists "lecture contrats_historique" on public.contrats_historique;
create policy "lecture contrats_historique"
  on public.contrats_historique for select
  using (public.is_admin() or prestataire_id = auth.uid());

drop policy if exists "ecriture contrats_historique" on public.contrats_historique;
create policy "ecriture contrats_historique"
  on public.contrats_historique for insert
  with check (prestataire_id = auth.uid() or public.is_admin());

-- 5) Suivi + signature client public par mission (sans compte)
alter table public.missions
  add column if not exists suivi_token uuid not null default gen_random_uuid(),
  add column if not exists client_signature_url text,
  add column if not exists client_nom_signataire text,
  add column if not exists client_signe_le timestamptz;

-- Un visiteur anonyme ne doit JAMAIS pouvoir lister les missions. On passe
-- donc par une fonction dédiée plutôt que par une policy SELECT publique
-- (une policy ne peut pas restreindre "uniquement si le bon jeton est
-- fourni" — elle s'applique à toute lecture, y compris un listing complet
-- via l'API si elle était mal écrite). Cette fonction ne renvoie qu'UNE
-- mission, et seulement les colonnes utiles au suivi/à la signature —
-- jamais le prix, les coordonnées internes ou les autres missions.
create or replace function public.get_mission_pour_suivi(p_suivi_token uuid)
returns table (
  id uuid,
  type text,
  titre text,
  vehicule text,
  lieu_depart text,
  lieu_arrivee text,
  date_prevue timestamptz,
  date_arrivee_prevue timestamptz,
  statut text,
  prestataire_nom text,
  client_signe_le timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select m.id, m.type, m.titre, m.vehicule, m.lieu_depart, m.lieu_arrivee,
         m.date_prevue, m.date_arrivee_prevue, m.statut,
         p.nom as prestataire_nom, m.client_signe_le
  from public.missions m
  left join public.profiles p on p.id = m.prestataire_id
  where m.suivi_token = p_suivi_token;
$$;

grant execute on function public.get_mission_pour_suivi(uuid) to anon, authenticated;

-- Fonction sécurisée : le client signe à la livraison (aucune authentification,
-- mais restreinte à UNE mission désignée par son jeton, et seulement si elle
-- n'est pas déjà signée)
create or replace function public.signer_mission_client(
  p_suivi_token uuid,
  p_signature_url text,
  p_nom_signataire text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.missions
  set client_signature_url = p_signature_url,
      client_nom_signataire = p_nom_signataire,
      client_signe_le = now()
  where suivi_token = p_suivi_token
    and client_signe_le is null;
end;
$$;

grant execute on function public.signer_mission_client(uuid, text, text) to anon, authenticated;

-- Autorise en plus l'upload SANS authentification, mais uniquement dans
-- un dossier dédié "client-signatures/" (le client final n'a pas de
-- compte) — n'affecte pas la policy existante pour les utilisateurs
-- connectés, qui reste inchangée
drop policy if exists "upload signature client sans authentification" on storage.objects;
create policy "upload signature client sans authentification"
  on storage.objects for insert
  with check (bucket_id = 'signatures' and (storage.foldername(name))[1] = 'client-signatures');

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
-- Va aussi dans admin.html > "Paramètres entreprise" pour renseigner
-- le nom, l'adresse et la signature de ta société (nécessaire pour
-- générer les contrats).
-- ============================================================
