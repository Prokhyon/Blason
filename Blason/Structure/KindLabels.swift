import SwiftUI
import SheetKit

// Libellés et symboles des types, pour les menus et l'inspecteur.

extension FieldKind {
    var title: LocalizedStringKey {
        switch self {
        case .text: "Texte"
        case .longText: "Texte long"
        case .integer: "Nombre entier"
        case .decimal: "Nombre décimal"
        case .percentage: "Pourcentage"
        case .modifier: "Modificateur (+/−)"
        case .resource: "Ressource (PV, PM…)"
        case .checkbox: "Case à cocher"
        case .choice: "Choix dans une liste"
        case .date: "Date"
        case .image: "Image"
        case .formula: "Calcul (formule)"
        }
    }

    var symbol: String {
        switch self {
        case .text: "textformat"
        case .longText: "text.alignleft"
        case .integer: "number"
        case .decimal: "number.circle"
        case .percentage: "percent"
        case .modifier: "plusminus"
        case .resource: "heart"
        case .checkbox: "checkmark.square"
        case .choice: "list.bullet"
        case .date: "calendar"
        case .image: "photo"
        case .formula: "function"
        }
    }

    var isNumeric: Bool {
        [.integer, .decimal, .percentage, .modifier].contains(self)
    }
}

extension SectionKind {
    var title: String {
        switch self {
        case .fields: String(localized: "Champs")
        case .table: String(localized: "Tableau")
        case .inventory: String(localized: "Besace")
        case .inventoryView: String(localized: "Vue de la Besace")
        }
    }
}

extension ColumnKind {
    var title: LocalizedStringKey {
        switch self {
        case .text: "Texte"
        case .number: "Nombre"
        case .percentage: "Pourcentage"
        case .checkbox: "Case à cocher"
        case .formula: "Calcul (formule)"
        }
    }

    var symbol: String {
        switch self {
        case .text: "textformat"
        case .number: "number"
        case .percentage: "percent"
        case .checkbox: "checkmark.square"
        case .formula: "function"
        }
    }
}

extension FieldArrangement {
    var title: LocalizedStringKey {
        switch self {
        case .list: "Liste"
        case .grid: "Grille"
        case .columns: "Listes côte à côte"
        }
    }
}

extension LabelPlacement {
    var title: LocalizedStringKey {
        switch self {
        case .leading: "À gauche"
        case .top: "Au-dessus"
        }
    }
}

extension ResourceStyle {
    var title: LocalizedStringKey {
        switch self {
        case .counter: "Compteur"
        case .track: "Piste numérotée"
        }
    }
}
