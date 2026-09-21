-- ============================================================
-- SBR CONVOYAGE — Migration v13
-- À exécuter UNE FOIS, après les migrations précédentes (v2 à v12).
-- Regroupe plusieurs ajouts : consentement RGPD, expiration
-- d'assurance, notifications push, historique des contrats,
-- suivi + signature client public par mission.
-- ============================================================

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
