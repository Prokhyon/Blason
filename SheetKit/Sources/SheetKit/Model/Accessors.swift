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
    public var sortedSections: [SheetSection] { (sections ?? []).sorted { $0.order < $1.order } }
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
    public var sortedColumns: [TableColumn] { (columns ?? []).sorted { $0.order < $1.order } }
    public var sortedGroups: [TableGroup] { (groups ?? []).sorted { $0.order < $1.order } }
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

    public var resourceStyle: ResourceStyle {
        get { ResourceStyle(rawValue: resourceStyleRaw) ?? .counter }
        set { resourceStyleRaw = newValue.rawValue }
    }
}

extension TableColumn {
    public var kind: ColumnKind {
        get { ColumnKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }
}

extension TableGroup {
    public var sortedRows: [TableRow] { (rows ?? []).sorted { $0.order < $1.order } }
}

extension TableRow {
    /// Libellé avec sa spécialisation : « Monter (Navire) ».
    public var displayLabel: String {
        guard let specialization, !specialization.isEmpty else { return label }
        return "\(label) (\(specialization))"
    }

    public func cell(for column: TableColumn) -> TableCell? {
        (cells ?? []).first { $0.column === column }
    }

    public func cell(code: String) -> TableCell? {
        (cells ?? []).first { $0.column?.code.caseInsensitiveCompare(code) == .orderedSame }
    }
}
