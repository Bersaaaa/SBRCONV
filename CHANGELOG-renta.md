# SBR AUTO — mise à jour "Rentabilité manuelle"

## Ce qui a été retiré
- Onglets **Livre Recettes**, **Livre Achats**, **Export Comptable**, **Historique**
- **Google Agenda** (section Paramètres + fonction Supabase `planning-feed`, supprimée)
- Tout ce qui touchait à la **TVA** (seuil, alerte, jauge)
- Tout ce qui touchait à l'**URSSAF** : prélèvement à la source par plateforme,
  calcul de cotisations, versement libératoire, déclaration annuelle. La
  Rentabilité sert uniquement à voir où on en est, pas à déclarer.
- Du Dashboard : CA à déclarer, marge nette, top des coûts, récap annuel, exports PDF/Excel
- Import CSV/Excel, répartition d'une ligne entre plusieurs plaques, décote globale

## Ce qui a été ajouté / refait
- **Rentabilité** entièrement en saisie manuelle, par véhicule et par mois :
  - Gains : Getaround, Turo, Roadstr, vente du véhicule, autres
  - Dépenses : assurance, crédit/loyer, entretien, réparation, pneus, carburant/péage,
    nettoyage, amendes, parking, autres
  - Décote du mois et notes
  - Marge = gains − dépenses − décote (mois, année, moyenne par mois saisi)
  - Comparaison entre véhicules + détail par poste + taux d'occupation (repris du planning)
  - « Effacer ce mois » → part à la Corbeille, restaurable
- **Dashboard** : alertes, actions rapides et rentabilité par véhicule (mois + année)
- **Planning Sièges** : libellé complet aussi dans la barre mobile
- Sauvegarde Excel : onglet **Rentabilité** à la place de Recettes/Achats/Répartitions

## Base de données
Relance **`schema.sql`** dans Supabase (SQL Editor → New query → Run). Il est
idempotent : il crée la table `renta_lignes`, ses index et ses règles d'accès.

Aucune donnée n'est supprimée : les tables `recettes`, `achats`, `montant_splits`
et `historique` restent en base en archive, ainsi que les colonnes TVA / décote
globale / versement libératoire / prélèvement à la source dans `params`.
L'application ne les lit plus.
