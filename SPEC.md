# Character Sheet — Spécification

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
- **V1.1** : tables de correspondance (ex. modificateur de dégâts selon FOR+TAI). D'ici là, ce champ reste saisi à la main.

### 5.7 Données
- Stockage local (SwiftData) avec sauvegarde automatique. Les données actuelles sont jetables (repartir de zéro est accepté).
- Le modèle doit rester **compatible CloudKit** dès maintenant. Schéma versionné (`VersionedSchema`).
- **Export / import JSON** des templates et des personnages (Fichiers, partage), pour la sauvegarde et le partage de templates.

### 5.8 Langue
Interface en français, avec un String Catalog prêt pour l'anglais.

---

## 6. Hors V1 (feuille de route)

| Prio | Fonction |
|---|---|
| V1.1 | Tables de correspondance dans les formules |
| V1.2 | Jets de dés (depuis un champ ou une ligne, ex. d100 contre la compétence) |
| V1.2 | **Synchronisation iCloud** : prérequis pour iPhone et Mac |
| V2 | iPhone et Mac ; inventaire avancé ; **journal de campagne et documents** de session |
| plus tard | Mise à jour d'un personnage depuis son template, Apple Pencil, volet MJ |

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
| 2026-11-09 | M1 : base stockée dans `CharacterSheet.store` ; l'ancienne `default.store` (modèle v0) est ignorée. |
| 2026-11-09 | M2 : types de tableau renommés `SheetTableColumn`, `SheetTableGroup`, `SheetTableRow`, `SheetTableCell` (collision avec SwiftUI `TableColumn` / `TableRow`). |
| 2026-11-09 | M2 : **SwiftData migre silencieusement** une base dont le modèle a changé, même sans nouvelle version de schéma (constaté : tableaux perdus). En développement, `SheetStore.developmentRevision` (à incrémenter à chaque changement du modèle) recrée la base. **Dès que de vraies fiches existent, tout changement du modèle passe par un `SheetSchemaV2` et une migration testée.** |
| 2026-11-09 | M3 : personnages triés par date de modification (mise à jour à chaque enregistrement fait pendant que la fiche est ouverte) ; templates triés par nom, plus utile pour retrouver un système. Ouvrir une fiche masque la barre latérale. |
| 2026-11-09 | M2 : un tableau affiche autant de colonnes d'affichage que la largeur le permet (au plus `columnCount`) ; la saisie demande plus de place que la lecture (ex. compétences : 3 colonnes en Jouer, 2 en Remplir en portrait). |

## 10. Questions ouvertes

Aucune pour l'instant.
