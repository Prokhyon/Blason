# Grille v0 (archivée)

Ancienne mise en page de la fiche : une grille de N colonnes à **cellules carrées**,
où chaque section occupe `largeur × hauteur` cellules et se place automatiquement
(premier emplacement libre, dans l'ordre des sections).

Elle est remplacée dans la spec v1 par le modèle **Page → Rangées → Sections**
(hauteur selon le contenu), voir `SPEC.md` §5.2.

| Fichier | Contenu |
|---|---|
| `SpanningGridLayout.swift` | `Layout` SwiftUI qui positionne les sections selon `gridOrigin`, `width`, `height` |
| `RecalculateGrid.swift` | Algorithme de placement (`CharacterLayout.recalculateGrid`) et `GridPosition` |

Ces fichiers sont **hors du build** (le dossier `Archive/` n'est pas dans le target).
Le code d'origine reste utilisé par l'app jusqu'au remplacement du rendu (jalon M2) ;
la version complète est aussi dans l'historique git (commit `6c6b2c9`).

Défauts connus, pour mémoire : contenu coupé quand il dépasse la cellule, taille des
cellules qui change entre portrait et paysage, boucle infinie si une section est plus
large que la grille.
