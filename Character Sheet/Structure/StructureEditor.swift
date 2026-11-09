import SwiftUI
import SheetKit

extension StructureItem {
    var kindName: LocalizedStringKey {
        switch kind {
        case .page: "Page"
        case .row: "Rangée"
        case .section: "Section"
        case .field: "Champ"
        case .column: "Colonne"
        case .group: "Groupe"
        case .tableRow: "Ligne"
        }
    }
}

extension EnvironmentValues {
    /// Éditeur de la fiche ouverte (nil hors d'une fiche, par exemple dans les aperçus).
    @Entry var structureEditor: StructureEditor?
}
