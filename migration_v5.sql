-- ============================================================
-- SBR AUTO — Migration v5
-- À exécuter UNE FOIS dans le SQL Editor, APRÈS les migrations
-- précédentes (v2, v3, v4).
-- Ajoute : paramètres entreprise (nom, adresse, signature),
-- statut de signature du contrat cadre, fonction sécurisée
-- permettant au prestataire de signer sans pouvoir modifier
-- d'autres champs de son profil.
-- ============================================================

-- 1) Paramètres de l'entreprise (une seule ligne, id = 1)
create table if not exists public.entreprise_config (
  id integer primary key default 1,
  nom text,
  adresse text,
  signature_url text,
  updated_at timestamptz default now()
);

alter table public.entreprise_config enable row level security;

drop policy if exists "lecture entreprise_config" on public.entreprise_config;
create policy "lecture entreprise_config"
  on public.entreprise_config for select
  using (auth.uid() is not null);

drop policy if exists "admin gere entreprise_config" on public.entreprise_config;
create policy "admin gere entreprise_config"
  on public.entreprise_config for all
  using (public.is_admin())
  with check (public.is_admin());

-- 2) Statut de signature sur le contrat cadre du prestataire
alter table public.profiles
  add column if not exists contrat_statut text not null default 'non_envoye'
    check (contrat_statut in ('non_envoye', 'en_attente_signature', 'signe')),
  add column if not exists contrat_signature_url text,
  add column if not exists contrat_signe_le timestamptz;

-- 3) Bucket de stockage des images de signature (société + prestataires)
insert into storage.buckets (id, name, public)
values ('signatures', 'signatures', true)
on conflict (id) do nothing;

drop policy if exists "lecture publique signatures" on storage.objects;
create policy "lecture publique signatures"
  on storage.objects for select
  using (bucket_id = 'signatures');

drop policy if exists "upload signatures utilisateurs connectes" on storage.objects;
create policy "upload signatures utilisateurs connectes"
  on storage.objects for insert
  with check (bucket_id = 'signatures' and auth.uid() is not null);

-- 4) Fonction sécurisée : le prestataire signe SON contrat cadre.
-- Volontairement une fonction dédiée (plutôt qu'une policy UPDATE
-- large sur profiles) pour qu'un prestataire ne puisse modifier QUE
-- ces trois champs sur SA propre ligne, jamais son rôle, son statut
-- actif, ou ses spécialités.
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
