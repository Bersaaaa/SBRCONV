-- ============================================================
-- SBR CONVOYAGE — Migration v11
-- À exécuter UNE FOIS dans le SQL Editor, APRÈS les migrations
-- précédentes (v2 à v10).
-- Ajoute : table des résultats de vérification IA des documents
-- prestataire (voir fonction Edge "verify-document").
-- ============================================================

create table if not exists public.document_verifications (
  id uuid primary key default gen_random_uuid(),
  prestataire_id uuid not null references public.profiles(id) on delete cascade,
  doc_type text not null check (doc_type in ('kbis', 'assurance', 'cni', 'permis')),
  statut text not null default 'a_verifier' check (statut in ('conforme', 'a_verifier', 'suspect')),
  commentaire text,
  verifie_le timestamptz not null default now(),
  unique (prestataire_id, doc_type)
);

alter table public.document_verifications enable row level security;

-- Lecture : le prestataire concerné, ou l'admin
drop policy if exists "lecture document_verifications" on public.document_verifications;
create policy "lecture document_verifications"
  on public.document_verifications for select
  using (public.is_admin() or prestataire_id = auth.uid());

-- Écriture : réservée au rôle "service_role" (utilisé par la fonction
-- Edge avec la clé service — jamais par un utilisateur normal, même
-- admin, pour garantir que seul le résultat de l'IA y est écrit)
drop policy if exists "service role ecrit document_verifications" on public.document_verifications;
create policy "service role ecrit document_verifications"
  on public.document_verifications for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');
