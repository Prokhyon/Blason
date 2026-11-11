import SwiftUI

/// Mode d'affichage de la fiche (SPEC §4).
enum SheetMode: String, CaseIterable, Identifiable {
    /// Construction : sélection d'éléments, inspecteur, ajouts. Les valeurs ne sont pas modifiables
    /// directement sur la fiche (elles le sont dans l'inspecteur).
    case structure
    /// Toutes les valeurs sont modifiables.
    case fill
    /// Seules les valeurs vivantes (PV, SAN, cases « Exp. »…) sont modifiables.
    case play

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .structure: "Structure"
        case .fill: "Remplir"
        case .play: "Jouer"
        }
    }

    /// Une valeur est modifiable en Remplir, ou en Jouer si elle est vivante ; jamais en Structure.
    func canEdit(live: Bool) -> Bool {
        self == .fill || (self == .play && live)
    }
}

extension EnvironmentValues {
    @Entry var sheetMode: SheetMode = .play
}
