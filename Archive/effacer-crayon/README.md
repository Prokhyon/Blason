# Bouton « effacer un caractère » au crayon (archivé)

Pendant l'écriture au Pencil (Scribble), un bouton flottant en bas à droite du récit d'une
session effaçait **un seul caractère** (maintenu, il répétait), au lieu de barrer tout un mot
pour une petite correction. La palette Scribble du système ne se modifie pas : c'était un
bouton propre à l'app.

Mis de côté le 12 novembre 2026, avant tout essai avec un vrai Pencil (le simulateur ne
déclenche pas Scribble). Les contrôles du test sans interface passaient.

| Morceau | Où il se branchait |
|---|---|
| `isPencilWriting`, `deleteBackward()` | `Blason/Journal/Editor/JournalEditorController.swift` |
| Détection de Scribble et du clavier | `Blason/Journal/Editor/JournalTextView.swift` (iOS) |
| `pencilDeleteButton` et son overlay | `Blason/Journal/JournalSessionEditor.swift` |
| Deux contrôles | `Blason/Journal/Editor/JournalEditorSelfTest.swift` |

Fonctionnement : `deleteBackward()` passe par `shouldChange(in:replacement:)` (mêmes règles que
la touche ⌫ : citation effacée d'un bloc, puce qui arrête la liste), puis efface par une
modification annulable de l'éditeur. Appeler `UITextView.deleteBackward()` ne suffisait pas :
dans le test sans interface, rien n'était effacé.

Ces fichiers sont **hors du build** (le dossier `Archive/` n'est pas dans le target).
