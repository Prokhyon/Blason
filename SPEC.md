# Blason — Spécification

> **Statut** : v1 validée (9 novembre 2026). Toute évolution est notée dans le journal des décisions (section 9).
> Fiche de référence : `Leo character sheet.pdf` (feuille officielle BRP, partiellement remplie), conservée localement et hors de git.

---

## 1. Vision

Une app iPad pour **joueur** de jeu de rôle qui permet de créer et de tenir à jour ses fiches de personnage pour **n'importe quel système**. On vise d'abord BRP, L'Appel de Cthulhu et les systèmes moins connus. D&D est hors cible, puisqu'il a déjà son app.

Le flux principal se déroule en deux étapes :
1. **Construire un template** pour un système (la structure de la fiche), une seule fois ;
2. **Créer des personnages** à partir de ce template et les remplir, sans jamais refaire les champs.

La priorité est de rendre **rapide et pratique** la construction de la structure, puis le remplissage et l'usage en partie.

**Usage** : personnel d'abord. Une publication est possible plus tard, ce qui demande un code et un modèle propres et évolutifs. Un volet MJ pourra venir ensuite, mais ce n'est pas une priorité.

### Non-objectifs (V1)
- Outils MJ, règles intégrées d'un système, multi-utilisateurs.
- iPhone et Mac. En revanche, le code doit rester **multiplateforme** (SwiftUI, sans API propres à l'iPad dans le modèle) pour qu'iOS et macOS arrivent plus tard sans réécriture.

---

## 2. Principes directeurs

1. **La fiche est l'écran central.** On construit, remplit et joue sur la même vue.
2. **Ce qu'on voit est ce qu'on obtient.** La structure s'édite sur le rendu réel de la fiche.
3. **Peu de taps.** Dupliquer, copier-coller, coller une liste et des réglages par défaut intelligents partout.
4. **Zéro perte de données.** Sauvegarde automatique, annuler/rétablir, export JSON.
5. **Pensée pour l'iPad.** Portrait et paysage, inspecteur latéral, clavier externe.

---

## 3. Concepts

| Concept | Définition |
|---|---|
| **Template** | Structure de fiche pour un système, avec ses valeurs par défaut. |
| **Personnage** | Fiche concrète. Possède **sa propre copie** de la structure, avec ses valeurs. |
| **Page** | Onglet de la fiche (ex. « Personnage », « Compétences », « Combat », « Notes »). |
| **Rangée** | Bloc horizontal d'une page, découpé en 1 à N **colonnes** de largeurs relatives. Chaque colonne **empile** ses sections, indépendamment des autres. |
| **Section** | Bloc titré. Deux sortes : **Champs** ou **Tableau**. |
| **Champ** | Donnée typée et nommée (ex. « POU », entier). Possède un **code** utilisable dans les formules. |
| **Tableau** | Lignes × colonnes typées, avec des groupes (ex. les compétences par catégorie). |

### Relation entre template et personnage (décidé)
- Créer un personnage fait une **copie complète** du template. Modifier ensuite le template n'affecte pas les personnages existants.
- Le personnage garde une référence informative à son template d'origine.
- Un personnage peut modifier sa propre structure (mode Structure), sans effet sur le template.
- « Enregistrer comme template » crée un **nouveau** template, qui est une copie.
- Plus tard : « mettre à jour depuis le template » (fusion des nouveaux champs).

---

## 4. Les trois modes de la fiche

Une seule vue, trois modes, un sélecteur dans la barre d'outils :

| Mode | Pour qui, quand | Ce qui est modifiable |
|---|---|---|
| **Structure** | Construction du template (étape 1) | Pages, rangées, sections, champs, colonnes. Inspecteur latéral ouvert. |
| **Remplir** | Création du personnage (étape 2) | Toutes les valeurs. |
| **Jouer** | En partie | Seules les **valeurs vivantes** (PV, PM, SAN, cases « compétence utilisée »…), en un tap. |

- Un template s'ouvre par défaut en **Structure**. Un personnage s'ouvre par défaut en **Jouer**.
- Sur un template, le mode **Remplir** sert à saisir les valeurs par défaut.

### 4.1 Mode Structure (détail)
- **Sélection** : un tap sélectionne une section ou un champ. L'inspecteur à droite affiche ses propriétés : libellé, code, type, min/max, unité, valeur par défaut ou formule, valeur vivante, disposition.
- **Ajout rapide** : un bouton « + champ » en bas de chaque section ouvre un menu de types. Le champ est inséré et son libellé reçoit le focus. Appuyer sur Entrée crée le champ suivant **du même type**, ce qui permet de saisir FOR, CON, TAI… au clavier sans toucher l'écran.
- **Coller une liste** : coller un texte (une ligne par entrée, colonnes séparées par une tabulation ou un `;`) crée tous les champs ou toutes les lignes d'un tableau d'un coup. Exemple : `Marchander;5` → ligne « Marchander », base 5.
- **Dupliquer, copier, coller** : un champ, plusieurs champs (sélection multiple), une section entière, d'une section à l'autre ou d'un template à l'autre (presse-papiers de l'app). Raccourcis ⌘C, ⌘V, ⌘D.
- **Glisser-déposer** : réordonner les champs, déplacer une section dans une autre rangée.
- **Rangées** : « + rangée » ; le nombre de colonnes d'une rangée et leurs largeurs relatives (ex. ½ – ½, ⅔ – ⅓) se règlent dans l'inspecteur. Une section se glisse d'une colonne à l'autre.
- **Annuler / rétablir** : ⌘Z, ⇧⌘Z.

---

## 5. Périmètre V1

### 5.1 Bibliothèque
- Personnages : créer (depuis un template ou une fiche vierge), dupliquer, renommer, supprimer avec confirmation.
- Templates : créer, dupliquer, renommer, supprimer, créer depuis un personnage.
- Tri par date de modification, recherche.

### 5.2 Mise en page
- Hiérarchie : **Fiche → Pages → Rangées → Colonnes → Sections** (disposition « C » : une rangée a 1 à N colonnes, chaque colonne empile ses sections ; une rangée d'une seule colonne donne une section pleine largeur).
- La hauteur d'une section **suit son contenu** : plus de cellules carrées ni de contenu coupé.
- En portrait étroit, les colonnes d'une rangée passent les unes sous les autres.
- Les pages s'affichent en **onglets**, définis librement dans le template.
- L'ancienne grille (`SpanningGridLayout`, `recalculateGrid`) est archivée hors du build, dans `Archive/`, pour comparaison ou réutilisation.

### 5.3 Sections « Champs »
Disposition au choix : liste, grille de N colonnes, ou N listes côte à côte (l'existant).

### 5.4 Sections « Tableau » (V1 complète)
Elles servent aux compétences, aux armes, aux armures, aux défauts, aux pouvoirs, puis à l'inventaire.
- **Colonnes typées**, définies dans le template : texte, nombre, pourcentage, case à cocher, formule.
- **Groupes** avec en-tête (Communication, Mental…). Un groupe peut avoir sa propre valeur (bonus de catégorie BRP).
- **Lignes du template** (pré-remplies : nom, base) et **lignes ajoutées** par le joueur.
- **Spécialisation** : une ligne peut avoir un complément libre, par exemple « Langue (Latin) », « Connaissance (Hautes sphères) » ou « Monter (Navire) ». On peut la dupliquer pour en ajouter d'autres.
- **Colonnes vivantes** : par exemple la case « compétence utilisée » se coche en mode Jouer.
- **Affichage sur N colonnes** : les groupes se répartissent sur 2 ou 3 colonnes, comme sur la fiche papier.
- Cellules **formule** par ligne : base « =DEX×2 », colonnes dérivées « =valeur/2 » ou « =valeur/5 » pour Cthulhu.

### 5.5 Types de champs V1

| Type | Exemple (fiche Leo) | Notes |
|---|---|---|
| Texte court | Nom, Culture, Profession | |
| Texte long | Description, Notes de combat, Notes | Multiligne, hauteur adaptée |
| Entier | FOR 11 | min / max / pas optionnels, aucun max implicite |
| Décimal | Poids | |
| Pourcentage | Statut 55 % | Entier affiché avec % |
| Modificateur | Modificateur de dégâts | Affiché avec son signe ; texte libre accepté (« +1d4 ») |
| **Ressource** | PV 14, PM 13, SAN 47/65, Fatigue | Valeur actuelle et maximum. Affichage en compteur (+/−) ou en piste numérotée comme sur le papier. Seuils optionnels (blessure grave, inconscient). |
| Case à cocher | Case POU | |
| Choix | Latéralité | Liste d'options |
| Date | | Affichage localisé |
| **Image** | Portrait | Photo ou fichier importé |
| **Formule** | Jet d'idée =INT×5, PV =plafond((CON+TAI)/2) | Lecture seule, recalculée en direct |

Pour chaque champ : libellé, **code** (pour les formules), unité, aide, valeur par défaut, disposition, valeur vivante.

### 5.6 Formules (V1)
- Syntaxe de tableur : `=FOR*5`, `=plafond((CON+TAI)/2)`, `=PV/2`.
- Les références se font par **code** de champ. Dans un tableau, par nom de colonne de la même ligne (`=valeur/2`).
- Opérateurs `+ − × ÷` et parenthèses ; fonctions `arrondi`, `plancher`, `plafond`, `min`, `max`.
- Les cycles sont détectés ; une erreur s'affiche dans le champ sans bloquer la fiche.
- Une formule peut servir de **valeur par défaut** (ex. le max de SAN = POU×5). Elle reste alors modifiable à la main.
- **Tables de correspondance** (V1.1) : `=table(FOR+TAI; 12; "-1d6"; 16; "-1d4"; 24; "aucun"; …)`, éditables ligne à ligne dans l'inspecteur. Le résultat peut être un texte (« +1d4 »).

### 5.7 Données
- SwiftData avec sauvegarde automatique, **synchronisé par iCloud** depuis la V1.2 (§5.10). Schéma versionné (`VersionedSchema`).
- Le modèle reste **compatible CloudKit**. Une fois le schéma déployé en production, il ne peut plus qu'**ajouter** : nouveaux attributs (optionnels ou avec valeur par défaut) et nouveaux modèles ; jamais renommer, retyper ni supprimer un attribut ou un modèle.
- **Export / import JSON** des templates et des personnages (Fichiers, partage), pour la sauvegarde et le partage de templates.

### 5.8 Langue
Interface en français, avec un String Catalog prêt pour l'anglais.

---

### 5.9 Thèmes (V1.1)
- Trois thèmes : **Natif** (système), **Couleur du template** (bandeaux et titres teintés, palette de 10 couleurs du système), **Fiche papier** (papier crème au grain léger, encre, cadres à double filet avec le titre posé sur le filet, capitales gravées, lignes à compléter, cases à l'encre ; toujours clair).
- Le template choisit le thème (menu « Affichage ») ; ses personnages le suivent, même s'il change ensuite. Un personnage peut choisir le sien, ou revenir à « Comme le template ».
- **Ajouter un thème** : un fichier dans `Themes/` qui part de `SheetTheme()` et remplace ce qu'il veut — couleurs, polices (celles d'iOS : rien à télécharger ni à licencier), et pièces : fond de page, cadre de section, zone de saisie, case à cocher ; textures dessinées par le code. Puis une ligne dans `SheetThemes.all`. Les vues de la fiche ne changent pas.

### 5.10 Synchronisation iCloud (V1.2)
- **Toujours active** dès que l'appareil est connecté à iCloud, comme Notes ; elle se coupe dans Réglages d'iOS (compte Apple › iCloud), pas dans l'app. Base privée de l'utilisateur, conteneur `iCloud.ch.loristhomas.blason` ; SwiftData fait le travail.
- L'app ne signale que les **problèmes**, par un avis discret sous les cartes de la bibliothèque : iCloud désactivé ou bloqué (avis masquable : le joueur peut choisir de ne pas utiliser iCloud), compte à revalider, stockage plein, échec. Les erreurs passagères (réseau, service occupé) ne s'affichent pas ; un échec s'efface à la synchronisation réussie suivante.
- Plus de données de démo créées automatiquement (chaque appareil vide créerait les siennes, en double après synchronisation) : « Ajouter l'exemple BRP » dans la bibliothèque vide et dans le menu du bouton + (appui long).
- Conflits : la dernière modification d'un objet l'emporte (CloudKit). Deux appareils qui modifient le même champ en même temps gardent la dernière valeur reçue.
- **Avant la première publication** (TestFlight, App Store) : lancer une fois l'app de développement avec `-initCloudKitSchema YES` (connecté à iCloud) pour créer tous les types et champs, puis déployer le schéma en production dans CloudKit Console. Ensuite, le modèle ne fait plus qu'ajouter (§5.7).
- **Schéma V1 figé** : de vraies fiches existent, sur l'appareil et dans iCloud. La base n'est plus jamais recréée automatiquement (fin de `developmentRevision`) ; en développement, `-resetStore YES` la vide à la demande. Un test compare le schéma V1 à son empreinte : tout changement du modèle passe par un `SheetSchemaV2` et une migration testée.

**Clôture de la V1.2** (11 novembre 2026) — reste à faire à la main, hors du code :
1. Indicateur iCloud de diagnostic retiré (11 novembre 2026) ; seul l'avis de problème reste. Valider la synchronisation sur deux appareils réels (création, modification, suppression, image, hors ligne puis reconnexion) avant TestFlight.
2. App créée dans App Store Connect : **Blason - Fiches JDR**, identifiant `ch.loristhomas.blason`.
3. Avant TestFlight : `-initCloudKitSchema YES` sur un appareil connecté à iCloud, puis « Deploy Schema Changes » dans CloudKit Console.
4. Vérifier les marques Blason (Swissreg, EUIPO), §10.

## 6. Hors V1 (feuille de route)

| Prio | Fonction |
|---|---|
| V1.2 | **Synchronisation iCloud** (voir §5.10) : faite et close côté code (validation sur appareils et schéma de production à faire) ; prérequis pour iPhone et Mac |
| V2 | iPhone et Mac ; inventaire avancé ; **journal de campagne et documents** de session |
| plus tard | D'autres thèmes de fiche (parchemin, dossier années 20, terminal…), un fichier chacun |
| plus tard | Mise à jour d'un personnage depuis son template, Apple Pencil, volet MJ |
| bien plus tard | Jets de dés (depuis un champ ou une ligne, ex. d100 contre la compétence), après l'inventaire et les notes |

---

## 7. Modèle de données (proposition)

Chaque personnage possède sa propre copie de la structure. Les valeurs vivent donc **dans les champs et les cellules**, ce qui supprime `CharacterFieldValue`.

```
Template   { name, system, notes, sheet: Sheet, dates }
Character  { name, portrait?, sourceTemplate (nom, id), sheet: Sheet, dates }
Sheet      { pages: [Page] }
Page       { title, order, rows: [Row] }
Row        { order, columnWeights: [Double], sections: [Section] }
Section    { title, columnIndex, order (dans la colonne), kind: fields|table,
             fieldsArrangement, columnCount,
             fields: [Field],
             tableColumns: [TableColumn], tableGroups: [TableGroup] }
Field      { label, code, order, kind, config (min, max, pas, unité, options, piste…),
             value typée, formula?, isLive }
TableColumn{ title, code, order, kind, formula?, isLive }
TableGroup { title, order, value?, rows: [TableRow] }
TableRow   { order, label, specialization?, isFromTemplate, cells: [TableCell] }
TableCell  { columnCode, value typée, formula? }
```

- Dans un template, les valeurs font office de **valeurs par défaut**. Copier revient à faire une copie profonde de `Sheet`.
- Les valeurs sont **typées** : texte, nombre, booléen, date, actuel/max, image.
- Contraintes CloudKit : attributs avec valeur par défaut, relations optionnelles, pas de `unique`. Les images sont stockées en `externalStorage`.
- Les suppressions passent par `modelContext.delete` (plus de données orphelines).
- Le moteur de formules est un module **pur Swift**, sans SwiftData, testé unitairement.

---

## 8. Jalons

| # | Jalon | Contenu | Taille | Critère de fin |
|---|---|---|---|---|
| M0 | Nettoyage | Code mort, archivage de la grille, avertissements Swift 6, cible iPad, String Catalog | S | Build propre, sans avertissement |
| M1 | Modèle v2 | Nouveau modèle, copie template → personnage, **template BRP de démo et Leo en données de seed** | M | Tests verts : copier, dupliquer, supprimer sans données orphelines |
| M2 | Rendu de la fiche | Pages, rangées et colonnes, sections Champs et Tableau, tous les types, modes Remplir et Jouer | L | La fiche de Leo s'affiche et se joue (à partir du seed) |
| M3 | Bibliothèque | Split view, cycle de vie des personnages et des templates | S | Créer, dupliquer et supprimer depuis un template |
| M4 | Éditeur Structure | Sélection, inspecteur, ajout rapide, coller une liste, dupliquer / copier-coller, glisser, annuler | L | **Template BRP recréé de zéro en moins de 20 min** |
| M5 | Formules | Moteur, références, cycles, colonnes dérivées | M | Tous les jets ×5, les PV et les bases des compétences sont calculés |
| M6 | Export / import | JSON pour les templates et les personnages | S | Aller-retour sans perte |
| M7 | Finition | Design, icône, états vides, accessibilité de base | M | Utilisé en vraie partie |

---

## 9. Journal des décisions

| Date | Décision |
|---|---|
| 2026-11-09 | Public : joueur, usage personnel ; publication éventuelle ; volet MJ plus tard. |
| 2026-11-09 | Systèmes génériques (BRP, Cthulhu, systèmes moins connus), un template par système ; D&D hors cible. |
| 2026-11-09 | Template **copié** dans le personnage, pas partagé. |
| 2026-11-09 | Tableaux complets et formules en V1 ; tables de correspondance en V1.1. |
| 2026-11-09 | Mise en page Page → Rangée → Section, hauteur selon le contenu ; ancienne grille archivée. |
| 2026-11-09 | Une seule vue de fiche avec trois modes (Structure / Remplir / Jouer) et un inspecteur latéral. |
| 2026-11-09 | Pages en onglets ; en portrait, les colonnes d'une rangée passent les unes sous les autres. |
| 2026-11-09 | Disposition « C » : chaque rangée a 1 à N colonnes qui empilent leurs sections. Les onglets sont conservés pour l'instant ; un défilement continu (sans pages) sera réévalué une fois la fiche visible. |
| 2026-11-09 | Ordre des jalons inchangé ; l'interface de M2 à M6 est fonctionnelle et sobre, le design est traité en M7. |
| 2026-11-09 | iPad seul en V1, code multiplateforme ; iCloud puis iPhone et Mac ensuite. |
| 2026-11-09 | Données actuelles jetables ; export / import JSON en V1. |
| 2026-11-09 | Fiche de Leo (BRP) comme référence et critère d'acceptation ; PDF exclu de git. |
| 2026-11-09 | M0 : Swift 6 (concurrence stricte) ; entitlements iCloud et push retirés jusqu'à la V1.2 ; langue de développement `fr`. |
| 2026-11-09 | M1 : modèle et logique dans un package local `SheetKit` (multiplateforme, testé par `swift test`). Types renommés pour éviter les collisions : `PlayerCharacter` (≠ `Swift.Character`), `SheetSection` (≠ `SwiftUI.Section`). |
| 2026-11-09 | M1 : un champ de la fiche peut porter le nom du personnage (`isNameField`) ; c'est lui qu'affiche la bibliothèque. |
| 2026-11-09 | M1 : « Enregistrer comme template » conserve les valeurs du personnage (elles deviennent les défauts), à nettoyer en mode Remplir. |
| 2026-11-09 | M1 : syntaxe de formule pour le maximum d'une ressource : `PV.max`. Une ressource avec formule voit celle-ci calculer son maximum. |
| 2026-11-09 | M1 : base stockée dans `CharacterSheet.store` (devenue `Blason.store` le 2026-11-11) ; l'ancienne `default.store` (modèle v0) est ignorée. |
| 2026-11-09 | M2 : types de tableau renommés `SheetTableColumn`, `SheetTableGroup`, `SheetTableRow`, `SheetTableCell` (collision avec SwiftUI `TableColumn` / `TableRow`). |
| 2026-11-09 | M2 : **SwiftData migre silencieusement** une base dont le modèle a changé, même sans nouvelle version de schéma (constaté : tableaux perdus). En développement, `SheetStore.developmentRevision` (à incrémenter à chaque changement du modèle) recrée la base (retiré le 2026-11-11 : schéma V1 figé). **Dès que de vraies fiches existent, tout changement du modèle passe par un `SheetSchemaV2` et une migration testée.** |
| 2026-11-09 | M3 : personnages triés par date de modification (mise à jour à chaque enregistrement fait pendant que la fiche est ouverte) ; templates triés par nom, plus utile pour retrouver un système. Ouvrir une fiche masque la barre latérale. |
| 2026-11-09 | M2 : un tableau affiche autant de colonnes d'affichage que la largeur le permet (au plus `columnCount`) ; la saisie demande plus de place que la lecture (ex. compétences : 3 colonnes en Jouer, 2 en Remplir en portrait). |
| 2026-11-09 | M4 : la logique de l'éditeur (`StructureEditor` : sélection, presse-papiers, coller une liste, glisser-déposer, déplacements) vit dans SheetKit et est testée ; l'app n'en garde que l'affichage. |
| 2026-11-09 | M4 : tout est sélectionnable, pas seulement sections et champs : page (bouton à côté des onglets), rangée (en-tête), colonne, groupe et ligne de tableau. Les valeurs ne se modifient pas sur la fiche en Structure, mais dans l'inspecteur (« Valeur par défaut » sur un template). |
| 2026-11-09 | M4 : l'inspecteur est un panneau maison (feuille sur écran étroit) : le `.inspector` de SwiftUI empêchait d'ouvrir la fiche dans la pile de navigation de la bibliothèque (iPadOS 26). |
| 2026-11-09 | M4 : presse-papiers propre à l'app (références aux éléments copiés, valable pendant la session) ; le presse-papiers système (copier une section d'une app à l'autre) pourra s'appuyer sur le format JSON de M6 ; pas prévu en V1. Les codes de champ collés ou dupliqués sont rendus uniques (`FOR` → `FOR2`) ; un seul champ « nom » par fiche. |
| 2026-11-09 | M4 : glisser un élément sur un autre lui fait prendre sa place ; lâché sur un élément d'un autre type, il remonte au conteneur le plus proche qui l'accepte (une section lâchée sur un champ se place à la section de ce champ). Une ligne déplacée vers un autre tableau garde les valeurs des colonnes de même code. |
| 2026-11-09 | M4 : sélection multiple avec ⌘ ou ⇧ + toucher (clavier physique) ou le menu contextuel « Ajouter à la sélection ». Supprimer : ⌘⌫ (⌫ seul entrerait en conflit avec la saisie). Annuler / rétablir : sur toutes les modifications, dans tous les modes sauf Jouer. |
| 2026-11-09 | M4 : « Coller une liste » — champs : `libellé;valeur;code` ; tableau : `libellé;valeur par colonne saisissable`, `# Groupe;bonus`, `Langue (…)` (spécialisation à préciser), `Monter (Navire)` (précisée). Une valeur `=…` est une formule ; une ressource accepte `47/65`. |
| 2026-11-09 | M5 : moteur de formules en Swift pur dans SheetKit (analyse, évaluation, mémorisation par calcul, détection des cycles). Fonctions : `plafond`, `plancher`, `arrondi` (1 ou 2 arguments), `min`, `max`, `abs`, avec alias anglais ; opérateurs × ÷ − acceptés ; arguments séparés par `;` (ou `,`). |
| 2026-11-09 | M5 : une valeur non saisie rend le calcul vide (« — »), sans erreur ; codes inconnus, cycles, divisions par zéro et syntaxe invalide s'affichent dans le champ. |
| 2026-11-09 | M5 : formule = valeur **par défaut** pour tout champ ou cellule numérique (affichée en gris en Remplir) ; la saisie la remplace, l'effacer revient au calcul. Champ ou colonne « Calcul » : lecture seule. Ressource : la formule calcule le maximum ; `PV` = actuel, `PV.max` = maximum. |
| 2026-11-09 | M5 : dans un tableau, une référence désigne d'abord une colonne de la même ligne, puis `groupe` (valeur du groupe, 0 si vide), puis un champ. Une colonne peut porter une formule par défaut : le template BRP de démo calcule `% = base + groupe`. Référence à une ligne d'un autre tableau (ex. `Esquive.valeur`) : pas en V1. |
| 2026-11-09 | M6 : un fichier `.json` par template ou personnage (format `character-sheet`, renommé `blason` le 2026-11-11, version 1), lisible et stable : clés triées, ordre des éléments donné par les tableaux, dates ISO 8601 à la milliseconde (arrondie : réexporter un fichier importé donne le même fichier), images en base64. Un test vérifie que chaque attribut du modèle figure dans le format. |
| 2026-11-09 | M6 : « Exporter… » ouvre la feuille de partage (Enregistrer dans Fichiers, AirDrop, Mail…) depuis le menu d'une carte ou la barre de la fiche ; « Importer » dans la bibliothèque accepte plusieurs fichiers, templates et personnages mélangés, et ouvre l'élément s'il est seul. Un élément importé une deuxième fois reçoit un nouvel identifiant. Un fichier d'une version plus récente est refusé avec un message clair. |
| 2026-11-09 | M7 : deux dispositions des pages, au choix dans le menu « Affichage » de la barre (préférence de l'appareil, commune aux fiches) : **une page à la fois** (onglets) ou **toutes les pages à la suite**, chacune sous son titre ; la barre des pages suit alors la page visible et un **Sommaire** mène à n'importe quelle section. |
| 2026-11-09 | M7 : thème **natif** seul pour l'instant (couleurs et typographie du système, clair / sombre). Les couleurs, formes et polices de la fiche passent toutes par un thème (`SheetTheme`), pour ajouter ensuite « couleur du template » et « fiche papier » sans toucher aux vues. |
| 2026-11-09 | M7 : les nombres se mettent à jour pendant la frappe (les formules qui en dépendent aussi). La virgule est décimale ; les séparateurs de milliers (espace, apostrophe suisse) sont acceptés. Une valeur vide s'affiche « — » estompé, partout. |
| 2026-11-09 | M7 : une section de champs trop étroite (inspecteur ouvert, grand texte) passe à moins de colonnes plutôt que de couper ses libellés ; dans un tableau, la précision (« Hautes sphères ») est coupée avant le nom de la compétence. |
| 2026-11-09 | M7 : compétences à spécialiser (Connaissance, Langue, Monter…) : en Jouer et Remplir, une ligne de catégorie puis chaque spécialité en retrait avec ses valeurs, même s'il n'y en a qu'une ; en Jouer, une compétence encore sans précision reste sur une ligne (« Langue 0 0 »). En Remplir, ⊕ sur la catégorie ajoute une spécialité : elle reprend la base et les formules, pas la valeur saisie ni la case « Exp. ». Le mode Structure montre les lignes du template telles quelles. Les spécialités d'une famille sont les lignes à spécialiser de même libellé dans le groupe : pas de changement de modèle. |
| 2026-11-09 | V1.1 : une table de correspondance s'écrit dans la formule du champ ou de la colonne : `=table(valeur; seuil; résultat; …; [au-delà])`. Chaque seuil est compris (« jusqu'à ») ; sans « au-delà », le champ reste vide au-dessus du dernier seuil. Pas de changement du modèle ni du format d'export ; une table servant à deux champs est recopiée. L'inspecteur l'édite ligne à ligne (« Table de correspondance… ») et relit la formule. |
| 2026-11-09 | V1.1 : une formule peut donner du **texte** (`"aucun"`, « +1d4 », guillemets droits ou typographiques). Un texte qui se lit comme un nombre (« +2 ») se calcule ; un autre (« +1d4 ») utilisé dans un calcul est une erreur « Valeur non numérique ». Un modificateur saisi à la main (texte ou nombre) remplace la table. Le template BRP de démo calcule le modificateur de dégâts (Leo : FOR 11 + TAI 15 = 26 → +1d4). |
| 2026-11-09 | V1.1 : thèmes modulaires. Un thème = couleurs, polices et quatre pièces remplaçables (fond de page, cadre de section, zone de saisie, case à cocher) ; le natif fournit tout, un thème ne remplace que ce qu'il veut. Thème et couleur sont enregistrés dans la fiche par identifiant (`themeID`, `themeColor`) et exportés ; un identifiant inconnu revient au natif. Un personnage sans thème propre suit son template. |
| 2026-11-09 | V1.1 : palette plutôt que couleur libre ; en « Couleur du template », titres et pleins sont assombris en clair et éclaircis en sombre pour rester lisibles (sarcelle, orange). La fiche papier reste claire en mode sombre, comme une vraie feuille. |
| 2026-11-09 | M7 : accessibilité de base : chaque saisie, case et ressource porte le nom de son champ (ou « ligne, colonne » dans un tableau) ; en lecture, libellé et valeur sont lus ensemble ; une ressource s'ajuste par balayage avec VoiceOver ; titres de page et de section annoncés comme titres ; tailles qui suivent la taille du texte. |
| 2026-11-10 | V1.2 : synchronisation iCloud toujours active, sans réglage dans l'app ; seuls les problèmes s'affichent ; exemple BRP ajouté par un bouton plutôt qu'au premier lancement. Les jets de dés passent bien plus tard, après l'inventaire et les notes. |
| 2026-11-11 | V1.2 : synchronisation iCloud par SwiftData (base privée). Nom affiché « Blason », identifiant `ch.loristhomas.blason`. Les avis de problème se placent sous les cartes de la bibliothèque (la barre latérale est souvent masquée en portrait), pas dans les fiches. L'exemple BRP s'ajoute à la demande ; en développement, `-seedDemo YES` le crée au lancement pour les captures. |
| 2026-11-11 | Projet renommé **Blason** partout : dossier des sources et projet Xcode (`Blason/`, `Blason.xcodeproj`), cible et produit, `BlasonApp`. La base devient `Blason.store` : une base `CharacterSheet.store` est renommée au lancement avec son journal, ses images et son cache iCloud (l'état de la synchronisation, stocké dans la base, suit). Le format d'export s'appelle `blason` ; `character-sheet` reste accepté à l'import (même format, version 1). |
| 2026-11-11 | Clôture de la V1.2 : le schéma V1 est figé (test d'empreinte des attributs et relations) ; plus de recréation automatique de la base, ni au changement de révision ni quand elle ne s'ouvre pas ; `-resetStore YES` la vide à la demande en développement (base, images et cache iCloud). L'indicateur iCloud reste dans les builds de développement le temps de valider la synchronisation sur des appareils réels. Prochaine étape : V2, en commençant par iPhone et Mac. |
| 2026-11-11 | Indicateur iCloud de diagnostic retiré (seul l'avis de problème reste ; le correctif des exports annulés, qui ne sont pas des échecs, est conservé). App créée dans App Store Connect sous le nom « Blason - Fiches JDR » ; le nom affiché sous l'icône reste « Blason ». |

## 10. Questions ouvertes

- **Nom de l'app et icône** : **Blason** est retenu. Nom réservé dans App Store Connect : « Blason - Fiches JDR » (le nom sous l'icône reste « Blason »). Reste à vérifier les marques sur Swissreg et à l'EUIPO. L'icône est un d10 taillé en blason, en terre cuite (`AppIcon.icon`, sources dans `Design/Blason`) ; l'ancienne icône provisoire (feuille + dé) reste dans `Design/IconeProvisoire`. Identifiant de l'app fixé avec la synchronisation iCloud : `ch.loristhomas.blason`, conteneur `iCloud.ch.loristhomas.blason` (définitif). Le nom affiché, lui, peut changer plus tard.

### 10.1 Pistes autour de « Blason »

Des idées à garder pour y revenir, **pas des exigences**.

- **Vocabulaire**, avec parcimonie : la bibliothèque comme **Armorial** (le recueil des blasons) ; la **Besace** pour l'inventaire (V2) ; les **émaux** pour les couleurs ; éventuellement la **brisure** (la marque qui distingue les armes d'un cadet de celles de sa famille) pour « créer un personnage depuis ce template ». Slogan possible : « Le blason de tes personnages ». Le *blason* est aussi un poème de la Renaissance qui décrit quelqu'un attribut par attribut, c'est-à-dire une fiche de personnage.
- **Règle des émaux** : pas de métal (or, argent) sur métal, ni de couleur (azur, gueules, sinople, sable) sur couleur. C'est une règle de contraste, utilisable pour l'icône et pour la palette « Couleur du template ».
- **Hachures** héraldiques (azur en traits horizontaux, gueules en traits verticaux, or en points…) : le thème Fiche papier pourrait rendre la couleur du template en hachures, en restant monochrome.
- **Un petit écu par personnage** dans la bibliothèque, teinté de la couleur de son template, quand il n'a pas de portrait.
- **Icônes alternatives** au choix dans l'app : les autres teintes héraldiques (gueules, or, sinople, sarcelle, azur, pourpre, graphite), unies ou à coins d'or, et la terre cuite à coins d'or, sont déjà dans le projet (`AppIcons/`, déclarées dans `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`). Reste à faire le choix dans les réglages (`setAlternateIconName`). Autre idée : une version gravée pour le thème papier.
- **Icône iOS 26** en calques (Icon Composer : clair, sombre, teinté) : l'écu et ses motifs sur des calques séparés.
- **Constellations de dés** (d20, d100 en deux d10) : plutôt en illustration (bibliothèque vide, À propos) qu'en icône, où elles deviennent illisibles en petit.
- **Écu et sécurité** : un écu seul, surtout avec une coche, évoque les apps de sécurité ou de VPN. L'icône doit montrer la fiche ou le JDR.
