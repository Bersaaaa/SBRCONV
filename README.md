# SBR AUTO — Missions & prestataires

Site pour publier des missions (convoyage, nettoyage, inspection) que tes
prestataires acceptent depuis leur compte. Prix saisis en HT ; toi seul (admin)
peux basculer l'affichage en TTC. Les prestataires ne voient que le HT.

À l'acceptation, chaque mission suit ce cycle, piloté par le prestataire :
**Disponible → (accepte) Acceptée → (état des lieux avant) En cours →
(état des lieux après) Terminée**. C'est le prestataire qui démarre et
clôture la mission — pas toi — avec un état des lieux (kilométrage,
carburant, état extérieur/intérieur, commentaire, photos) à chaque étape.
Tu peux consulter ces états des lieux depuis ton tableau de bord admin.

## 1. Créer le projet Supabase

**Nouvelle installation ?** Va sur supabase.com → New project (dédié à SBR AUTO,
distinct des 3 autres), ouvre le **SQL Editor**, colle le contenu de
`schema.sql`, exécute. Il contient déjà tout (spécialités, factures, etc.).

**Tu as déjà un projet Supabase pour ce site (installé avant le 14/09) ?**
N'exécute PAS `schema.sql` à nouveau (ça créerait des doublons). Ouvre plutôt
le SQL Editor et exécute, dans l'ordre, uniquement les migrations que tu n'as
pas encore passées :
1. `migration_v2.sql` (spécialités prestataires, factures) — si pas encore fait.
2. `migration_v3.sql` (notation des prestataires, contrats PDF automatiques) — si pas encore fait.
3. `migration_v4.sql` (contrat cadre par prestataire, date d'arrivée pour les convoyages).

Ensuite dans les deux cas :
1. Va dans **Project Settings → API** : copie `Project URL` et `anon public key`.
2. Colle-les dans `config.js` (`SUPABASE_URL` et `SUPABASE_ANON_KEY`).

## 2. Créer ton compte admin

1. Dans le dashboard Supabase → **Authentication → Users → Add user**, crée un
   utilisateur avec ton email et un mot de passe.
2. Copie son `UID`.
3. Dans **Table Editor → profiles**, ajoute une ligne :
   `id = <UID copié>`, `role = admin`, `nom = ton nom`, `actif = true`.

## 3. Créer un compte prestataire

Même procédure : **Authentication → Users → Add user**, puis une ligne dans
`profiles` avec `role = prestataire`. Communique-lui l'email + mot de passe
(tu peux les changer plus tard depuis le dashboard Supabase).

Pour désactiver un prestataire sans supprimer son historique : coche/décoche
"Actif" depuis le panneau **Prestataires** dans `admin.html` (ou directement
dans Supabase, `actif = false` sur sa ligne `profiles`) — il ne pourra plus
se connecter.

### Spécialités des prestataires

Chaque prestataire n'a accès qu'aux missions disponibles correspondant à
ses spécialités. Depuis `admin.html`, clique sur **"Prestataires"** en haut :
tu y coches Convoyage / Nettoyage / Inspection / Autre pour chacun, et
"Enregistrer". Un prestataire sans aucune spécialité cochée ne verra aucune
mission disponible.

### Contrat cadre (autorisation à travailler avec toi)

C'est différent du contrat de mission (généré automatiquement à chaque
acceptation) : ici c'est le contrat général qui autorise un prestataire à
travailler avec SBR AUTO. Dans le panneau **Prestataires**, bouton "Ajouter
le contrat" sur sa ligne → tu déposes le PDF (signé par ailleurs, papier
scanné ou signature électronique externe). Il reste ensuite consultable
depuis cette même ligne, côté admin uniquement.

## 4. Déployer le site

Le site est 100% statique (pas de build). Le plus simple :
- Sur vercel.com → New Project → glisse le dossier `sbr-missions`
  (comme tes autres apps sbrauto.vercel.app / sbrcompta.vercel.app).
- Ou Netlify Drop (netlify.com/drop) pour un déploiement en 10 secondes.

## 5. Notifications par email (optionnel)

Deux emails automatiques sont disponibles : au prestataire quand une
mission correspondant à sa spécialité est publiée, et à toi quand une
mission est acceptée. Ça demande un peu plus de configuration que le
reste du site (une fonction serveur + un service d'envoi d'email) — tu
peux tout à fait déployer le site sans ça et l'ajouter plus tard.

1. **Installe la CLI Supabase** si tu ne l'as pas déjà (tu l'as sûrement
   pour SBRHUB / le module Mécano) : `npm install -g supabase`.
2. Dans le dossier `sbr-missions`, connecte-toi à ton projet :
   `supabase login` puis `supabase link --project-ref <ton-project-ref>`
   (le ref est dans Project Settings → General).
3. Déploie la fonction : `supabase functions deploy notify-mission`.
4. Crée un compte sur **resend.com** (gratuit, jusqu'à 3000 emails/mois),
   récupère une clé API.
5. Configure les secrets de la fonction :
   `supabase secrets set RESEND_API_KEY=ta_cle_resend`
   `supabase secrets set RESEND_FROM="SBR AUTO <onboarding@resend.dev>"`
   (remplace par ton propre domaine vérifié sur Resend quand tu en as un —
   `onboarding@resend.dev` fonctionne pour tester).
6. Dans le Dashboard Supabase → **Database → Webhooks → Create a new hook** :
   - Nom : `notify-mission-insert` — Table : `missions` — Events : `Insert`
     — Type : `Supabase Edge Functions` — Function : `notify-mission`.
   - Recrée un second webhook identique avec Events : `Update` (pour
     détecter l'acceptation d'une mission).

La fonction elle-même sait faire le tri (nouvelle mission vs. mission
acceptée) à partir de ce qui a changé — pas besoin de filtrer côté
webhook.

## Fonctionnement

- **Toi (admin)** : `admin.html` — tu crées les missions. Le formulaire
  s'adapte au type choisi :
  - **Convoyage** : lieu de départ + lieu d'arrivée, date de départ prévue
    + date d'arrivée prévue.
  - **Nettoyage / Inspection** : un seul champ "Lieu" (pas de lieu de
    retour) + une seule date.
  - **Autre** : lieu de départ + lieu d'arrivée, une seule date.
  La case "Appliquer la TVA" est **décochée par défaut** (vous ne facturez
  pas la TVA actuellement) — coche-la uniquement sur les missions où tu
  factures la TVA ; le taux ne s'affiche que si la case est cochée.
  Tu vois tout en 3 colonnes : Disponibles / En cours / Clôturées. Un
  interrupteur en haut à droite bascule l'affichage HT ↔ TTC pour toi
  (calcul automatique : prix HT × (1 + taux TVA)) ; les prestataires ne
  voient eux que le HT. Sur chaque mission en cours ou clôturée, un bouton
  "État des lieux" t'affiche ce que le prestataire a renseigné avant et
  après, photos cliquables pour les voir en grand.
- **Factures** : sur une mission "Terminée", un bouton "Ajouter facture" te
  permet de saisir un numéro de facture et/ou déposer le PDF. Une fois
  ajoutée, le bouton devient "Voir facture" et l'ouvre dans un nouvel
  onglet.
- **Contrat automatique** : dès qu'un prestataire accepte une mission, un
  PDF de contrat est généré automatiquement dans son navigateur (mission,
  véhicule, prix, conditions) et déposé dans le bucket `contrats`. Toi et
  le prestataire pouvez l'ouvrir depuis la carte de la mission ("Contrat
  (PDF)" / "Voir mon contrat"). Aucune action de ta part n'est nécessaire.
- **Notation des prestataires** : sur une mission "Terminée", bouton
  "Noter" → 1 à 5 étoiles + commentaire libre. La moyenne de chaque
  prestataire (et le nombre de missions notées) s'affiche dans le panneau
  **Prestataires**.
- **Prestataires** : `prestataire.html` — ils ne voient que les missions
  disponibles dans leurs spécialités (prix HT uniquement) et cliquent
  "Accepter". Dès qu'une mission est prise, elle disparaît pour les autres
  (protection intégrée en base contre le double-clic de deux prestataires
  en même temps). Ensuite, c'est à eux de gérer le cycle de la mission :
  - **Démarrer** → formulaire d'état des lieux "avant" (kilométrage,
    carburant, état extérieur/intérieur, commentaire, photos) → la mission
    passe en "En cours".
  - **Clôturer** → même formulaire côté "après" → la mission passe en
    "Terminée".
- Tout le monde arrive par `index.html` (connexion), qui redirige
  automatiquement vers le bon espace selon le rôle.
- Les photos d'état des lieux sont stockées dans le bucket Supabase Storage
  `etats-lieux`, les factures PDF dans `factures`, et les contrats générés
  automatiquement dans `contrats`.

## Idées pour la suite

- Email de notification quand une facture ou un contrat est ajouté (en plus
  de la nouvelle mission / mission acceptée déjà en place).
- Génération automatique du PDF de facture (au lieu de le déposer toi-même)
  à partir des infos de la mission, sur le même principe que le contrat.
- Export comptable des missions clôturées + factures (lien possible avec
  SBR COMPTA).
- Auto-inscription des prestataires avec validation admin (aujourd'hui :
  création manuelle par toi dans Supabase).
- Relances automatiques si une mission "disponible" reste longtemps sans
  prestataire.
- Signature électronique du contrat par le prestataire (au-delà de
  l'acceptation en un clic).
