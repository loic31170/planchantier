# PlanChantier

Appli iPhone / iPad pour scanner des pièces au LiDAR et obtenir un plan 2D coté.

## Lancer l'appli sur ton iPhone

1. **Ajoute ton identifiant Apple dans Xcode** : Xcode > Réglages (Settings) > Comptes (Accounts) > « + » > Apple ID.
2. **Ouvre le projet** : double-clique sur `PlanChantier.xcodeproj`.
3. **Signature** : dans la colonne de gauche, clique sur le projet bleu « PlanChantier », puis sur la cible « PlanChantier » > onglet « Signing & Capabilities ».
   Dans « Team », choisis ton nom (Personal Team).
   Si Xcode affiche une erreur sur le « Bundle Identifier », remplace `com.loic.planchantier` par quelque chose d'unique, par exemple `com.loic.planchantier2`.
4. **Branche ton iPhone** au Mac avec un câble, déverrouille-le et accepte « Faire confiance à cet ordinateur ».
5. **Active le mode développeur sur l'iPhone** : Réglages > Confidentialité et sécurité > Mode développeur > activer, puis redémarrer l'iPhone.
6. **Choisis ton iPhone** en haut de la fenêtre Xcode (à côté de « PlanChantier »), puis clique sur le bouton ▶︎ (ou Cmd + R).
7. **Premier lancement** : si l'iPhone refuse d'ouvrir l'appli, va dans Réglages > Général > VPN et gestion de l'appareil, et fais confiance à ton profil développeur.

Avec un compte Apple gratuit, l'appli installée fonctionne 7 jours : il suffit de relancer ▶︎ depuis Xcode pour la renouveler.

## Ce que fait la version 0.1

- Liste des chantiers (nom, client, adresse)
- Scan d'une pièce avec RoomPlan (iPhone Pro / iPad Pro avec LiDAR)
- Plan 2D vu de dessus : murs, portes, fenêtres, ouvertures, longueur de chaque mur
- Mesures : surface au sol, périmètre, hauteur sous plafond, surface brute des murs
- Notes par pièce, total de surface par chantier

## Ajouts de la version 0.2

- Plan redressé (le mur le plus long est horizontal) et petites cotes masquées sur le dessin
- Photos par pièce : appareil photo ou photothèque, appui long pour supprimer
- Export PDF du chantier (bouton de partage en haut de l'écran du chantier) : page de garde avec récapitulatif, une page par pièce avec plan coté et mesures, pages de photos

## Ajouts de la version 0.3 : devis

- Réglages (roue dentée en haut à gauche de la liste des chantiers) : coordonnées de l'entreprise, SIRET, franchise de TVA, durée de validité
- Catalogue de prestations avec tes prix, et pour chacune la mesure qui sert à calculer la quantité (murs nets, plafond, sol, plinthes, portes…)
- Dans un chantier, section « Devis » : ajout de prestations du catalogue (quantités calculées pièce par pièce, modifiables) ou de lignes libres, totaux HT / TVA / TTC
- PDF du devis numéroté (D-année-001…) avec zone « Bon pour accord »
- Nouvelles mesures par pièce : surface des murs nette (portes et fenêtres déduites) et longueur de plinthes

## Ajouts de la version 0.4

- Murs numérotés sur le plan (sens des aiguilles d'une montre, en partant du haut), même numérotation dans la liste et le PDF
- Scan de plusieurs pièces à la suite (« Enregistrer et scanner la pièce suivante ») : elles sont assemblées en plan d'étage, visible dans le chantier et dans le PDF
- Icône de l'appli, couleurs de l'entreprise, logo Les PaPa Potes sur les PDF (modifiable dans Réglages)

## Ajouts de la version 0.5

- Nouvelle page d'accueil : logo et nom de l'entreprise, chantiers en cartes avec l'aperçu du plan, surface totale et initiales du client
- Recherche par nom, client ou adresse ; filtres Tous / Favoris / Archivés
- Appui long sur une carte : favori, archiver, supprimer (avec confirmation)

## Organisation du code

| Fichier | Rôle |
| --- | --- |
| `PlanChantierApp.swift` | Point d'entrée de l'appli |
| `AccueilView.swift` | Page d'accueil : cartes des chantiers, recherche, filtres |
| `Modeles.swift` | Données : Chantier, Pièce, segments du plan |
| `AnalyseurPiece.swift` | Conversion du scan 3D en plan 2D et en métrés |
| `ScanView.swift` | Écran de scan RoomPlan |
| `PlanPieceView.swift` | Dessin du plan 2D coté |
| `ChantiersViews.swift` | Écrans : nouveau chantier, chantier, pièce |
| `Photos.swift` | Photos des pièces : prise de vue, stockage, affichage |
| `ExportPDF.swift` | Génération et partage du PDF du chantier |
| `Devis.swift` | Données du devis : catalogue, lignes, calcul des quantités et totaux |
| `DevisViews.swift` | Écrans du devis |
| `ReglagesViews.swift` | Réglages de l'entreprise et catalogue |
| `ExportDevisPDF.swift` | PDF du devis |
| `PlanEtageView.swift` | Plan d'étage assemblé |
| `Logo.swift` | Logo de l'entreprise |
