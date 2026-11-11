import SwiftUI

/// Demande faite à la bibliothèque depuis un menu (barre des menus du Mac, ou de l'iPad avec un clavier).
enum LibraryRequest: Equatable {
    case newCharacter
    case newTemplate
    case importFiles
}

/// Actions de la bibliothèque, publiées par la fenêtre active pour les menus.
struct LibraryActions {
    let perform: (LibraryRequest) -> Void
}

extension FocusedValues {
    @Entry var libraryActions: LibraryActions?
    /// Mode de la fiche ouverte (menu Fiche).
    @Entry var sheetModeBinding: Binding<SheetMode>?
}

/// Menus de l'app : Fichier (nouveau, importer) et Fiche (mode, ⌘1 à ⌘3).
struct BlasonCommands: Commands {
    @FocusedValue(\.libraryActions) private var library
    @FocusedValue(\.sheetModeBinding) private var mode

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
        }
    }
}
