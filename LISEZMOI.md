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

## Ajouts de la version 0.6 : fiche chantier

- Description du chantier, carte client + adresse avec mini-carte et bouton Itinéraire
- Statistiques : surface au sol, surface murale, étages, pièces
- Plans : défilement horizontal (plans d'étage puis pièces seules), bouton + pour scanner, « Voir tout »
- Photos : photos générales du chantier et photos des pièces, bouton + (appareil ou photothèque), « Voir tout »
- Carte Devis (numéro et total TTC), informations de création, actions : exporter, favori, dupliquer, archiver, supprimer

## Ajouts de la version 0.7 : localisation (Plans d'Apple uniquement)

- Toucher la carte adresse ouvre la carte plein écran du chantier (plan ou satellite) avec son repère
- « Itinéraire » ouvre directement l'appli Plans d'Apple en mode voiture ; « Ouvrir dans Plans » dans le menu carte
- « Modifier » : adresse champ par champ (rue, ville, code postal, région, pays) avec suggestions d'adresses Apple, et « Supprimer l'adresse »
- Bouton crayon en haut de la fiche chantier pour modifier le nom, la description et le client

## Ajouts de la version 0.8 : fichiers et rapport façon architecte

- Nouvelle section **Fichiers** dans la fiche chantier : chaque relevé et chaque devis généré y est rangé automatiquement, on peut aussi scanner un document papier ou importer un PDF, une image ou un modèle 3D. Appui long pour partager, renommer ou supprimer.
- Plans de pièce cotés façon architecte : murs épais, portes avec leur sens d'ouverture, fenêtres, chaînes de cotes avec les ouvertures, échelle.
- Rapport PDF refait : page de garde avec la carte Plans d'Apple, tableau des chiffres clés et récapitulatif des pièces, bandeau chantier en haut de chaque page, photos sur 3 colonnes étiquetées « Pièce · Photo n ».

## Ajouts de la version 0.9 : 3D et mobilier

- Bouton **Vue 3D** (cube) en haut d'une pièce ou d'un plan d'étage : le modèle 3D est construit à partir du scan, on le fait tourner avec un doigt et on zoome avec deux.
- **Bibliothèque de mobilier** (cuisine, salon, chambre, salle de bain, divers) aux dimensions courantes. Touche un meuble pour le sélectionner, fais-le glisser pour le déplacer, tourne-le, duplique-le ou supprime-le. L'aménagement est enregistré avec le chantier.
- **Export 3D en USDZ**, avec ou sans les meubles, rangé dans les Fichiers du chantier et partageable. « Voir en réalité augmentée » pose le modèle dans la pièce avec la caméra.
- La vue 3D a besoin du scan d'origine, enregistré avec chaque pièce scannée.

## Ajouts de la version 0.10 : Plan 3D depuis l'accueil

- Carte **Plan 3D** sur l'accueil (et icône cube en haut) : on choisit le chantier, puis les étages et les pièces à inclure, et on génère le plan 3D.

## Ajouts de la version 0.11 : devis pièce par pièce

- Carte **Générer un devis** sur l'accueil : on choisit le chantier et on arrive sur son devis.
- Le devis est rangé **par pièce**, avec un sous-total par pièce, plus une section « Travaux généraux ». Le PDF suit le même découpage.
- Dans chaque pièce : **Ajouter des travaux**. Tu choisis une prestation du catalogue (rangé par corps de métier) ou un **ouvrage tout prêt** qui ajoute plusieurs lignes d'un coup : alimentation d'un radiateur (saignée + gaine + sortie de câble + rebouchage…), prise encastrée, point lumineux, remplacement d'une baignoire par une douche, lavabo, WC.
- On peut indiquer l'emplacement : numéro du mur (comme sur le plan) et une précision libre.
- Le catalogue s'enrichit de prestations d'électricité, plomberie, chauffage, maçonnerie… (prix d'exemple à adapter).

## Ajouts de la version 0.12 : tarifs fournisseurs

- Réglages > **Tarifs fournisseurs** : import d'un tarif en CSV (le fichier Cedeo est prêt dans `Produits/Tarifs Cedeo.csv`). Recherche par libellé, marque ou code, filtre par famille.
- Prix de revente : prix public du fournisseur, ou prix d'achat × ton coefficient. L'éco-contribution est ajoutée.
- Dans le devis, **Ajouter des travaux > Fournitures** : on choisit un produit, la marge s'affiche pour toi, jamais sur le PDF. Le total du devis montre la marge sur fournitures.
- Pour un autre fournisseur : exporter son tarif en CSV avec au moins une colonne libellé et une colonne prix.
- Ton fichier d'articles est prêt dans `Produits/Tarifs Mes articles.csv` : les produits vont dans les tarifs, les lignes de type « Service » (main d'œuvre, forfaits) vont directement dans le catalogue de prestations avec ton prix et ta TVA.

## Ajouts de la version 0.13 : dictée du devis au micro

- Dans le devis, **Dicter des travaux au micro** : tu décris les travaux pièce par pièce, le texte s'affiche (modifiable), puis « Transformer en lignes de devis ».
- L'analyse utilise l'IA d'Apple sur l'iPhone (iOS 26, iPhone 15 Pro ou plus récent, Apple Intelligence activé), sinon une analyse par mots-clés.
- Un écran de vérification montre les lignes proposées par pièce : tu coches, corriges les quantités et les prix, puis tu ajoutes au devis.
- Au premier usage, l'iPhone demande l'accès au micro et à la reconnaissance vocale.

## Plan depuis un plan existant (sans LiDAR)

- Dans la fiche chantier, le « + » des Plans propose **Scanner avec le LiDAR** ou **Importer un plan existant** (PDF, image, ou photo du plan papier redressée automatiquement).
- Étapes : mise à l'échelle avec une cote connue, clic des coins de la pièce (murs droits à 90° par défaut), portes et fenêtres en touchant les murs, nom et hauteur sous plafond.
- Les pièces tracées sur un même plan forment un plan d'étage. Le plan importé est rangé dans les Fichiers du chantier.
- Ces pièces n'ont pas de scan 3D : la vue 3D ne les montre pas.

## TVA selon la nature des travaux

- En haut du devis : **Rénovation (10 %)** ou **Neuf (20 %)**. Le choix s'applique à toutes les lignes, existantes et nouvelles (une ligne peut encore être modifiée à la main).
- En rénovation, le PDF porte la mention du taux réduit (art. 279-0 bis du CGI).

## Organisation du code

| Fichier | Rôle |
| --- | --- |
| `PlanChantierApp.swift` | Point d'entrée de l'appli |
| `AccueilView.swift` | Page d'accueil : cartes des chantiers, recherche, filtres |
| `Modeles.swift` | Données : Chantier, Pièce, segments du plan |
| `AnalyseurPiece.swift` | Conversion du scan 3D en plan 2D et en métrés |
| `ScanView.swift` | Écran de scan RoomPlan |
| `PlanPieceView.swift` | Dessin du plan 2D coté |
| `ChantierView.swift` | Fiche d'un chantier |
| `Localisation.swift` | Carte du chantier, itinéraire Plans, modification de l'adresse |
| `ChantiersViews.swift` | Écrans : nouveau chantier, pièce |
| `Photos.swift` | Photos des pièces : prise de vue, stockage, affichage |
| `ExportPDF.swift` | Génération et partage du PDF du chantier |
| `Devis.swift` | Données du devis : catalogue, lignes, calcul des quantités et totaux |
| `DevisViews.swift` | Écrans du devis |
| `ReglagesViews.swift` | Réglages de l'entreprise et catalogue |
| `ExportDevisPDF.swift` | PDF du devis |
| `PlanEtageView.swift` | Plan d'étage assemblé |
| `Logo.swift` | Logo de l'entreprise |
| `PlanCoteView.swift` | Plan de pièce coté façon architecte |
| `Vue3D.swift` | Vue 3D, déplacement des meubles, export USDZ |
| `Assistant3D.swift` | Plan 3D depuis l'accueil : choix du chantier et des pièces |
| `TravauxPieces.swift` | Travaux par pièce, ouvrages tout prêts, devis depuis l'accueil |
| `Produits.swift` | Tarifs fournisseurs : import CSV, recherche, ajout au devis avec marge |
| `Dictee.swift` | Dictée au micro et transformation en lignes de devis |
| `TracePlan.swift` | Création des pièces à partir d'un plan existant (PDF, image) |
| `Mobilier3D.swift` | Bibliothèque de mobilier 3D |
| `Fichiers.swift` | Fichiers du chantier : relevés, devis, documents scannés ou importés |
