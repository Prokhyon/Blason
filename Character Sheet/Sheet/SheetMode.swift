import SwiftUI

/// Mode d'affichage de la fiche (SPEC §4). Le mode Structure arrive avec l'éditeur (M4).
enum SheetMode: String, CaseIterable, Identifiable {
    /// Toutes les valeurs sont modifiables.
    case fill
    /// Seules les valeurs vivantes (PV, SAN, cases « Exp. »…) sont modifiables.
    case play

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .fill: "Remplir"
        case .play: "Jouer"
        }
    }

    /// Une valeur est modifiable en Remplir, ou en Jouer si elle est vivante.
    func canEdit(live: Bool) -> Bool {
        self == .fill || live
    }
}

extension EnvironmentValues {
    @Entry var sheetMode: SheetMode = .play
}

extension View {
    /// Fond discret qui signale un champ de saisie.
    func inputBackground() -> some View {
        padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
    }
}
