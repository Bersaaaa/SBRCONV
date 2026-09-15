-- ============================================================
-- SBR AUTO — Migration v8
-- À exécuter UNE FOIS dans le SQL Editor, APRÈS les migrations
-- précédentes (v2 à v7).
-- Ajoute : compteurs pour le score de fiabilité (acceptées /
-- désistées / annulées), suivi payé/à payer par mission.
-- ============================================================

-- 1) Compteurs sur le profil, mis à jour automatiquement par un trigger
alter table public.profiles
  add column if not exists missions_acceptees_total integer not null default 0,
  add column if not exists missions_desistees_total integer not null default 0,
  add column if not exists missions_annulees_total integer not null default 0;

-- 2) Suivi du paiement par mission
alter table public.missions
  add column if not exists paye boolean not null default false,
  add column if not exists paye_le timestamptz;

-- 3) Trigger qui tient les compteurs à jour à chaque changement de statut
-- (SECURITY DEFINER : nécessaire pour que la mise à jour de "profiles"
-- fonctionne même quand c'est un prestataire, pas l'admin, qui déclenche
-- le changement sur "missions")
create or replace function public.track_mission_stats()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Acceptation : disponible -> acceptee
  if TG_OP = 'UPDATE' and OLD.statut = 'disponible' and NEW.statut = 'acceptee' and NEW.prestataire_id is not null then
    update public.profiles set missions_acceptees_total = missions_acceptees_total + 1 where id = NEW.prestataire_id;
  end if;

  -- Désistement avant démarrage : acceptee -> disponible
  if TG_OP = 'UPDATE' and OLD.statut = 'acceptee' and NEW.statut = 'disponible' and OLD.prestataire_id is not null then
    update public.profiles set missions_desistees_total = missions_desistees_total + 1 where id = OLD.prestataire_id;
  end if;

  -- Annulation par l'admin alors qu'un prestataire était déjà assigné
  if TG_OP = 'UPDATE' and NEW.statut = 'annulee' and OLD.statut in ('acceptee', 'en_cours') and OLD.prestataire_id is not null then
    update public.profiles set missions_annulees_total = missions_annulees_total + 1 where id = OLD.prestataire_id;
  end if;

  return NEW;
end;
$$;

drop trigger if exists missions_stats_trigger on public.missions;
create trigger missions_stats_trigger
  after update on public.missions
  for each row execute function public.track_mission_stats();
