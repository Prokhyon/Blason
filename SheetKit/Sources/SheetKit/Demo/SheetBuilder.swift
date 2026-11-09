import Foundation
import SwiftData

// Petit DSL pour décrire une fiche en code (données de démo, tests).
//
//     SheetBuilder(sheet: sheet, context: context).page("Personnage") { page in
//         page.row { row in
//             row.fields("Caractéristiques") { s in
//                 s.field("FOR", .integer, code: "FOR")
//             }
//         }
//     }

public final class SheetBuilder {
    public let sheet: Sheet
    let context: ModelContext

    public init(sheet: Sheet, context: ModelContext) {
        self.sheet = sheet
        self.context = context
    }

    @discardableResult
    public func page(_ title: String, _ build: (PageBuilder) -> Void) -> Page {
        let page = sheet.addPage(title: title, in: context)
        build(PageBuilder(page: page, context: context))
        return page
    }
}

public final class PageBuilder {
    public let page: Page
    let context: ModelContext

    init(page: Page, context: ModelContext) {
        self.page = page
        self.context = context
    }

    /// Rangée de `columns.count` colonnes de largeurs relatives `columns`.
    @discardableResult
    public func row(columns: [Double] = [1], _ build: (RowBuilder) -> Void) -> SheetRow {
        let row = page.addRow(columnWeights: columns, in: context)
        build(RowBuilder(row: row, context: context))
        return row
    }
}

public final class RowBuilder {
    public let row: SheetRow
    let context: ModelContext

    init(row: SheetRow, context: ModelContext) {
        self.row = row
        self.context = context
    }

    @discardableResult
    public func fields(
        _ title: String,
        column: Int = 0,
        arrangement: FieldArrangement = .list,
        columns: Int = 1,
        _ build: (FieldsBuilder) -> Void
    ) -> SheetSection {
        let section = row.addSection(title: title, kind: .fields, column: column, in: context)
        section.arrangement = arrangement
        section.columnCount = columns
        build(FieldsBuilder(section: section, context: context))
        return section
    }

    @discardableResult
    public func table(
        _ title: String,
        labelTitle: String,
        column: Int = 0,
        displayColumns: Int = 1,
        _ build: (TableBuilder) -> Void
    ) -> SheetSection {
        let section = row.addSection(title: title, kind: .table, column: column, in: context)
        section.columnCount = displayColumns
        section.labelColumnTitle = labelTitle
        build(TableBuilder(section: section, context: context))
        return section
    }
}

public final class FieldsBuilder {
    public let section: SheetSection
    let context: ModelContext

    init(section: SheetSection, context: ModelContext) {
        self.section = section
        self.context = context
    }

    @discardableResult
    public func field(
        _ label: String,
        _ kind: FieldKind = .text,
        code: String = "",
        value: CellInput? = nil,
        formula: String? = nil,
        unit: String? = nil,
        min: Double? = nil,
        max: Double? = nil,
        live: Bool = false,
        placement: LabelPlacement = .leading,
        list: Int = 0,
        options: [String] = [],
        style: ResourceStyle = .counter,
        isName: Bool = false
    ) -> SheetField {
        let field = section.addField(label: label, kind: kind, code: code, in: context)
        if let value { field.apply(value) }
        field.formula = formula ?? field.formula
        field.unit = unit
        field.minimum = min
        field.maximum = max
        field.isLive = live
        field.labelPlacement = placement
        field.listIndex = list
        field.options = options
        field.resourceStyle = style
        field.isNameField = isName
        return field
    }
}

public final class TableBuilder {
    public let section: SheetSection
    let context: ModelContext

    init(section: SheetSection, context: ModelContext) {
        self.section = section
        self.context = context
    }

    @discardableResult
    public func column(
        _ title: String,
        _ kind: ColumnKind,
        code: String,
        formula: String? = nil,
        live: Bool = false
    ) -> SheetTableColumn {
        let column = section.addColumn(title: title, kind: kind, code: code, in: context)
        column.formula = formula
        column.isLive = live
        return column
    }

    @discardableResult
    public func group(_ title: String = "", hasValue: Bool = false, _ build: (GroupBuilder) -> Void = { _ in }) -> SheetTableGroup {
        let group = section.addGroup(title: title, hasValue: hasValue, in: context)
        build(GroupBuilder(section: section, group: group, context: context))
        return group
    }
}

public final class GroupBuilder {
    public let section: SheetSection
    public let group: SheetTableGroup
    let context: ModelContext

    init(section: SheetSection, group: SheetTableGroup, context: ModelContext) {
        self.section = section
        self.group = group
        self.context = context
    }

    /// Ajoute une ligne ; `cells` associe un code de colonne à une valeur.
    @discardableResult
    public func row(
        _ label: String,
        specialization: Bool = false,
        _ cells: [String: CellInput] = [:]
    ) -> SheetTableRow {
        let row = section.addRow(label: label, to: group, allowsSpecialization: specialization, in: context)
        for (code, input) in cells {
            precondition(row.cell(code: code) != nil, "Colonne inconnue « \(code) » dans « \(section.title) »")
            row.cell(code: code)?.apply(input)
        }
        return row
    }
}
