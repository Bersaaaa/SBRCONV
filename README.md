# SBR AUTO — LITE (registre de gestion de flotte, usage interne)

Application interne de gestion de flotte : registres légaux, planning,
entretiens, amendes, rentabilité, exports comptables. **Sans site public de
réservation, sans contrats/états des lieux, sans paiement carte.**

```
SBRAUTO-LITE/
├── index.html          → l'application entière (un seul fichier)
├── schema.sql          → toute la base de données (un seul fichier à exécuter)
├── manifest.json        → réglages PWA (icône, nom, raccourcis)
├── sw.js                  → service worker (chargement rapide, résilience hors-ligne)
├── vercel.json              → pour que les liens sans ".html" marchent
├── icon-192.png, icon-512.png,
│   icon-512-maskable.png      → icônes de l'app (installation sur téléphone)
├── deploy.bat                   → double-clic pour envoyer les mises à jour vers GitHub
├── README.md                      → ce document
└── supabase/
    └── functions/
        ├── send-push/              → notifications push
        └── daily-alerts/           → résumé d'alertes chaque matin
```

---

## Redéployer de zéro (≈ 15 minutes)

### 1. Créer la base de données

1. Sur [supabase.com](https://supabase.com) → **New project**. Note le mot
   de passe de la base demandé à la création (tu n'en auras pas besoin au
   quotidien, garde-le de côté).
2. **SQL Editor** → **New query** → colle **tout** le contenu de
   `schema.sql` → **Run**. Crée toutes les tables et les règles de sécurité.
   Peut être relancé plus tard sans rien casser — toujours la même unique
   source à jour.

> Le schéma contient aussi quelques tables/colonnes liées à des
> fonctionnalités qui n'existent pas dans cette version LITE (contrats,
> caution, site vitrine). Elles ne gênent en rien : cette version ne les lit
> ni ne les écrit jamais. Rien à faire de particulier.

### 2. Créer ton compte

1. **Authentication → Sign In / Providers** : *Email* activé, et
   **"Allow new users to sign up" DÉSACTIVÉ** (sinon n'importe qui pourrait
   se créer un compte admin).
2. **Authentication → Users → Add user** : ton email + un mot de passe.
3. Copie son **User UID**, puis dans **SQL Editor** :
   ```sql
   insert into profiles (id, email, nom, role_label, is_admin, allowed_tabs)
   values ('TON-UUID', 'ton@email.com', 'Ton Nom', 'Gérant', true, array[]::text[])
   on conflict (id) do update
     set nom = excluded.nom, email = excluded.email,
         role_label = excluded.role_label, is_admin = excluded.is_admin;
   ```

### 3. Connecter l'application

1. **Project Settings → API** : copie la **Project URL** et la clé
   **anon public**.
2. Ouvre `index.html`, remplace en haut du `<script>` :
   ```js
   const SUPABASE_URL = "https://xxxxx.supabase.co";
   const SUPABASE_ANON_KEY = "eyJhbGciOi...";
   ```

### 4. Mettre en ligne (Vercel)

1. Sur [vercel.com](https://vercel.com), connecte GitHub et importe le
   dépôt contenant ces fichiers. Site statique détecté automatiquement,
   aucune configuration à toucher.
2. Chaque mise à jour poussée sur GitHub redéploie automatiquement.

> **Mets le dépôt GitHub en privé.** La clé Supabase (anon) est visible en
> clair dans `index.html` — normal, elle est conçue pour ça — mais autant
> limiter qui peut voir le code.

Sur téléphone : **Partager → Ajouter à l'écran d'accueil** pour installer
l'app avec son icône.

---

## Mettre à jour l'application

Remplace les fichiers modifiés dans GitHub, pousse — Vercel redéploie tout
seul, les données ne sont jamais touchées. Nouvelle colonne demandée ?
Relance `schema.sql` (toujours sans risque).

**Sans ligne de commande** : installe **[GitHub Desktop](https://desktop.github.com)**,
clone ton dépôt dedans. Ensuite : remplace les fichiers → GitHub Desktop →
**Commit to main** → **Push origin**.

**Avec `deploy.bat`** : à la racine de ton dépôt Git local, double-clique
dessus à chaque mise à jour (récupère automatiquement les changements faits
ailleurs avant d'envoyer les tiens, pour éviter les conflits).

### Fichiers obligatoires dans le dépôt GitHub

À la racine (pas dans un sous-dossier) :
- **`index.html`**, **`vercel.json`**, **`manifest.json`**
- **`icon-192.png`**, **`icon-512.png`**, **`icon-512-maskable.png`**
- **`sw.js`**

`schema.sql`, `deploy.bat`, `README.md` et `supabase/functions/**` peuvent
rester dans le dépôt sans problème (utile pour t'y retrouver), mais ne sont
jamais servis par le site lui-même.

---

## Ce que contient l'application

**Dashboard** — véhicules actifs, alertes triées par urgence et cliquables,
actions rapides, et la rentabilité du mois véhicule par véhicule.

**Rentabilité** — le cœur de l'app. Saisie manuelle mois par mois et
véhicule par véhicule : gains détaillés par plateforme (Getaround, Turo,
Roadstr, vente du véhicule, autres), dépenses détaillées (assurance, crédit, entretien,
réparation, pneus, carburant, nettoyage, amendes, parking, autres), décote
du mois. Comparaison entre véhicules, détail
par poste et taux d'occupation repris du Planning Véhicules.

**Planning Véhicules** — un statut par jour (Getaround/Turo/Roadstr/
Direct/Sinistre/libre).

**Planning Sièges & Accessoires** — même principe, une couleur par véhicule.

**Véhicules & Entretiens** — fiches repliables (CT, assurance, km, valeur,
carte grise, attestation d'assurance), carnet d'entretien exportable en PDF.

**Recherche Amende** — retrouve qui louait un véhicule à une date donnée.

**Corbeille** — toute suppression est réversible.

**Sauvegarde** (Paramètres) — export Excel complet de toutes tes données,
un onglet par registre. À faire une fois par mois.

**Comptes à accès restreint** — comptes qui ne voient que certains onglets
(comptable, employé...), restriction appliquée aussi côté base de données :

```sql
insert into profiles (id, email, nom, role_label, is_admin, allowed_tabs)
values ('UUID', 'comptable@exemple.com', 'Nom Prénom', 'Comptable', false,
  array['dashboard','rentabilite']);
```

Onglets disponibles : `dashboard`, `rentabilite`, `planningVeh`,
`planningSiege`, `vehicules`, `amendes`. Paramètres et Corbeille restent
réservés aux admins.

---

## En cas de problème

**L'app reste bloquée sur l'écran de connexion**
Vérifie les deux clés en haut de `index.html` (URL du type
`https://xxxxx.supabase.co`, rien après le `.co`).

**Une section reste vide ou affiche une erreur au chargement**
Relance `schema.sql` : il manque probablement une colonne récente.

**"Impossible de charger tes données" dès la connexion, à chaque fois**
Ce n'est pas forcément un problème réseau : ce message s'affiche aussi si le
JavaScript plante en cours de chargement (ex. appel à une fonction retirée
par erreur). Ouvre la console du navigateur (F12 → Console) pour voir
l'erreur exacte si ça se reproduit.

**Un bandeau orange indique des modifications en attente**
Connexion perdue. Repartira automatiquement au retour du réseau, ou via
le bouton « Réessayer ».

---

## Points de vigilance

- **Sauvegarde** : les données n'existent qu'à un seul endroit (Supabase).
  Bouton de sauvegarde complète dans Paramètres, une fois par mois.
- **Rentabilité** : les chiffres sont ceux que tu saisis, rien n'est
  calculé automatiquement à partir d'un autre registre. Ce module sert au
  pilotage, pas à la déclaration fiscale.
- **Tables d'archive** : les anciennes tables `recettes`, `achats`,
  `montant_splits` et `historique` restent dans Supabase (rien n'est
  effacé) mais l'app ne les lit plus.

---

## Notifications push (nouveau)

Comme sur SBR CARTE GRISE : de vraies alertes sur ton téléphone, même app
fermée — pas juste le badge iOS qui existait déjà.

**Deux types d'alertes :**
- **Temps réel** : dès qu'un jour de planning (véhicule ou siège) est modifié.
- **Résumé quotidien** (chaque matin à 7h) : contrôle technique, assurance ou
  entretien dépassé/proche, amendes en attente.

### À faire pour activer (≈ 10 min, une seule fois)

1. **Exécuter `schema.sql`** (SQL Editor → coller tout → Run). Ajoute la table
   `push_subscriptions` et programme l'alerte quotidienne. Si tu as une erreur
   sur `create extension pg_cron` ou `pg_net` : **Database → Extensions**,
   active-les manuellement, puis relance `schema.sql`.
2. **Déployer les 2 nouvelles fonctions** (Edge Functions → Deploy a new
   function → copier-coller le contenu de chaque fichier) :
   - `send-push`
   - `daily-alerts`
   Pour les deux : **Settings → désactive "Verify JWT"**.
3. **Ajouter les secrets** (Edge Functions → Secrets) :
   - `VAPID_PUBLIC_KEY` = `BPGSvrTbURiVV3SBQtrkvwIQTB7fl8_SufydrIskcLXgKLvrc-Xe3PCmveLv9LNXm6Hw_CHXyZo7w9OChU5uuDM`
   - `VAPID_PRIVATE_KEY` = `QVPrHsq9qsjmztC-dFqxXqxoC-PYf6a6L5fHv-Ih-cE`
   (déjà générées, propres à ce projet — ne pas les réutiliser ailleurs)
4. **Redéployer le site** avec les fichiers mis à jour (`index.html`, `sw.js`).
5. Dans l'app → **Paramètres → 🔔 Notifications** → **"Activer les
   notifications"**. Sur iPhone, le site doit déjà être installé sur l'écran
   d'accueil (sinon Apple ne propose même pas l'option).

### Qui reçoit quoi

Chaque utilisateur active les notifications pour lui-même, sur son propre
appareil (bouton dans Paramètres). Un compte connecté sur plusieurs
appareils peut activer les notifications sur chacun séparément. Toute la
famille de comptes (tous les profils, pas juste l'admin) peut s'abonner —
utile si plusieurs personnes gèrent la flotte au quotidien.

### Limite connue

Le résumé quotidien reprend une version simplifiée des alertes déjà visibles
dans l'app (CT, assurance, entretien, amendes) — il ne couvre pas les
alertes secondaires comme le kilométrage à mettre à jour ou les lignes
partagées non réparties, qui restent visibles uniquement dans le bandeau de
l'app à l'ouverture.
