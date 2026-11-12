import Foundation
import Observation
import SwiftData

/// Élément sélectionnable de la structure.
public enum StructureItem: Hashable {
    case page(Page)
    case row(SheetRow)
    case section(SheetSection)
    case field(SheetField)
    case column(SheetTableColumn)
    case group(SheetTableGroup)
    case tableRow(SheetTableRow)

    public enum Kind { case page, row, section, field, column, group, tableRow }

    public var kind: Kind {
        switch self {
        case .page: .page
        case .row: .row
        case .section: .section
        case .field: .field
        case .column: .column
        case .group: .group
        case .tableRow: .tableRow
        }
    }

    public var model: any PersistentModel {
        switch self {
        case .page(let model): model
        case .row(let model): model
        case .section(let model): model
        case .field(let model): model
        case .column(let model): model
        case .group(let model): model
        case .tableRow(let model): model
        }
    }

    /// Conteneur direct (le champ → sa section → sa rangée → sa page).
    public var parent: StructureItem? {
        switch self {
        case .page: nil
        case .row(let row): row.page.map(StructureItem.page)
        case .section(let section): section.row.map(StructureItem.row)
        case .field(let field): field.section.map(StructureItem.section)
        case .column(let column): column.section.map(StructureItem.section)
        case .group(let group): group.section.map(StructureItem.section)
        case .tableRow(let row): row.group.map(StructureItem.group)
        }
    }

    /// L'élément puis ses conteneurs successifs.
    public var ancestors: [StructureItem] {
        var result = [self]
        while let parent = result.last?.parent { result.append(parent) }
        return result
    }

    /// Toujours présent dans une fiche (ni supprimé, ni détaché par une annulation).
    public var isAlive: Bool {
        guard !model.isDeleted, model.modelContext != nil else { return false }
        if case .page(let page) = self { return page.sheet != nil }
        return parent?.isAlive ?? false
    }
}

/// Presse-papiers de l'éditeur, partagé par toutes les fiches (copier d'un template, coller dans un autre).
@Observable @MainActor
public final class StructureClipboard {
    public static let shared = StructureClipboard()
    public var items: [StructureItem] = []
}

/// Demande d'import d'une liste collée.
public struct PasteListRequest: Identifiable {
    public enum Target {
        case fields(SheetSection, after: SheetField?)
        case rows(SheetSection, group: SheetTableGroup?)
    }
    public let id = UUID()
    public let target: Target

    public init(target: Target) {
        self.target = target
    }
}

/// État de l'éditeur d'une fiche ouverte : page affichée, sélection, actions de structure.
@Observable @MainActor
public final class StructureEditor {
    public let sheet: Sheet?
    public var pageIndex = 0
    public var selection: [StructureItem] = []
    public var pasteList: PasteListRequest?
    /// Élément dont l'inspecteur doit placer le curseur dans le libellé (après une création).
    public var focusLabel: StructureItem?
    /// Message bref (ex. « Rien à coller ici »).
    public var notice: String?
    /// Un champ de texte de l'inspecteur a le focus : les raccourcis ⌘C/⌘V lui reviennent.
    public var isEditingText = false
    @ObservationIgnored private var dragged: StructureItem?

    public init(sheet: Sheet?) {
        self.sheet = sheet
    }

    private var context: ModelContext? { sheet?.modelContext }
    public var clipboard: StructureClipboard { .shared }

    public var pages: [Page] { sheet?.sortedPages ?? [] }

    public var currentPage: Page? {
        let pages = pages
        guard !pages.isEmpty else { return nil }
        return pages[min(max(pageIndex, 0), pages.count - 1)]
    }

    // MARK: Sélection

    public var liveSelection: [StructureItem] { selection.filter(\.isAlive) }
    public var primary: StructureItem? { liveSelection.last }

    public func isSelected(_ item: StructureItem) -> Bool { selection.contains(item) }

    public func select(_ item: StructureItem, extending: Bool = false) {
        if extending {
            if let index = selection.firstIndex(of: item) {
                selection.remove(at: index)
            } else {
                selection.append(item)
            }
        } else {
            selection = [item]
        }
    }

    public func clearSelection() {
        selection = []
    }

    private func show(_ message: String) {
        notice = message
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            if self?.notice == message { self?.notice = nil }
        }
    }

    // MARK: Presse-papiers

    /// Éléments sélectionnés du même type que l'élément principal.
    private var homogeneousSelection: [StructureItem] {
        guard let primary else { return [] }
        return liveSelection.filter { $0.kind == primary.kind }
    }

    public var canCopy: Bool { primary != nil }
    public var canPaste: Bool { clipboard.items.contains(where: \.isAlive) }

    public func copy() {
        let items = homogeneousSelection
        guard !items.isEmpty else { return }
        clipboard.items = items
        show(items.count == 1 ? "Élément copié" : "\(items.count) éléments copiés")
    }

    public func duplicate() {
        guard let context else { return }
        var created: [StructureItem] = []
        for item in homogeneousSelection {
            switch item {
            case .page(let page): page.duplicate(in: context).map { created.append(.page($0)) }
            case .row(let row): row.duplicate(in: context).map { created.append(.row($0)) }
            case .section(let section): section.duplicate(in: context).map { created.append(.section($0)) }
            case .field(let field): field.duplicate(in: context).map { created.append(.field($0)) }
            case .column(let column): column.duplicate(in: context).map { created.append(.column($0)) }
            case .group(let group): group.duplicate(in: context).map { created.append(.group($0)) }
            case .tableRow(let row): row.duplicate(in: context).map { created.append(.tableRow($0)) }
            }
        }
        if !created.isEmpty { selection = created }
    }

    public func delete() {
        guard let context else { return }
        for item in liveSelection {
            context.delete(item.model)
        }
        selection = []
    }

    /// Colle le presse-papiers à l'endroit le plus proche de la sélection (après l'élément sélectionné,
    /// ou à la fin du conteneur sélectionné).
    public func paste() {
        guard let context else { return }
        let items = clipboard.items.filter(\.isAlive)
        guard let first = items.first else { return }
        let anchors = primary?.ancestors ?? currentPage.map { [.page($0)] } ?? []
        var created: [StructureItem] = []

        switch first.kind {
        case .field:
            var destination: (SheetSection, Int?)?
            for anchor in anchors {
                if case .field(let field) = anchor, let section = field.section, section.kind == .fields {
                    destination = (section, index(of: field, in: section.sortedFields).map { $0 + 1 }); break
                }
                if case .section(let section) = anchor, section.kind == .fields {
                    destination = (section, nil); break
                }
            }
            guard let destination else { return show("Sélectionnez une section de champs") }
            var (section, index) = destination
            for case .field(let field) in items {
                created.append(.field(field.paste(into: section, at: index, in: context)))
                index = index.map { $0 + 1 }
            }

        case .section:
            var destination: (SheetRow, Int, Int?)?
            for anchor in anchors {
                if case .section(let section) = anchor, let row = section.row {
                    let column = row.effectiveColumn(of: section)
                    destination = (row, column, index(of: section, in: row.sections(inColumn: column)).map { $0 + 1 }); break
                }
                if case .row(let row) = anchor {
                    destination = (row, 0, nil); break
                }
                if case .page(let page) = anchor {
                    destination = (page.sortedRows.last ?? page.addRow(in: context), 0, nil); break
                }
            }
            guard let destination else { return show("Sélectionnez une rangée") }
            var (row, column, index) = destination
            for case .section(let section) in items {
                created.append(.section(section.paste(into: row, column: column, at: index, in: context)))
                index = index.map { $0 + 1 }
            }

        case .row:
            var destination: (Page, Int?)?
            for anchor in anchors {
                if case .row(let row) = anchor, let page = row.page {
                    destination = (page, index(of: row, in: page.sortedRows).map { $0 + 1 }); break
                }
                if case .page(let page) = anchor {
                    destination = (page, nil); break
                }
            }
            guard let destination else { return show("Sélectionnez une page") }
            var (page, index) = destination
            for case .row(let row) in items {
                created.append(.row(row.paste(into: page, at: index, in: context)))
                index = index.map { $0 + 1 }
            }

        case .page:
            guard let sheet else { return }
            var index = currentPage.flatMap { index(of: $0, in: pages) }.map { $0 + 1 }
            for case .page(let page) in items {
                created.append(.page(page.paste(into: sheet, at: index, in: context)))
                index = index.map { $0 + 1 }
            }
            if let index { pageIndex = index - 1 }

        case .column:
            var destination: (SheetSection, SheetTableColumn?)?
            for anchor in anchors {
                if case .column(let column) = anchor, let section = column.section {
                    destination = (section, column); break
                }
                if case .section(let section) = anchor, section.kind == .table {
                    destination = (section, section.sortedColumns.last); break
                }
            }
            guard let destination else { return show("Sélectionnez un tableau") }
            var (section, after) = destination
            for case .column(let column) in items {
                let copy = column.paste(into: section, after: after, in: context)
                created.append(.column(copy))
                after = copy
            }

        case .group:
            var destination: (SheetSection, SheetTableGroup?)?
            for anchor in anchors {
                if case .group(let group) = anchor, let section = group.section {
                    destination = (section, group); break
                }
                if case .section(let section) = anchor, section.kind == .table {
                    destination = (section, section.sortedGroups.last); break
                }
            }
            guard let destination else { return show("Sélectionnez un tableau") }
            var (section, after) = destination
            for case .group(let group) in items {
                let copy = group.paste(into: section, after: after, in: context)
                created.append(.group(copy))
                after = copy
            }

        case .tableRow:
            var destination: (SheetTableGroup, Int?)?
            for anchor in anchors {
                if case .tableRow(let row) = anchor, let group = row.group {
                    destination = (group, index(of: row, in: group.sortedRows).map { $0 + 1 }); break
                }
                if case .group(let group) = anchor {
                    destination = (group, nil); break
                }
                if case .section(let section) = anchor, section.kind == .table {
                    destination = (section.sortedGroups.last ?? section.firstOrNewGroup(in: context), nil); break
                }
            }
            guard let destination else { return show("Sélectionnez un tableau") }
            var (group, index) = destination
            for case .tableRow(let row) in items {
                created.append(.tableRow(row.paste(into: group, at: index, in: context)))
                index = index.map { $0 + 1 }
            }
        }
        if !created.isEmpty { selection = created }
    }

    private func index<T: AnyObject>(of element: T, in list: [T]) -> Int? {
        list.firstIndex { $0 === element }
    }

    // MARK: Ajouts

    public func addPage() {
        guard let sheet, let context else { return }
        let page = sheet.addPage(title: "", in: context)
        page.addRow(in: context)
        if let current = currentPage, let index = index(of: current, in: pages) {
            sheet.move(page, to: index + 1)
        }
        pageIndex = index(of: page, in: pages) ?? pageIndex
        created(.page(page))
    }

    public func addRow(columns: Int, to page: Page) {
        guard let context else { return }
        var after: SheetRow?
        for case .row(let row) in primary?.ancestors ?? [] where row.page === page { after = row }
        let row = page.insertRow(columnWeights: Array(repeating: 1, count: columns), after: after, in: context)
        select(.row(row))
    }

    public func addSection(_ kind: SectionKind, to row: SheetRow, column: Int) {
        guard let context else { return }
        let section = kind == .inventory
            ? row.addInventorySection(title: "Besace", column: column, in: context)
            : row.addSection(title: "", kind: kind, column: column, in: context)
        if kind == .table {
            section.labelColumnTitle = "Nom"
            section.addColumn(title: "Valeur", kind: .number, code: "valeur", in: context)
            section.addGroup(title: "", in: context)
        }
        created(.section(section))
    }

    public func addField(_ kind: FieldKind, to section: SheetSection, after previous: SheetField? = nil) {
        guard let context else { return }
        var anchor = previous
        if anchor == nil, case .field(let selected) = primary, selected.section === section {
            anchor = selected
        }
        let field = section.insertField(label: "", kind: kind, after: anchor, in: context)
        created(.field(field))
    }

    public func addColumn(_ kind: ColumnKind, to section: SheetSection, after previous: SheetTableColumn? = nil) {
        guard let context else { return }
        var anchor = previous
        if anchor == nil, case .column(let selected) = primary, selected.section === section {
            anchor = selected
        }
        let column = section.insertColumn(title: "", kind: kind, code: "", after: anchor, in: context)
        created(.column(column))
    }

    public func addGroup(to section: SheetSection, after previous: SheetTableGroup? = nil) {
        guard let context else { return }
        let group = section.insertGroup(title: "", after: previous ?? section.sortedGroups.last, in: context)
        created(.group(group))
    }

    public func addTableRow(to group: SheetTableGroup, after previous: SheetTableRow? = nil) {
        guard let context, let section = group.section else { return }
        var anchor = previous
        if anchor == nil, case .tableRow(let selected) = primary, selected.group === group {
            anchor = selected
        }
        let row = section.addRow(label: "", to: group, in: context)
        if let anchor, let index = index(of: anchor, in: group.sortedRows) {
            row.move(to: group, at: index + 1, in: context)
        }
        created(.tableRow(row))
    }

    /// Entrée dans le libellé : crée l'élément suivant du même type, juste après.
    public func addNext(after item: StructureItem) {
        switch item {
        case .field(let field):
            if let section = field.section { addField(field.kind, to: section, after: field) }
        case .column(let column):
            if let section = column.section { addColumn(column.kind, to: section, after: column) }
        case .group(let group):
            if let section = group.section { addGroup(to: section, after: group) }
        case .tableRow(let row):
            if let group = row.group { addTableRow(to: group, after: row) }
        case .page, .row, .section:
            break
        }
    }

    private func created(_ item: StructureItem) {
        select(item)
        focusLabel = item
    }

    // MARK: Coller une liste

    public func requestPasteList(into section: SheetSection, group: SheetTableGroup? = nil) {
        switch section.kind {
        case .fields:
            var after: SheetField?
            if case .field(let field) = primary, field.section === section { after = field }
            pasteList = PasteListRequest(target: .fields(section, after: after))
        case .table:
            var target = group
            if target == nil, case .group(let selected) = primary, selected.section === section { target = selected }
            if target == nil, case .tableRow(let row) = primary, row.group?.section === section { target = row.group }
            pasteList = PasteListRequest(target: .rows(section, group: target))
        case .inventory, .inventoryView:
            // Coller une liste d'objets : avec l'interface de la Besace.
            break
        }
    }

    public func importList(_ text: String, request: PasteListRequest, kind: FieldKind) {
        guard let context else { return }
        let entries = ListImport.parse(text)
        switch request.target {
        case .fields(let section, let after):
            selection = section.importFields(entries, kind: kind, after: after, in: context).map(StructureItem.field)
        case .rows(let section, let group):
            selection = section.importRows(entries, into: group, in: context).map(StructureItem.tableRow)
        }
    }

    // MARK: Déplacements

    /// Frères ordonnés d'un élément (ceux parmi lesquels il peut monter ou descendre).
    private func siblings(of item: StructureItem) -> [StructureItem] {
        switch item {
        case .page: pages.map(StructureItem.page)
        case .row(let row): row.page?.sortedRows.map(StructureItem.row) ?? []
        case .section(let section):
            section.row.map { row in row.sections(inColumn: row.effectiveColumn(of: section)).map(StructureItem.section) } ?? []
        case .field(let field): field.section?.sortedFields.map(StructureItem.field) ?? []
        case .column(let column): column.section?.sortedColumns.map(StructureItem.column) ?? []
        case .group(let group): group.section?.sortedGroups.map(StructureItem.group) ?? []
        case .tableRow(let row): row.group?.sortedRows.map(StructureItem.tableRow) ?? []
        }
    }

    public func canMove(_ item: StructureItem, by delta: Int) -> Bool {
        let list = siblings(of: item)
        guard let index = list.firstIndex(of: item) else { return false }
        return list.indices.contains(index + delta)
    }

    public func move(_ item: StructureItem, by delta: Int) {
        let list = siblings(of: item)
        guard let index = list.firstIndex(of: item), list.indices.contains(index + delta) else { return }
        move(item, to: index + delta)
    }

    /// Place l'élément à la position `index` parmi ses frères.
    private func move(_ item: StructureItem, to index: Int) {
        guard let context else { return }
        switch item {
        case .page(let page):
            sheet?.move(page, to: index)
            pageIndex = index
        case .row(let row): row.page?.move(row, to: index)
        case .section(let section):
            if let row = section.row { section.move(to: row, column: row.effectiveColumn(of: section), at: index) }
        case .field(let field):
            if let section = field.section { field.move(to: section, at: index) }
        case .column(let column): column.section?.move(column, to: index)
        case .group(let group): group.section?.move(group, to: index)
        case .tableRow(let row):
            if let group = row.group { row.move(to: group, at: index, in: context) }
        }
    }

    // MARK: Glisser-déposer

    /// Début d'un glisser : mémorise l'élément et renvoie le jeton transporté.
    public func beginDrag(_ item: StructureItem) -> String {
        dragged = item
        return Self.dragToken
    }

    public static let dragToken = "blason.structure-item"

    /// Dépose l'élément glissé sur `target` : il prend la place de la cible (ou de son conteneur
    /// le plus proche qui l'accepte). Renvoie faux si le dépôt n'a pas de sens.
    public func drop(onto target: StructureItem) -> Bool {
        guard let dragged, dragged.isAlive, dragged != target else { return false }
        defer { self.dragged = nil }
        guard let context else { return false }

        for anchor in target.ancestors {
            // Lâché dans son propre contenu (une section sur l'un de ses champs) : rien à faire.
            if anchor == dragged { return false }
            switch (dragged, anchor) {
            case (.field(let field), .field(let other)):
                guard let section = other.section, field !== other else { return false }
                let index = index(of: other, in: section.sortedFields)
                field.listIndex = other.listIndex
                field.move(to: section, at: index)
            case (.field(let field), .section(let section)) where section.kind == .fields:
                field.move(to: section)
            case (.section(let section), .section(let other)):
                guard let row = other.row, section !== other else { return false }
                let column = row.effectiveColumn(of: other)
                section.move(to: row, column: column, at: index(of: other, in: row.sections(inColumn: column)))
            case (.section(let section), .row(let row)):
                section.move(to: row, column: 0)
            case (.row(let row), .row(let other)) where row.page === other.page:
                guard let page = row.page, let index = index(of: other, in: page.sortedRows) else { return false }
                page.move(row, to: index)
            case (.column(let column), .column(let other)) where column.section === other.section:
                guard let section = other.section, let index = index(of: other, in: section.sortedColumns) else { return false }
                section.move(column, to: index)
            case (.group(let group), .group(let other)) where group.section === other.section:
                guard let section = other.section, let index = index(of: other, in: section.sortedGroups) else { return false }
                section.move(group, to: index)
            case (.tableRow(let row), .tableRow(let other)):
                guard let group = other.group else { return false }
                row.move(to: group, at: index(of: other, in: group.sortedRows), in: context)
            case (.tableRow(let row), .group(let group)):
                row.move(to: group, in: context)
            case (.tableRow(let row), .section(let section)) where section.kind == .table:
                row.move(to: section.sortedGroups.last ?? section.firstOrNewGroup(in: context), in: context)
            default:
                continue
            }
            select(dragged)
            return true
        }
        return false
    }

    /// Dépose une section au bas d'une colonne de rangée.
    public func dropSection(into row: SheetRow, column: Int) -> Bool {
        guard case .section(let section) = dragged, StructureItem.section(section).isAlive else { return false }
        dragged = nil
        section.move(to: row, column: column)
        select(.section(section))
        return true
    }
}
