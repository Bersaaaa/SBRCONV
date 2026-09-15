-- ============================================================
-- SBR CONVOYAGE — Migration v10
-- À exécuter UNE FOIS dans le SQL Editor, APRÈS les migrations
-- précédentes (v2 à v9).
-- Ajoute : nom de société / site web du prestataire, et upload de
-- documents (Kbis, assurance pro, CNI, permis) dans un bucket PRIVÉ
-- (contrairement aux autres buckets du projet, celui-ci n'est PAS
-- public : ce sont des pièces d'identité).
-- ============================================================

-- 1) Informations complémentaires sur le prestataire
alter table public.profiles
  add column if not exists nom_societe text,
  add column if not exists site_web text,
  add column if not exists doc_kbis_path text,
  add column if not exists doc_assurance_path text,
  add column if not exists doc_cni_path text,
  add column if not exists doc_permis_path text;

-- 2) Bucket PRIVÉ pour les documents (public = false)
insert into storage.buckets (id, name, public)
values ('documents', 'documents', false)
on conflict (id) do nothing;

-- Convention de chemin : "<uid-du-prestataire>/nom-du-fichier.pdf"
-- Upload : uniquement dans son propre dossier
drop policy if exists "upload documents proprietaire" on storage.objects;
create policy "upload documents proprietaire"
  on storage.objects for insert
  with check (
    bucket_id = 'documents'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Lecture : le propriétaire du dossier, ou l'admin (jamais public)
drop policy if exists "lecture documents proprietaire ou admin" on storage.objects;
create policy "lecture documents proprietaire ou admin"
  on storage.objects for select
  using (
    bucket_id = 'documents'
    and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin())
  );

-- 3) Fonction sécurisée : le prestataire met à jour SES infos et
-- chemins de documents (jamais son rôle, son statut actif, etc.)
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
