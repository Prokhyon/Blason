import SwiftUI

/// Onglet de l'écran d'un personnage ou d'un template : la fiche, la Besace, le journal.
enum CharacterTab: String, CaseIterable, Identifiable {
    case sheet
    case inventory
    case journal

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .sheet: "Fiche"
        case .inventory: "Inventaire"
        case .journal: "Journal"
        }
    }

    var symbol: String {
        switch self {
        case .sheet: "person.text.rectangle"
        case .inventory: "backpack"
        case .journal: "book.closed"
        }
    }

    /// Raccourci du menu Fiche (⌥⌘1 à ⌥⌘3).
    var shortcut: KeyEquivalent {
        switch self {
        case .sheet: "1"
        case .inventory: "2"
        case .journal: "3"
        }
    }
}
