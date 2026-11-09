import Foundation

// Recherche dans une fiche (par code ou par titre, sans tenir compte de la casse).

extension Sheet {
    /// Toutes les sections, dans l'ordre de lecture (page, rangée, section).
    public var allSections: [SheetSection] {
        sortedPages.flatMap { $0.sortedRows.flatMap(\.sortedSections) }
    }

    public var allFields: [SheetField] {
        allSections.flatMap(\.sortedFields)
    }

    /// Champ qui porte le nom du personnage.
    public var nameField: SheetField? {
        allFields.first { $0.isNameField }
    }

    public func field(code: String) -> SheetField? {
        allFields.first { !$0.code.isEmpty && $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }

    public func section(titled title: String) -> SheetSection? {
        allSections.first { $0.title.caseInsensitiveCompare(title) == .orderedSame }
    }
}

extension SheetSection {
    public func column(code: String) -> SheetTableColumn? {
        sortedColumns.first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }

    public func group(titled title: String) -> SheetTableGroup? {
        sortedGroups.first { $0.title.caseInsensitiveCompare(title) == .orderedSame }
    }

    /// Toutes les lignes du tableau, groupe après groupe.
    public var allTableRows: [SheetTableRow] {
        sortedGroups.flatMap(\.sortedRows)
    }

    /// Première ligne portant ce libellé (et cette spécialisation si elle est précisée).
    public func tableRow(label: String, specialization: String? = nil) -> SheetTableRow? {
        allTableRows.first { row in
            row.label.caseInsensitiveCompare(label) == .orderedSame
                && (specialization == nil || row.specialization == specialization)
        }
    }
}
