import SwiftUI

/// Demande faite à la bibliothèque depuis un menu (barre des menus du Mac, ou de l'iPad avec un clavier).
enum LibraryRequest: Equatable {
    case newCharacter
    case newTemplate
    case importFiles
}

/// Journal de la fiche ouverte (menu Fiche › Journal).
struct JournalActions {
    let isOpen: Bool
    let toggle: () -> Void
}

/// Actions de la bibliothèque, publiées par la fenêtre active pour les menus.
struct LibraryActions {
    let perform: (LibraryRequest) -> Void
}

extension FocusedValues {
    @Entry var libraryActions: LibraryActions?
    /// Mode de la fiche ouverte (menu Fiche).
    @Entry var sheetModeBinding: Binding<SheetMode>?
    /// Journal du personnage ouvert (menu Fiche).
    @Entry var journalActions: JournalActions?
}

/// Menus de l'app : Fichier (nouveau, importer) et Fiche (mode, ⌘1 à ⌘3 ; journal, ⌘J).
struct BlasonCommands: Commands {
    @FocusedValue(\.libraryActions) private var library
    @FocusedValue(\.sheetModeBinding) private var mode
    @FocusedValue(\.journalActions) private var journal

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nouveau personnage") { library?.perform(.newCharacter) }
                .keyboardShortcut("n")
                .disabled(library == nil)
            Button("Nouveau template") { library?.perform(.newTemplate) }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(library == nil)
            Divider()
            Button("Importer…") { library?.perform(.importFiles) }
                .keyboardShortcut("o")
                .disabled(library == nil)
        }
        CommandMenu("Fiche") {
            ForEach(Array(SheetMode.allCases.enumerated()), id: \.element) { index, item in
                Toggle(item.title, isOn: Binding(
                    get: { mode?.wrappedValue == item },
                    set: { if $0 { mode?.wrappedValue = item } }
                ))
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))))
            }
            .disabled(mode == nil)
            Divider()
            Button(journal?.isOpen == true ? "Fermer le journal" : "Journal") { journal?.toggle() }
                .keyboardShortcut("j")
                .disabled(journal == nil)
        }
    }
}
