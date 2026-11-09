import Foundation
import SwiftData

// Opérations de l'éditeur de structure (SPEC §4.1) : déplacer, insérer, dupliquer, coller.
// Les positions (`order`) sont renumérotées 0…n à chaque déplacement ; les trous laissés par
// une suppression sont sans conséquence (on trie toujours par `order`).

/// Élément ordonné parmi ses frères.
public protocol OrderedElement: AnyObject {
    var order: Int { get set }
}

extension Page: OrderedElement {}
extension SheetRow: OrderedElement {}
extension SheetSection: OrderedElement {}
extension SheetField: OrderedElement {}
extension SheetTableColumn: OrderedElement {}
extension SheetTableGroup: OrderedElement {}
extension SheetTableRow: OrderedElement {}

/// Place `item` à la position `index` parmi `siblings` (triés, avec ou sans `item`) et renumérote.
/// `index` nil ou hors limites : à la fin.
func place<T: OrderedElement>(_ item: T, among siblings: [T], at index: Int?) {
    var list = siblings.filter { $0 !== item }
    let position = min(max(0, index ?? list.count), list.count)
    list.insert(item, at: position)
    for (order, element) in list.enumerated() {
        element.order = order
    }
}

/// Position juste après `element` dans `siblings`, ou la fin.
func position<T: OrderedElement>(after element: T?, in siblings: [T]) -> Int? {
    guard let element, let index = siblings.firstIndex(where: { $0 === element }) else { return nil }
    return index + 1
}

// MARK: - Codes uniques

extension Sheet {
    /// Code libre dans la fiche : `FOR` → `FOR2` (puis `FOR3`…) s'il est déjà utilisé par un autre champ.
    public func uniqueFieldCode(_ code: String, excluding field: SheetField? = nil) -> String {
        let used = Set(allFields.filter { $0 !== field }.map { $0.code.uppercased() })
        return Self.uniqueCode(code, used: used)
    }

    static func uniqueCode(_ code: String, used: Set<String>) -> String {
        guard !code.isEmpty, used.contains(code.uppercased()) else { return code }
        var base = code
        while let last = base.last, last.isNumber { base.removeLast() }
        if base.isEmpty { base = code }
        var number = 2
        while used.contains("\(base)\(number)".uppercased()) { number += 1 }
        return "\(base)\(number)"
    }
}

extension SheetSection {
    var sheet: Sheet? { row?.page?.sheet }

    /// Code de colonne libre dans le tableau.
    func uniqueColumnCode(_ code: String, excluding column: SheetTableColumn? = nil) -> String {
        let used = Set((columns ?? []).filter { $0 !== column }.map { $0.code.uppercased() })
        return Sheet.uniqueCode(code, used: used)
    }
}

// MARK: - Pages et rangées

extension Sheet {
    public func move(_ page: Page, to index: Int) {
        place(page, among: sortedPages, at: index)
    }
}

extension Page {
    public func move(_ row: SheetRow, to index: Int) {
        place(row, among: sortedRows, at: index)
    }

    /// Ajoute une rangée juste après `row` (ou à la fin).
    @discardableResult
    public func insertRow(columnWeights: [Double] = [1], after row: SheetRow?, in context: ModelContext) -> SheetRow {
        let new = addRow(columnWeights: columnWeights, in: context)
        place(new, among: sortedRows, at: position(after: row, in: sortedRows.filter { $0 !== new }))
        return new
    }

    /// Copie la page (avec ses valeurs) dans `sheet` à la position `index`, codes de champs rendus uniques.
    @discardableResult
    public func paste(into sheet: Sheet, at index: Int? = nil, in context: ModelContext) -> Page {
        let copy = copy(into: sheet, in: context)
        for field in copy.allFields {
            field.code = sheet.uniqueFieldCode(field.code, excluding: field)
            if field.isNameField, sheet.allFields.contains(where: { $0.isNameField && $0 !== field }) {
                field.isNameField = false
            }
        }
        place(copy, among: sheet.sortedPages.filter { $0 !== copy }, at: index)
        return copy
    }

    /// Duplique la page (avec ses valeurs) juste après elle-même.
    @discardableResult
    public func duplicate(in context: ModelContext) -> Page? {
        guard let sheet else { return nil }
        let copy = paste(into: sheet, at: position(after: self, in: sheet.sortedPages), in: context)
        copy.title = "\(title) (copie)"
        return copy
    }

    var allFields: [SheetField] {
        sortedRows.flatMap(\.sortedSections).flatMap(\.sortedFields)
    }
}

extension SheetRow {
    /// Change le nombre de colonnes. Les sections des colonnes supprimées passent à la fin
    /// de la dernière colonne conservée.
    public func setColumnCount(_ count: Int) {
        let count = max(1, count)
        guard count != columnWeights.count else { return }
        if count > columnWeights.count {
            columnWeights += Array(repeating: 1, count: count - columnWeights.count)
        } else {
            let target = count - 1
            var kept = sections(inColumn: target)
            for column in count..<columnCount {
                kept += sections(inColumn: column)
            }
            for (order, section) in kept.enumerated() {
                section.columnIndex = target
                section.order = order
            }
            columnWeights = Array(columnWeights.prefix(count))
        }
    }

    /// Supprime une colonne ; ses sections rejoignent la colonne voisine (à gauche si possible).
    public func removeColumn(at index: Int) {
        guard columnCount > 1, columnWeights.indices.contains(index) else { return }
        let neighbour = index > 0 ? index - 1 : 1
        let merged = index > 0
            ? sections(inColumn: neighbour) + sections(inColumn: index)
            : sections(inColumn: index) + sections(inColumn: neighbour)
        let following = (sections ?? []).filter { effectiveColumn(of: $0) > max(index, neighbour) }
        for (order, section) in merged.enumerated() {
            section.columnIndex = min(index, neighbour)
            section.order = order
        }
        for section in following {
            section.columnIndex -= 1
        }
        columnWeights.remove(at: index)
    }

    /// Copie la rangée (sections et valeurs) dans `page` à la position `index`.
    @discardableResult
    public func paste(into page: Page, at index: Int? = nil, in context: ModelContext) -> SheetRow {
        let copy = SheetRow(order: 0)
        context.insert(copy)
        copy.page = page
        copy.columnWeights = columnWeights
        for section in sortedSections {
            section.paste(into: copy, column: section.columnIndex, in: context)
        }
        place(copy, among: page.sortedRows.filter { $0 !== copy }, at: index)
        return copy
    }

    /// Duplique la rangée (sections et valeurs) juste en dessous.
    @discardableResult
    public func duplicate(in context: ModelContext) -> SheetRow? {
        guard let page else { return nil }
        return paste(into: page, at: position(after: self, in: page.sortedRows), in: context)
    }
}

// MARK: - Sections

extension SheetSection {
    /// Déplace la section dans `row`, colonne `column`, à la position `index` (nil : à la fin).
    public func move(to row: SheetRow, column: Int, at index: Int? = nil) {
        let column = min(max(0, column), row.columnCount - 1)
        let oldRow = self.row
        let oldColumn = oldRow?.effectiveColumn(of: self)
        self.row = row
        columnIndex = column
        place(self, among: row.sections(inColumn: column), at: index)
        if let oldRow, let oldColumn, oldRow !== row || oldColumn != column {
            for (order, section) in oldRow.sections(inColumn: oldColumn).filter({ $0 !== self }).enumerated() {
                section.order = order
            }
        }
    }

    /// Copie la section dans `row` (colonne `column`) à la position `index`, avec des codes de champs
    /// uniques dans la fiche de destination.
    @discardableResult
    public func paste(into row: SheetRow, column: Int, at index: Int? = nil, in context: ModelContext) -> SheetSection {
        let copy = copy(into: row, in: context)
        if let sheet = row.page?.sheet {
            for field in copy.fields ?? [] {
                field.code = sheet.uniqueFieldCode(field.code, excluding: field)
                if field.isNameField, sheet.allFields.contains(where: { $0.isNameField && $0 !== field }) {
                    field.isNameField = false
                }
            }
        }
        let column = min(max(0, column), row.columnCount - 1)
        copy.columnIndex = column
        place(copy, among: row.sections(inColumn: column), at: index)
        return copy
    }

    /// Duplique la section juste en dessous d'elle-même.
    @discardableResult
    public func duplicate(in context: ModelContext) -> SheetSection? {
        guard let row else { return nil }
        let column = row.effectiveColumn(of: self)
        let siblings = row.sections(inColumn: column)
        let copy = paste(into: row, column: column, at: position(after: self, in: siblings), in: context)
        copy.title = title.isEmpty ? "" : "\(title) (copie)"
        return copy
    }

    // MARK: Champs

    /// Ajoute un champ juste après `previous` (même liste), ou à la fin.
    @discardableResult
    public func insertField(label: String, kind: FieldKind, after previous: SheetField?, in context: ModelContext) -> SheetField {
        let field = addField(label: label, kind: kind, in: context)
        if let previous, previous.section === self {
            field.listIndex = previous.listIndex
            field.labelPlacement = previous.labelPlacement
        }
        if kind == .resource {
            field.isLive = true
        }
        place(field, among: sortedFields.filter { $0 !== field }, at: position(after: previous, in: sortedFields))
        return field
    }

    // MARK: Tableaux

    public func move(_ column: SheetTableColumn, to index: Int) {
        place(column, among: sortedColumns, at: index)
    }

    public func move(_ group: SheetTableGroup, to index: Int) {
        place(group, among: sortedGroups, at: index)
    }

    /// Ajoute une colonne juste après `previous` (ou à la fin), avec un code unique dans le tableau.
    @discardableResult
    public func insertColumn(title: String, kind: ColumnKind, code: String, after previous: SheetTableColumn?, in context: ModelContext) -> SheetTableColumn {
        let column = addColumn(title: title, kind: kind, code: uniqueColumnCode(code), in: context)
        place(column, among: sortedColumns.filter { $0 !== column }, at: position(after: previous, in: sortedColumns))
        return column
    }

    /// Ajoute un groupe juste après `previous` (ou à la fin).
    @discardableResult
    public func insertGroup(title: String, after previous: SheetTableGroup?, in context: ModelContext) -> SheetTableGroup {
        let group = addGroup(title: title, in: context)
        place(group, among: sortedGroups.filter { $0 !== group }, at: position(after: previous, in: sortedGroups))
        return group
    }

    /// Premier groupe du tableau, créé (sans titre) s'il n'y en a aucun.
    public func firstOrNewGroup(in context: ModelContext) -> SheetTableGroup {
        sortedGroups.first ?? addGroup(title: "", in: context)
    }
}

// MARK: - Champs

extension SheetField {
    /// Déplace le champ dans `section` à la position `index` (nil : à la fin).
    public func move(to section: SheetSection, at index: Int? = nil) {
        let oldSection = self.section
        self.section = section
        if section.arrangement == .columns {
            listIndex = min(listIndex, max(0, section.columnCount - 1))
        }
        place(self, among: section.sortedFields, at: index)
        if let oldSection, oldSection !== section {
            for (order, field) in oldSection.sortedFields.filter({ $0 !== self }).enumerated() {
                field.order = order
            }
        }
    }

    /// Copie le champ dans `section` à la position `index`, avec un code unique dans la fiche.
    @discardableResult
    public func paste(into section: SheetSection, at index: Int? = nil, in context: ModelContext) -> SheetField {
        let canBeName = section.sheet?.nameField == nil
        let copy = copy(into: section, in: context)
        copy.isNameField = isNameField && canBeName
        if let sheet = section.sheet {
            copy.code = sheet.uniqueFieldCode(code, excluding: copy)
        }
        place(copy, among: section.sortedFields.filter { $0 !== copy }, at: index)
        return copy
    }

    /// Duplique le champ juste après lui-même.
    @discardableResult
    public func duplicate(in context: ModelContext) -> SheetField? {
        guard let section else { return nil }
        return paste(into: section, at: position(after: self, in: section.sortedFields), in: context)
    }
}

// MARK: - Colonnes et groupes de tableau

extension SheetTableColumn {
    /// Copie la colonne (titre, type, formule, sans valeurs) dans `section`, juste après `previous`.
    @discardableResult
    public func paste(into section: SheetSection, after previous: SheetTableColumn? = nil, in context: ModelContext) -> SheetTableColumn {
        let copy = section.insertColumn(title: title, kind: kind, code: code, after: previous, in: context)
        copy.formula = formula
        copy.isLive = isLive
        return copy
    }

    /// Duplique la colonne (titre, type, formule, valeurs) juste à droite.
    @discardableResult
    public func duplicate(in context: ModelContext) -> SheetTableColumn? {
        guard let section else { return nil }
        let copy = paste(into: section, after: self, in: context)
        copy.title = "\(title) (copie)"
        for cell in cells ?? [] {
            guard let target = cell.row?.cell(for: copy) else { continue }
            target.copyValues(from: cell)
        }
        return copy
    }
}

extension SheetTableGroup {
    /// Copie le groupe et ses lignes dans `section`, juste après `previous` (ou à la fin).
    @discardableResult
    public func paste(into section: SheetSection, after previous: SheetTableGroup? = nil, in context: ModelContext) -> SheetTableGroup {
        let copy = section.insertGroup(title: title, after: previous, in: context)
        copy.hasValue = hasValue
        copy.numberValue = numberValue
        for row in sortedRows {
            row.paste(into: copy, in: context)
        }
        return copy
    }

    /// Duplique le groupe et ses lignes juste en dessous.
    @discardableResult
    public func duplicate(in context: ModelContext) -> SheetTableGroup? {
        guard let section else { return nil }
        let copy = paste(into: section, after: self, in: context)
        copy.title = title.isEmpty ? "" : "\(title) (copie)"
        return copy
    }
}

extension SheetTableCell {
    func copyValues(from other: SheetTableCell) {
        textValue = other.textValue
        numberValue = other.numberValue
        boolValue = other.boolValue
        formula = other.formula
    }
}

// MARK: - Lignes de tableau

extension SheetTableRow {
    /// Déplace la ligne dans `group` à la position `index` (nil : à la fin). Vers un autre tableau,
    /// les valeurs suivent les colonnes de même code (ou de même titre).
    public func move(to group: SheetTableGroup, at index: Int? = nil, in context: ModelContext) {
        let oldGroup = self.group
        let oldSection = oldGroup?.section
        self.group = group
        if let section = group.section, section !== oldSection {
            remapCells(to: section, in: context)
        }
        place(self, among: group.sortedRows, at: index)
        if let oldGroup, oldGroup !== group {
            for (order, row) in oldGroup.sortedRows.filter({ $0 !== self }).enumerated() {
                row.order = order
            }
        }
    }

    /// Copie la ligne (libellé, spécialisation, valeurs) dans `group` à la position `index`.
    @discardableResult
    public func paste(into group: SheetTableGroup, at index: Int? = nil, in context: ModelContext) -> SheetTableRow {
        let copy = SheetTableRow(label: label, order: 0)
        context.insert(copy)
        copy.group = group
        copy.specialization = specialization
        copy.allowsSpecialization = allowsSpecialization
        copy.isFromTemplate = isFromTemplate
        for column in group.section?.sortedColumns ?? [] {
            let cell = SheetTableCell()
            context.insert(cell)
            cell.row = copy
            cell.column = column
            if let source = matchingCell(for: column, in: cells ?? []) {
                cell.copyValues(from: source)
            }
        }
        place(copy, among: group.sortedRows.filter { $0 !== copy }, at: index)
        return copy
    }

    /// Cellule de cette ligne qui correspond à `column` : même colonne, sinon même code, sinon même titre.
    func matchingCell(for column: SheetTableColumn, in cells: [SheetTableCell]) -> SheetTableCell? {
        if let cell = cells.first(where: { $0.column === column }) { return cell }
        if !column.code.isEmpty,
           let cell = cells.first(where: { $0.column?.code.caseInsensitiveCompare(column.code) == .orderedSame }) {
            return cell
        }
        return cells.first { $0.column?.title.caseInsensitiveCompare(column.title) == .orderedSame }
    }

    /// Recrée les cellules pour les colonnes de `section`, en reprenant les valeurs correspondantes.
    private func remapCells(to section: SheetSection, in context: ModelContext) {
        let old = cells ?? []
        let sources = section.sortedColumns.map { ($0, matchingCell(for: $0, in: old)) }
        for (column, source) in sources {
            let cell = SheetTableCell()
            context.insert(cell)
            if let source {
                cell.copyValues(from: source)
            }
            cell.column = column
            cell.row = self
        }
        for cell in old {
            cell.row = nil
            cell.column = nil
            context.delete(cell)
        }
    }
}
