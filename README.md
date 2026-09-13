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

1. Va sur supabase.com → New project (dédié à SBR MISSIONS, distinct des 3 autres).
2. Une fois créé, ouvre le **SQL Editor** et colle le contenu de `schema.sql`, puis exécute.
3. Va dans **Project Settings → API** : copie `Project URL` et `anon public key`.
4. Colle-les dans `config.js` (`SUPABASE_URL` et `SUPABASE_ANON_KEY`).

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

Pour désactiver un prestataire sans supprimer son historique : passe
`actif = false` sur sa ligne `profiles` — il ne pourra plus se connecter.

## 4. Déployer le site

Le site est 100% statique (pas de build). Le plus simple :
- Sur vercel.com → New Project → glisse le dossier `sbr-missions`
  (comme tes autres apps sbrauto.vercel.app / sbrcompta.vercel.app).
- Ou Netlify Drop (netlify.com/drop) pour un déploiement en 10 secondes.

## Fonctionnement

- **Toi (admin)** : `admin.html` — tu crées les missions (type, véhicule,
  lieux, date, prix HT, taux TVA). Tu vois tout en 3 colonnes : Disponibles /
  En cours / Clôturées. Un interrupteur en haut à droite bascule l'affichage
  HT ↔ TTC (calcul automatique : prix HT × (1 + taux TVA)). Sur chaque
  mission en cours ou clôturée, un bouton "État des lieux" t'affiche ce que
  le prestataire a renseigné avant et après.
- **Prestataires** : `prestataire.html` — ils voient les missions disponibles
  (prix HT uniquement) et cliquent "Accepter". Dès qu'une mission est prise,
  elle disparaît pour les autres (protection intégrée en base contre le
  double-clic de deux prestataires en même temps). Ensuite, c'est à eux de
  gérer le cycle de la mission :
  - **Démarrer** → formulaire d'état des lieux "avant" (kilométrage,
    carburant, état extérieur/intérieur, commentaire, photos) → la mission
    passe en "En cours".
  - **Clôturer** → même formulaire côté "après" → la mission passe en
    "Terminée".
- Tout le monde arrive par `index.html` (connexion), qui redirige
  automatiquement vers le bon espace selon le rôle.
- Les photos d'état des lieux sont stockées dans un bucket Supabase Storage
  `etats-lieux`, créé automatiquement par `schema.sql`.

## Pistes d'évolution (pas encore développées)

- Notifications email/SMS quand une nouvelle mission est publiée.
- Export comptable des missions clôturées (lien possible avec SBR COMPTA).
- Auto-inscription des prestataires (aujourd'hui : création manuelle par toi).
