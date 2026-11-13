import Foundation

/// Sorte de section : une liste de champs, un tableau (lignes × colonnes), une Besace,
/// ou une vue de la Besace (objets équipés, ailleurs sur la fiche).
public enum SectionKind: String, Codable, CaseIterable, Sendable {
    case fields
    case table
    case inventory
    case inventoryView

    /// La Besace s'affiche dans l'onglet Inventaire, pas sur les pages de la fiche.
    public var isShownOnSheet: Bool { self != .inventory }
}

/// Disposition des champs dans une section « Champs ».
public enum FieldArrangement: String, Codable, CaseIterable, Sendable {
    /// Un champ par ligne.
    case list
    /// Grille de `columnCount` colonnes, remplie dans l'ordre.
    case grid
    /// `columnCount` listes côte à côte ; chaque champ choisit sa liste (`listIndex`).
    case columns
    /// Deux listes (`listIndex` 0 et 1) lues rang par rang : chaque champ de gauche à côté de
    /// celui de droite (FOR → Effort), lignes alignées.
    case pairs
    /// Mêmes deux listes, en tuiles : la valeur de gauche en grand, celle de droite en petit dessous.
    case tiles

    /// Les champs se répartissent entre plusieurs listes (`listIndex`).
    public var usesLists: Bool { self == .columns || self == .pairs || self == .tiles }

    /// Nombre de listes : `columnCount` pour les listes côte à côte, deux pour Paires et Tuiles.
    public func listCount(columnCount: Int) -> Int {
        switch self {
        case .columns: max(1, columnCount)
        case .pairs, .tiles: 2
        case .list, .grid: 1
        }
    }
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
    /// Case vide, sans valeur : laisse une place libre (TAI n'a pas de jet en face).
    case spacer
}

/// Largeur d'un champ dans une grille (disposition `grid`), en sixièmes de la section.
public enum FieldWidth: String, Codable, CaseIterable, Sendable {
    /// Selon le type : nombre et case ⅓, texte court ½, texte long et image pleine largeur.
    case auto
    case full
    case half
    case third

    /// Largeur en sixièmes de la section.
    public func sixths(for kind: FieldKind, resourceStyle: ResourceStyle = .counter) -> Int {
        switch self {
        case .full: return 6
        case .half: return 3
        case .third: return 2
        case .auto:
            switch kind {
            case .longText, .image: return 6
            case .resource: return resourceStyle == .track ? 6 : 3
            case .text, .choice, .date: return 3
            case .integer, .decimal, .percentage, .modifier, .checkbox, .formula, .spacer: return 2
            }
        }
    }
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

/// Genre d'une fiche du journal.
public enum CodexKind: String, Codable, CaseIterable, Sendable {
    case npc
    case place
    case clue
    case faction
    case other
}
