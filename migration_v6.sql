-- ============================================================
-- SBR AUTO — Migration v6
-- À exécuter UNE FOIS dans le SQL Editor, APRÈS les migrations
-- précédentes.
-- Ajoute : possibilité pour un prestataire de se désister d'une
-- mission acceptée (avant de la démarrer) — elle redevient
-- disponible pour les autres. L'admin peut de son côté annuler une
-- mission même après qu'elle a été acceptée/démarrée (déjà géré par
-- les policies existantes, seul le bouton manquait côté interface).
-- ============================================================

drop policy if exists "prestataire se desiste avant demarrage" on public.missions;
create policy "prestataire se desiste avant demarrage"
  on public.missions for update
  using (prestataire_id = auth.uid() and statut = 'acceptee')
  with check (statut = 'disponible' and prestataire_id is null);
