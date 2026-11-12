import Foundation

/// Sorte de section : une liste de champs, un tableau (lignes × colonnes), une Besace,
/// ou une vue de la Besace (objets équipés, ailleurs sur la fiche).
public enum SectionKind: String, Codable, CaseIterable, Sendable {
    case fields
    case table
    case inventory
    case inventoryView
}

/// Disposition des champs dans une section « Champs ».
public enum FieldArrangement: String, Codable, CaseIterable, Sendable {
    /// Un champ par ligne.
    case list
    /// Grille de `columnCount` colonnes, remplie dans l'ordre.
    case grid
    /// `columnCount` listes côte à côte ; chaque champ choisit sa liste (`listIndex`).
    case columns
}

/// Type d'un champ.
public enum FieldKind: String, Codable, CaseIterable, Sendable {
    case text
    case longText
    case integer
    case decimal
    case percentage
    /// Nombre signé (+2 / −1) ; accepte aussi un texte libre (« +1d4 »).
    case modifier
    /// Valeur actuelle / maximum (PV, PM, SAN…). Une formule éventuelle calcule le maximum.
    case resource
    case checkbox
    case choice
    case date
    case image
    /// Valeur calculée, en lecture seule.
    case formula
}

/// Position du libellé par rapport à la valeur.
public enum LabelPlacement: String, Codable, CaseIterable, Sendable {
    case leading
    case top
}

/// Affichage d'une ressource.
public enum ResourceStyle: String, Codable, CaseIterable, Sendable {
    /// Compteur avec boutons +/−.
    case counter
    /// Piste numérotée, comme sur la fiche papier.
    case track
}

/// Type d'une colonne de tableau.
public enum ColumnKind: String, Codable, CaseIterable, Sendable {
    case text
    case number
    case percentage
    case checkbox
    /// Valeur calculée (ex. `=valeur/2`), en lecture seule.
    case formula
}
