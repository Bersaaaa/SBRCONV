# Intégration SBR COMPTA dans SBR AUTO — étapes de déploiement

Ce zip contient `index.html` avec SBR COMPTA déjà fusionné dans SBR AUTO
(nouveau groupe de navigation **Compta**, groupe **Opérations** renommé en
**Location**, Vue d'ensemble enrichie avec les chiffres du mois). Une seule
base Supabase (celle de SBR AUTO), une seule connexion.

## 1. Créer les tables Compta dans la base SBR AUTO

Dans le **Dashboard Supabase du projet SBR AUTO** (réf. `wpecxfxyfnvmzxkclhqc`)
→ SQL Editor → coller et exécuter `migration-sbrcompta.sql` (à la racine de ce
zip). Sûr à rejouer plusieurs fois. Crée : `transactions`, `declarations`,
`rules`, `settings`, `notifications`, leurs policies RLS (chacun ne voit que
ses propres lignes, comme avant), le bucket Storage `justificatifs`, et
active le Realtime sur `notifications` (pour la cloche 🔔).

## 2. Migrer les données existantes de SBR COMPTA

L'ancienne base SBR COMPTA (réf. `hjxmwsstbvirfuijqcql`) contient tes
recettes/dépenses/déclarations actuelles. Elles ne sont **pas** migrées
automatiquement — cet environnement n'a pas accès à tes bases Supabase en
direct. Deux façons de les transférer, à faire toi-même :

**Option simple (Table Editor, sans rien installer) :**
Pour chacune des 5 tables (`transactions`, `declarations`, `rules`,
`settings`, `notifications`) : ouvre-la dans le projet SBR COMPTA → bouton
"Export" → CSV, puis dans le projet SBR AUTO → Table Editor → même table
(après l'étape 1) → "Import data from CSV". Fais `transactions` en premier
(c'est la seule qui contient vraiment du volume).

**Option rapide (ligne de commande, si tu as `psql`/`pg_dump`) :**
Récupère les deux "Connection string" (Settings → Database → Connection
string → URI) de chaque projet, puis :
```bash
pg_dump "postgresql://...URI-SBRCOMPTA..." \
  --data-only -t public.transactions -t public.declarations \
  -t public.rules -t public.settings -t public.notifications \
  -f compta-data.sql

psql "postgresql://...URI-SBRAUTO..." -f compta-data.sql
```
(Fais l'étape 1 — créer les tables — avant de lancer le `psql` de restauration.)

## 3. Déployer la fonction ROOT IA sur le projet SBR AUTO

Le module TVA / ROOT IA appelle une Edge Function (`root-ia`), déjà fournie
dans `supabase/functions/root-ia/index.ts`. Elle doit être (re)déployée sur
le projet **SBR AUTO**, pas sur l'ancien projet compta :
```bash
supabase login
supabase link --project-ref wpecxfxyfnvmzxkclhqc
supabase secrets set ANTHROPIC_API_KEY=sk-ant-xxxxxxxx
supabase functions deploy root-ia
```

## 4. Redéployer le site

Remplace le contenu de ton repo SBR AUTO (Vercel ou autre) par celui de ce
zip, puis redéploie normalement.

## 5. Vérifier avant de couper l'ancien SBR COMPTA

- Se connecter avec le compte habituel → onglet **Compta** → vérifier que
  les recettes/dépenses/déclarations migrées apparaissent bien.
- Tester un ajout de recette/dépense, l'import bancaire, le module TVA.
- Vérifier que la cloche 🔔 (notifications URSSAF) fonctionne.
- Une fois confirmé : tu peux mettre en pause (ou garder en lecture seule
  quelque temps par sécurité) l'ancien projet Supabase SBR COMPTA et son
  déploiement séparé (`sbrcompta.vercel.app`).

## Limite connue

Les tables Compta utilisent encore leurs propres règles d'accès simples
(chacun voit ses propres lignes). Si tu donnes un jour un accès restreint à
quelqu'un d'autre que toi dans SBR AUTO (rôle non-admin), il faudra adapter
ces règles pour les données Compta — pour l'instant tout est pensé pour un
seul utilisateur (toi).
