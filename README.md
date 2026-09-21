# SBR CONVOYAGE — Missions & prestataires

Site pour publier des missions (convoyage, nettoyage, inspection) que tes
prestataires acceptent depuis leur compte. Prix saisis en HT ; toi seul (admin)
peux basculer l'affichage en TTC. Les prestataires ne voient que le HT.

À l'acceptation, chaque mission suit ce cycle, piloté par le prestataire :
**Disponible → (accepte) Acceptée → (état des lieux avant) En cours →
(état des lieux après) Terminée**. C'est le prestataire qui démarre et
clôture la mission — pas toi — avec un état des lieux (kilométrage,
carburant, état extérieur/intérieur, commentaire, photos) à chaque étape.
Tu peux consulter ces états des lieux depuis ton tableau de bord admin.

## Structure des pages

- **`index.html`** — le site vitrine public (accueil, services, zone
  d'intervention, tarifs, professionnels, devenir prestataire, FAQ). C'est
  la page que voient tes visiteurs sur ton nom de domaine.
- **`connexion.html`** — connexion admin/prestataire (avant : c'était
  `index.html`). Accessible depuis le bouton "Se connecter" du site vitrine.
- **`inscription.html`** — auto-inscription prestataire.
- **`admin.html`** / **`prestataire.html`** — les espaces une fois connecté.
- **`mentions-legales.html`** — mentions légales, va chercher automatiquement
  le nom/SIRET/adresse dans "Paramètres entreprise".

## 1. Créer le projet Supabase

**Nouvelle installation ?** Va sur supabase.com → New project (dédié à SBR CONVOYAGE,
distinct des 3 autres), ouvre le **SQL Editor**, colle le contenu de
`schema.sql`, exécute. Il contient déjà tout (spécialités, factures, etc.).

**Tu as déjà un projet Supabase pour ce site (installé avant le 14/09) ?**
N'exécute PAS `schema.sql` à nouveau (ça créerait des doublons). Ouvre plutôt
le SQL Editor et exécute, dans l'ordre, uniquement les migrations que tu n'as
pas encore passées :
1. `migration_v2.sql` (spécialités prestataires, factures) — si pas encore fait.
2. `migration_v3.sql` (notation des prestataires, contrats PDF automatiques) — si pas encore fait.
3. `migration_v4.sql` (contrat cadre par prestataire, date d'arrivée pour les convoyages) — si pas encore fait.
4. `migration_v5.sql` (paramètres entreprise, signature électronique du contrat cadre) — si pas encore fait.
5. `migration_v6.sql` (désistement d'un prestataire avant démarrage d'une mission) — si pas encore fait.
6. `migration_v7.sql` (auto-inscription prestataire, suivi des relances automatiques) — si pas encore fait.
7. `migration_v8.sql` (score de fiabilité, tableau de bord, suivi des paiements) — si pas encore fait.
8. `migration_v9.sql` (informations légales : SIRET, forme juridique, adresse) — si pas encore fait.
9. `migration_v10.sql` (documents prestataire : Kbis, assurance pro, CNI, permis — stockage privé) — si pas encore fait.
10. `migration_v11.sql` (vérification automatique des documents par IA) — si pas encore fait.
11. `migration_v12.sql` (nom du client sur la mission, pour le contrat) — si pas encore fait.
12. `migration_v13.sql` (RGPD, expiration assurance, notifications push, historique des contrats, suivi + signature client public).

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

Deux façons :
- **Auto-inscription (recommandé)** : envoie à tes prestataires le lien
  `inscription.html` de ton site déployé. Ils créent leur compte eux-mêmes
  (nom, téléphone, email, mot de passe, spécialités souhaitées). Le compte
  reste bloqué tant que tu ne l'as pas validé : dans `admin.html`, panneau
  **Prestataires**, section "Demandes en attente" en haut → bouton
  "Approuver" (ou "Refuser" pour supprimer la demande).
- **Création manuelle** : dashboard Supabase → **Authentication → Users →
  Add user**, puis une ligne dans `profiles` avec `role = prestataire`.
  Communique-lui l'email + mot de passe (tu peux les changer plus tard
  depuis le dashboard Supabase).

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

### Contrat cadre (autorisation à travailler avec toi) — signature électronique

C'est différent du contrat de mission (généré automatiquement à chaque
acceptation) : ici c'est le contrat général qui autorise un prestataire à
travailler avec SBR CONVOYAGE, avec ta signature de société d'un côté et celle
du prestataire de l'autre.

1. D'abord, une seule fois : bouton **"Paramètres entreprise"** en haut de
   `admin.html` → renseigne le nom de ta société, son adresse, et dépose
   une image de ta signature (photo ou scan sur fond clair). Elle sera
   apposée automatiquement sur tous les contrats générés.
2. Dans le panneau **Prestataires**, bouton **"Générer et envoyer le
   contrat"** sur la ligne d'un prestataire : un PDF est généré avec ta
   signature déjà apposée, et le statut passe à "en attente de signature
   du prestataire".
3. Côté prestataire, un bandeau apparaît en haut de son espace tant qu'il
   n'a pas signé : il relit le contrat, dessine sa signature du doigt (ou
   à la souris) dans un petit pavé, valide. Un nouveau PDF est généré avec
   les deux signatures et remplace le précédent ; le statut passe à
   "signé".
4. Tu peux suivre le statut de chacun (non envoyé / en attente / signé,
   avec la date) directement dans le panneau Prestataires, avec un lien
   pour ouvrir le PDF à tout moment.

Si un prestataire a déjà signé un contrat papier ou par un autre moyen,
le bouton **"Déposer un PDF déjà signé"** reste disponible pour l'importer
directement (statut mis à "signé" sans passer par la signature en ligne).

## 4. Déployer le site

Le site est 100% statique (pas de build), tous les fichiers vivent à la
racine du dossier (pas de sous-dossier). Le plus simple :
- Sur vercel.com → New Project → glisse le dossier `sbr-missions`
  (comme tes autres apps sbrauto.vercel.app / sbrcompta.vercel.app).
- Ou Netlify Drop (netlify.com/drop) pour un déploiement en 10 secondes.

### Nouveau logo et rebranding SBR CONVOYAGE

Le nouveau logo (voiture + route) est utilisé partout : en-tête de chaque
page, favicon, icône PWA, contrats PDF. Toute la marque a été renommée de
"SBR AUTO" à "SBR CONVOYAGE" dans l'ensemble du site, des contrats et de
la documentation.

### Site vitrine

`vitrine.html` est le site public de présentation (accueil, services,
zone d'intervention, tarifs, professionnels, devenir prestataire, FAQ),
dans le même style que la maquette que tu as fournie — avec le vrai logo
et les couleurs de la marque. Deux points de connexion avec le reste de
l'appli :
- Le bouton "Créer mon compte prestataire" renvoie vers `inscription.html`
  (la vraie création de compte, avec validation admin).
- Un lien "Se connecter" en haut renvoie vers `index.html` (connexion
  admin/prestataire).

Les deux formulaires (demande de devis, candidature détaillée) sont pour
l'instant des formulaires de démonstration : ils affichent juste un message
de confirmation sans rien envoyer nulle part. Pour les rendre fonctionnels,
il faut soit les connecter à un service d'emails/CRM de ton choix, soit
demande-moi de les brancher sur une adresse email une fois que tu m'en as
donné une.

Le site est aussi une **PWA (application installable)** : une fois déployé
en HTTPS (Vercel/Netlify le sont par défaut), toi et tes prestataires
pouvez l'ajouter à l'écran d'accueil du téléphone (Chrome : menu → "Ajouter
à l'écran d'accueil" ; Safari iOS : partager → "Sur l'écran d'accueil"). Il
s'ouvre alors comme une vraie appli, sans barre d'adresse, avec son icône.
Les données restent toujours en direct depuis Supabase — seule la coquille
(pages, styles) est mise en cache pour un chargement plus rapide.

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
   `supabase secrets set RESEND_FROM="SBR CONVOYAGE <onboarding@resend.dev>"`
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

### Vérification automatique des documents par IA (optionnel)

Depuis cette mise à jour, l'inscription prestataire **exige** les 4
documents (Kbis, assurance pro, CNI, permis) avant de pouvoir envoyer la
demande — c'est une vraie contrainte du formulaire, pas juste une
recommandation. En complément, une IA (API Claude) peut faire un premier
contrôle automatique de chaque document déposé (type de document
reconnu, lisible, cohérent) et écrire son verdict à côté de chaque
document dans le panneau Prestataires — **ça ne remplace jamais ta
vérification humaine**, c'est juste un premier filtre.

1. Crée une clé API sur **console.anthropic.com** si tu n'en as pas déjà une.
2. Déploie la fonction : `supabase functions deploy verify-document`.
3. Configure le secret : `supabase secrets set ANTHROPIC_API_KEY=ta_cle`.
4. C'est tout — la fonction est appelée automatiquement par le site à
   chaque dépôt de document (inscription ou "Mes documents"), pas besoin
   de Cron ni de webhook pour celle-ci.

⚠️ **Vie privée** : la CNI et le permis contiennent des données
personnelles. Les prompts envoyés à l'IA lui demandent explicitement de
ne jamais recopier ces données dans son verdict (juste dire si le
document est lisible et correspond au bon type), mais le fichier
transite techniquement par l'API d'Anthropic pour l'analyse. C'est déjà
mentionné dans `mentions-legales.html` — relis cette section si tu
actives la fonction, et assure-toi que ça correspond à ce que tu veux
faire avec ces documents.

Si tu ne configures pas cette fonction, les documents restent
uploadables et consultables normalement — seul le petit encart "verdict
IA" restera vide ("IA en cours...") indéfiniment, sans bloquer quoi que
ce soit.

### Notifications push sur le téléphone (optionnel, un peu technique)

En plus des emails, tes prestataires peuvent recevoir une vraie
notification sur leur téléphone (comme n'importe quelle appli), même
PWA fermée.

1. Génère une paire de clés VAPID (une seule fois, sur ton ordinateur,
   avec Node.js installé) :
   ```
   npx web-push generate-vapid-keys
   ```
   Ça te donne une clé publique et une clé privée.
2. Colle la clé **publique** dans `config.js`, variable `VAPID_PUBLIC_KEY`.
3. Configure la clé **privée** comme secret de la fonction `notify-mission` :
   ```
   supabase secrets set VAPID_PUBLIC_KEY=ta_cle_publique
   supabase secrets set VAPID_PRIVATE_KEY=ta_cle_privee
   ```
4. Redéploie la fonction : `supabase functions deploy notify-mission`.
5. Le webhook "Update" sur `missions` que tu as déjà configuré pour les
   emails déclenche aussi les notifications push — rien d'autre à faire
   côté Supabase.

Sans clé VAPID configurée, le bouton 🔔 reste simplement masqué côté
prestataire — aucun risque de casser quoi que ce soit si tu ne configures
pas cette partie.

### Relance automatique (optionnel, nécessite les emails ci-dessus)

Si une mission reste "disponible" plus de 24h sans prestataire, un email
récapitulatif peut t'être envoyé automatiquement (un seul email groupant
toutes les missions concernées, pas un par mission).

1. Déploie la seconde fonction : `supabase functions deploy relance-missions`
   (elle réutilise les mêmes secrets RESEND_API_KEY / RESEND_FROM).
2. Contrairement à `notify-mission`, celle-ci doit tourner sur un **planning
   régulier** plutôt que sur un événement. Le plus simple : Dashboard
   Supabase → **Edge Functions → relance-missions → Cron** (si disponible
   sur ton plan) → programme-la par exemple toutes les heures
   (`0 * * * *`).
   Si l'option Cron n'apparaît pas sur les fonctions, active plutôt les
   extensions **pg_cron** et **pg_net** (Database → Extensions), puis dans
   le SQL Editor :
   ```sql
   select cron.schedule(
     'relance-missions-horaire',
     '0 * * * *',
     $$
     select net.http_post(
       url := 'https://<ton-project-ref>.supabase.co/functions/v1/relance-missions',
       headers := jsonb_build_object('Authorization', 'Bearer <ta-service-role-key>')
     );
     $$
   );
   ```
   (remplace `<ton-project-ref>` et `<ta-service-role-key>`, trouvable dans
   Project Settings → API).

## Fonctionnement

- **Mot de passe oublié** : lien "Mot de passe oublié ?" sur `connexion.html`
  → email envoyé par Supabase → nouvelle page `reinitialiser-mot-de-passe.html`
  pour en choisir un nouveau. Aucune configuration nécessaire, ça marche
  directement avec Supabase Auth.
- **Export CSV** : bouton "⬇️ Export CSV" dans `admin.html` → toutes les
  missions avec dates, montants HT/TTC, statut de paiement, n° de facture
  — prêt à importer dans SBR COMPTA ou un tableur.
- **Calendrier** : bouton "📅 Calendrier" → vue mensuelle des missions par
  date prévue, avec navigation mois précédent/suivant.
- **Consentement RGPD** : case à cocher obligatoire à l'inscription
  prestataire, avec horodatage enregistré.
- **Anti-spam à l'inscription** : champ piège invisible (les bots le
  remplissent, pas les humains) + refus si le formulaire est envoyé en
  moins de 3 secondes. Léger mais efficace contre le spam automatisé de
  base ; n'arrête pas un spammeur déterminé qui cible spécifiquement ton
  site.
- **Alerte expiration assurance** : le prestataire renseigne la date de
  validité de son assurance pro dans "Mes documents". Elle apparaît dans
  "À traiter" dès qu'il reste moins de 30 jours, ou qu'elle est expirée.
- **Historique des contrats** : chaque nouvelle génération (brouillon ou
  signée) est maintenant conservée, pas seulement écrasée. Lien
  "historique des versions" sur chaque prestataire dans le panneau
  Prestataires.
- **Suivi + signature client** (nouveau, inspiré du CMR du secteur) :
  chaque mission a un lien de suivi public (`suivi.html?m=...`), à
  transmettre au client final — aucun compte requis. Il y voit le statut
  de sa mission, et peut signer électroniquement la réception du véhicule
  une fois la mission clôturée (comme la case "Signature et tampon
  client" d'un CMR classique). Bouton "Copier le lien de suivi client"
  sur chaque mission dans `admin.html`.
- **Notifications push** (optionnel, configuration plus avancée — voir
  section dédiée ci-dessous) : en plus de l'email, le prestataire peut
  activer les notifications directement sur son téléphone via le bouton
  🔔 dans son espace.

- **Contrat cadre enrichi** (inspiré de contrats du secteur du convoyage) :
  durée de 6 mois renouvelable par tacite reconduction (périodes de 3
  mois, préavis 15 jours), résiliation anticipée en cas de manquement
  grave (faux documents, suspicion de vol, comportement dangereux),
  qualités du prestataire (permis valide depuis plus de 3 ans),
  **mandat de facturation** (le prestataire te donne mandat pour établir
  les factures en son nom, sauf opposition écrite de sa part), infractions
  à sa charge, force majeure, cession interdite. 14 articles au total.
- **Contrat de mission** : nouveau champ facultatif "Nom du client" à la
  création d'une mission, repris sur le contrat généré à l'acceptation.
- **Relevé hebdomadaire prestataire** : bouton "🗓️ Récap hebdo" dans son
  espace → missions clôturées cette semaine, total, statut payé/à payer,
  et un bouton pour télécharger un relevé PDF officiel (généré par
  SBR CONVOYAGE au nom du prestataire, cohérent avec le mandat de
  facturation du contrat).
- **CGV** : nouvelle page `cgv.html`, liée depuis le pied de page —
  objet, tarifs/paiement (avec les pénalités de retard légales),
  exécution, responsabilité, annulation, litiges.
  ⚠️ Modèle standard à adapter/faire relire, comme les mentions légales.
- **Clients qui défilent** : mis à jour avec tes vrais noms (SBR AUTO,
  Remote Loc, DJ TRANSPORT).
- **Photos compressées automatiquement** : les photos d'état des lieux
  sont redimensionnées et compressées côté prestataire avant l'envoi
  (plus rapide, moins de data, en particulier depuis un mobile).

- **Documents obligatoires à l'inscription** : impossible d'envoyer sa
  demande sans avoir joint les 4 documents (Kbis, assurance pro, CNI,
  permis) — ce sont des champs obligatoires du formulaire, le navigateur
  bloque l'envoi tant qu'ils ne sont pas tous sélectionnés. S'il faut
  confirmer son email avant de pouvoir se connecter (selon tes réglages
  Supabase), les documents sont à déposer juste après, dans "Mes
  documents" — mais dans la configuration la plus courante (sans
  confirmation email), tout se fait en une seule fois à l'inscription.
- **Vérification IA des documents** (optionnelle, voir section dédiée
  plus bas) : verdict affiché à côté de chaque document, aussi bien côté
  prestataire que côté admin — jamais un remplacement de ta propre
  vérification.
- **Recherche de missions** : au-dessus du tableau de missions dans
  `admin.html`, un champ recherche (titre, véhicule, prestataire, lieu)
  et un filtre par type, pour retrouver rapidement une mission une fois
  qu'il y en a beaucoup.

- **Vitrine dans l'esprit Otoqi** : le formulaire "devenir prestataire"
  (candidature détaillée) a été retiré — il ne reste qu'un seul bouton
  clair "Créer mon compte prestataire" vers `inscription.html`. Le grand
  formulaire de devis (12+ champs) a été remplacé par une section
  "Contact" simple : téléphone, email, horaires — cliquables directement
  (appel / email) plutôt qu'un formulaire à remplir.
  ⚠️ **Numéro et email sont des placeholders** (`06 00 00 00 00` /
  `contact@sbrconvoyage.fr`) — remplace-les par tes vraies coordonnées
  dans `index.html` (cherche `tel:+33000000000` et `contact@sbrconvoyage.fr`).
- **Vraie carte** : la zone d'intervention affiche maintenant une carte
  OpenStreetMap réelle (gratuite, sans clé API) centrée sur Marseille/PACA,
  à la place des villes positionnées à la main en CSS.
- **Bande "Ils nous font confiance"** : logos/noms clients qui défilent en
  continu, inspiré des plateformes de convoyage B2B établies. Seul "SBR
  AUTO" est un vrai nom (ta propre activité) ; les autres
  ("Garage partenaire", "Loueur régional"...) sont des **placeholders
  génériques** à remplacer par de vrais noms de clients (ou mieux, leurs
  logos) dès que tu en as — ne publie pas de noms d'entreprises inventés
  comme s'il s'agissait de vrais clients.

- **Design/UX** : le menu ☰ du site vitrine sur mobile ne faisait rien
  (juste décoratif) — il ouvre maintenant un vrai panneau de navigation.
  La barre de boutons de l'admin (Paiements, Tableau de bord, etc.)
  débordait sur petit écran — elle défile maintenant horizontalement au
  lieu de casser la mise en page. Les fenêtres (état des lieux, facture,
  notation, signature...) s'ouvrent avec une animation douce plutôt que
  d'apparaître brutalement. Les écrans de chargement ont un vrai indicateur
  visuel plutôt qu'un texte "Chargement...". Le fond de la page d'accueil
  n'utilise plus une image externe (Unsplash) mais un dégradé de marque
  avec le motif "route" repris du logo — plus rapide à charger et plus
  cohérent visuellement.

- **Nouveau logo et PWA renforcée** : ton logo (voiture + route) est
  utilisé partout. Les balises manquantes pour une vraie installation en
  application sur iPhone ont été ajoutées (`apple-mobile-web-app-capable`
  etc.) — sans elles, "Ajouter à l'écran d'accueil" ouvrait juste Safari
  au lieu d'une vraie appli plein écran. Ça concerne `admin.html` et
  `prestataire.html` comme les autres pages : les deux sont prêts à être
  utilisés comme une appli téléphone une fois installés.
- **Documents prestataire** : depuis son espace, bouton **"Mes
  documents"** → le prestataire renseigne son nom de société / site web
  (optionnels) et dépose Kbis, attestation d'assurance pro, CNI, permis
  de conduire. Ces fichiers sont stockés dans un bucket **privé** —
  contrairement aux photos d'état des lieux ou aux factures, ils ne sont
  JAMAIS accessibles publiquement : seuls le prestataire concerné et toi
  (admin) pouvez les ouvrir (lien à durée limitée généré à la demande).
  Depuis le panneau **Prestataires**, tu vois en un coup d'œil quels
  documents sont déposés ou manquants pour chacun.
- **Site vitrine repensé** : couleurs harmonisées avec le nouveau logo
  (doré plutôt qu'orange), mise en avant du processus de vérification des
  prestataires (Kbis, assurance, identité, permis) comme argument de
  confiance auprès des professionnels — dans l'esprit des plateformes de
  convoyage B2B établies.
- **Mentions légales** : nouvelle page, liée depuis le pied de page du
  site vitrine, avec les informations de la société récupérées
  automatiquement depuis "Paramètres entreprise".
  ⚠️ C'est un modèle standard, pas un avis juridique — fais-le relire par
  un professionnel, notamment la partie hébergement si tu changes
  d'hébergeur. Le lien "CGV" du pied de page n'est pas encore relié (page
  à rédiger séparément, avec tes conditions de vente réelles).

- **Correctif important** : le bug "Erreur lors de la signature : Incomplete
  or corrupt PNG file" est corrigé. Il venait du format de la signature de
  la société : si tu avais déposé une image qui n'était pas un vrai PNG
  (JPG renommé, etc.), la génération du PDF échouait. Deux corrections :
  le format réel de chaque image est maintenant détecté automatiquement
  avant de l'insérer dans le PDF, et toute nouvelle signature déposée dans
  "Paramètres entreprise" est systématiquement reconvertie en PNG propre
  avant l'envoi. Si le problème te bloquait avant cette mise à jour,
  redépose simplement ta signature depuis "Paramètres entreprise" — c'est
  suffisant, pas besoin de renvoyer les contrats déjà générés.
- **Contrat cadre = vrai contrat de prestation de services** : il comporte
  désormais l'identification complète des parties (forme juridique, SIRET,
  adresse — à renseigner dans "Paramètres entreprise" pour la société, et
  dans la fiche de chaque prestataire pour lui), et des articles standards :
  indépendance du prestataire (pas de lien de subordination — important
  pour éviter toute requalification en salariat), obligations réciproques,
  rémunération, assurance/responsabilité, confidentialité, données
  personnelles, durée et résiliation (préavis de 15 jours), droit
  applicable. Le PDF s'étale sur plusieurs pages si besoin, avec pied de
  page sur chacune.
  ⚠️ Ce contrat est un modèle généraliste, pas un avis juridique — fais-le
  relire par un professionnel (avocat, expert-comptable) avant de le
  diffuser à grande échelle, notamment sur le statut du prestataire.
- **Contrat de mission enrichi** : rappelle désormais le cadre du contrat
  de prestation de services et l'indépendance du prestataire, affiche la
  date d'arrivée prévue pour les convoyages, et gère lui aussi plusieurs
  pages si besoin.
- **Autocomplétion d'adresse** : en tapant dans "Lieu de départ", "Lieu
  d'arrivée" (création de mission), "Adresse" (Paramètres entreprise et
  inscription prestataire), des suggestions d'adresses réelles apparaissent
  au bout de 3 caractères, via l'API Adresse du gouvernement français
  (gratuite, sans inscription, aucune clé à configurer).

- **Score de fiabilité** : dans le panneau Prestataires, chaque prestataire
  affiche désormais, en plus de sa note moyenne, un score de fiabilité sur
  5 qui pénalise les désistements (avant démarrage) et les annulations
  (mission annulée par toi alors qu'il était déjà assigné). Calcul :
  note moyenne (ou 5 par défaut) × (1 − taux d'incidents), avec taux
  d'incidents = (désistements + annulations) / missions acceptées. Ces
  compteurs se mettent à jour automatiquement (trigger en base), pas
  besoin d'action de ta part.
- **Tableau de bord** : bouton en haut de `admin.html` → CA du mois (HT et
  TTC) sur les missions clôturées, répartition par type, classement des 5
  prestataires les plus actifs ce mois-ci.
- **Paiements** : bouton "Paiements" → missions clôturées pas encore
  payées, groupées par prestataire avec le total dû. Coche les missions
  réglées puis "Marquer les cochées comme payées", ou "Tout marquer payé"
  en un clic le lundi une fois les virements faits. Le prestataire voit
  aussi ce statut ("réglé le JJ/MM" ou "en attente") sur sa propre carte
  de mission.

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
  onglet. Le prestataire concerné voit aussi ce lien depuis sa propre
  carte de la mission.
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
  - **Me désister** (visible tant que la mission n'est pas démarrée) →
    la mission redevient disponible pour les autres prestataires.
- Toi (admin), tu peux annuler une mission à tout moment — disponible,
  acceptée ou en cours — via le bouton "Annuler" sur sa carte (une
  confirmation est demandée). Bouton "Dupliquer" sur chaque mission :
  pré-remplit le formulaire "Nouvelle mission" avec les mêmes infos (type,
  titre, véhicule, lieux, prix), dates à vide pour que tu les ressaisisses.
- **Vue "À traiter"** : bouton en haut de `admin.html` → recense en un
  coup d'œil les factures manquantes, les notations manquantes, les
  contrats cadre non signés et les missions disponibles depuis plus de
  24h, avec une action directe sur chaque ligne (ajouter la facture,
  noter, renvoyer le contrat...).
- **Paiement** : les deux contrats (mission et contrat cadre) précisent
  désormais que le règlement s'effectue chaque lundi, pour les missions
  clôturées et facturées la semaine précédente.
- Les PDF générés (contrat de mission, contrat cadre) ont une mise en page
  plus structurée : bandeau d'en-tête avec logo, sections nettement
  séparées, pied de page avec date de génération.
- Tout le monde arrive par `index.html` (connexion), qui redirige
  automatiquement vers le bon espace selon le rôle.
- Les photos d'état des lieux sont stockées dans le bucket Supabase Storage
  `etats-lieux`, les factures PDF dans `factures`, et les contrats générés
  automatiquement dans `contrats`.
- Le logo SBR CONVOYAGE est utilisé partout : en-tête de chaque page, favicon,
  et icône de l'app une fois installée en PWA.

## Idées pour la suite

- Email de notification quand une facture ou un contrat est ajouté (en plus
  de la nouvelle mission / mission acceptée déjà en place).
- Génération automatique du PDF de facture (au lieu de le déposer toi-même)
  à partir des infos de la mission, sur le même principe que le contrat.
- Export comptable des missions clôturées + factures (lien possible avec
  SBR COMPTA).
- Recherche/filtre des missions (par prestataire, date, statut).
- Réinitialisation de mot de passe en autonomie pour les prestataires.
- Compression des photos avant envoi (plus rapide sur mobile, moins de
  data).
