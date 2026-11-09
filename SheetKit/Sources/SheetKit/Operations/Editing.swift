import Foundation
import SwiftData

// Opérations de structure. Elles garantissent les invariants du modèle :
// chaque ligne de tableau possède exactement une cellule par colonne.
// Pour supprimer un objet : `context.delete(objet)` — la cascade supprime ses enfants.

/// Valeur saisie pour un champ ou une cellule. Les littéraux sont acceptés :
/// `5` → nombre, `"texte"` → texte, `"=DEX*2"` → formule, `true` → case cochée.
public enum CellInput: Sendable, Equatable,
    ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
    ExpressibleByStringLiteral, ExpressibleByBooleanLiteral {
    case number(Double)
    case text(String)
    case bool(Bool)
    case formula(String)

    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(stringLiteral value: String) {
        self = value.hasPrefix("=") ? .formula(value) : .text(value)
    }
}

extension TableCell {
    public func apply(_ input: CellInput) {
        switch input {
        case .number(let value): numberValue = value
        case .text(let value): textValue = value
        case .bool(let value): boolValue = value
        case .formula(let value): formula = value
        }
    }
}

extension SheetField {
    public func apply(_ input: CellInput) {
        switch input {
        case .number(let value): numberValue = value
        case .text(let value): textValue = value
        case .bool(let value): boolValue = value
        case .formula(let value): formula = value
        }
    }
}

extension Sheet {
    @discardableResult
    public func addPage(title: String, in context: ModelContext) -> Page {
        let page = Page(title: title, order: ((pages ?? []).map(\.order).max() ?? -1) + 1)
        context.insert(page)
        page.sheet = self
        return page
    }
}

extension Page {
    @discardableResult
    public func addRow(in context: ModelContext) -> SheetRow {
        let row = SheetRow(order: ((rows ?? []).map(\.order).max() ?? -1) + 1)
        context.insert(row)
        row.page = self
        return row
    }
}

extension SheetRow {
    @discardableResult
    public func addSection(title: String, kind: SectionKind, in context: ModelContext) -> SheetSection {
        let section = SheetSection(title: title, kind: kind, order: ((sections ?? []).map(\.order).max() ?? -1) + 1)
        context.insert(section)
        section.row = self
        return section
    }
}

extension SheetSection {
    @discardableResult
    public func addField(label: String, kind: FieldKind, code: String = "", in context: ModelContext) -> SheetField {
        let field = SheetField(label: label, kind: kind, code: code, order: ((fields ?? []).map(\.order).max() ?? -1) + 1)
        context.insert(field)
        field.section = self
        return field
    }

    /// Ajoute une colonne et crée sa cellule dans chaque ligne existante.
    @discardableResult
    public func addColumn(title: String, kind: ColumnKind, code: String, in context: ModelContext) -> TableColumn {
        let column = TableColumn(title: title, kind: kind, code: code, order: ((columns ?? []).map(\.order).max() ?? -1) + 1)
        context.insert(column)
        column.section = self
        for group in groups ?? [] {
            for row in group.rows ?? [] {
                let cell = TableCell()
                context.insert(cell)
                cell.row = row
                cell.column = column
            }
        }
        return column
    }

    @discardableResult
    public func addGroup(title: String, hasValue: Bool = false, in context: ModelContext) -> TableGroup {
        let group = TableGroup(title: title, order: ((groups ?? []).map(\.order).max() ?? -1) + 1, hasValue: hasValue)
        context.insert(group)
        group.section = self
        return group
    }

    /// Ajoute une ligne au groupe, avec une cellule pour chaque colonne de la section.
    @discardableResult
    public func addRow(
        label: String,
        to group: TableGroup,
        allowsSpecialization: Bool = false,
        isFromTemplate: Bool = true,
        in context: ModelContext
    ) -> TableRow {
        let row = TableRow(label: label, order: ((group.rows ?? []).map(\.order).max() ?? -1) + 1)
        context.insert(row)
        row.group = group
        row.allowsSpecialization = allowsSpecialization
        row.isFromTemplate = isFromTemplate
        for column in sortedColumns {
            let cell = TableCell()
            context.insert(cell)
            cell.row = row
            cell.column = column
        }
        return row
    }
}
