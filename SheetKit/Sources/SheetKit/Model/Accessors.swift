import Foundation

// Accesseurs typés et listes triées. Les attributs bruts (`…Raw`, tableaux non ordonnés)
// restent des détails de stockage.

extension Sheet {
    public var sortedPages: [Page] { (pages ?? []).sorted { $0.order < $1.order } }
}

extension Page {
    public var sortedRows: [SheetRow] { (rows ?? []).sorted { $0.order < $1.order } }
}

extension SheetRow {
    public var columnCount: Int { max(1, columnWeights.count) }

    /// Colonne effective d'une section (une colonne supprimée renvoie vers la dernière).
    public func effectiveColumn(of section: SheetSection) -> Int {
        min(max(0, section.columnIndex), columnCount - 1)
    }

    /// Sections d'une colonne, de haut en bas.
    public func sections(inColumn column: Int) -> [SheetSection] {
        (sections ?? [])
            .filter { effectiveColumn(of: $0) == column }
            .sorted { $0.order < $1.order }
    }

    /// Sections dessinées sur la fiche : la Besace a son propre onglet (SPEC §5.13).
    public func displayedSections(inColumn column: Int) -> [SheetSection] {
        sections(inColumn: column).filter { $0.kind.isShownOnSheet }
    }

    /// Toutes les sections, colonne par colonne.
    public var sortedSections: [SheetSection] {
        (0..<columnCount).flatMap { sections(inColumn: $0) }
    }
}

extension SheetSection {
    public var kind: SectionKind {
        get { SectionKind(rawValue: kindRaw) ?? .fields }
        set { kindRaw = newValue.rawValue }
    }

    public var arrangement: FieldArrangement {
        get { FieldArrangement(rawValue: arrangementRaw) ?? .list }
        set { arrangementRaw = newValue.rawValue }
    }

    public var sortedFields: [SheetField] { (fields ?? []).sorted { $0.order < $1.order } }
    public var sortedColumns: [SheetTableColumn] { (columns ?? []).sorted { $0.order < $1.order } }
    public var sortedGroups: [SheetTableGroup] { (groups ?? []).sorted { $0.order < $1.order } }
}

extension SheetField {
    public var kind: FieldKind {
        get { FieldKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }

    public var labelPlacement: LabelPlacement {
        get { LabelPlacement(rawValue: labelPlacementRaw) ?? .leading }
        set { labelPlacementRaw = newValue.rawValue }
    }

    public var width: FieldWidth {
        get { FieldWidth(rawValue: widthRaw) ?? .auto }
        set { widthRaw = newValue.rawValue }
    }

    /// Largeur effective dans une grille, en sixièmes.
    public var gridSixths: Int { width.sixths(for: kind, resourceStyle: resourceStyle) }

    /// Liste effective dans la disposition de sa section (une liste supprimée renvoie vers la dernière).
    public var effectiveListIndex: Int {
        guard let section, section.arrangement.usesLists else { return 0 }
        return min(max(0, listIndex), section.arrangement.listCount(columnCount: section.columnCount) - 1)
    }

    public var resourceStyle: ResourceStyle {
        get { ResourceStyle(rawValue: resourceStyleRaw) ?? .counter }
        set { resourceStyleRaw = newValue.rawValue }
    }
}

extension SheetTableColumn {
    public var kind: ColumnKind {
        get { ColumnKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }
}

extension SheetTableGroup {
    public var sortedRows: [SheetTableRow] { (rows ?? []).sorted { $0.order < $1.order } }
}

extension SheetTableRow {
    /// Libellé avec sa spécialisation : « Monter (Navire) ».
    public var displayLabel: String {
        guard let specialization, !specialization.isEmpty else { return label }
        return "\(label) (\(specialization))"
    }

    public func cell(for column: SheetTableColumn) -> SheetTableCell? {
        (cells ?? []).first { $0.column === column }
    }

    public func cell(code: String) -> SheetTableCell? {
        (cells ?? []).first { $0.column?.code.caseInsensitiveCompare(code) == .orderedSame }
    }
}
