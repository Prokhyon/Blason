import Foundation
import SwiftData

// Export / import JSON d'un template ou d'un personnage (SPEC §5.7).
//
// Format versionné, lisible et stable (clés triées) :
//   { "format": "blason", "version": 1, "exportedAt": "…",
//     "template": { "name": …, "sheet": { "pages": [ { "rows": [ { "sections": [ … ] } ] } ] } } }
// ou "character" à la place de "template".
// Version 2 (modèle V2, brouillon) : sections Besace (`inventory`) et vues de la Besace
// (`viewTypeCodes`, `viewPropertyCodes`). Un fichier version 1 se lit toujours.
//
// L'ordre des éléments est celui des tableaux JSON (pas de champ `order`). Les cellules d'une ligne
// suivent l'ordre des colonnes de son tableau. Les types sont écrits comme dans le modèle
// (`"integer"`, `"table"`…) ; une valeur inconnue retombe sur le type par défaut, comme le modèle.

/// Document d'échange : un template ou un personnage, avec sa fiche complète.
public struct SheetDocument: Codable, Equatable, Sendable {
    public static let formatIdentifier = "blason"
    /// Identifiants acceptés à l'import : `character-sheet` est l'ancien nom du format
    /// (fichiers exportés avant le renommage du projet), identique pour le reste.
    public static let acceptedFormatIdentifiers: Set<String> = [formatIdentifier, "character-sheet"]
    public static let currentVersion = 2

    public var format: String
    public var version: Int
    public var exportedAt: Date
    public var template: TemplateRecord?
    public var character: CharacterRecord?

    public struct TemplateRecord: Codable, Equatable, Sendable {
        public var uid: UUID
        public var name: String
        public var system: String
        public var notes: String
        public var createdAt: Date
        public var updatedAt: Date
        public var sheet: SheetRecord
    }

    public struct CharacterRecord: Codable, Equatable, Sendable {
        public var uid: UUID
        public var name: String
        public var sourceTemplateUID: UUID?
        public var sourceTemplateName: String
        public var createdAt: Date
        public var updatedAt: Date
        public var sheet: SheetRecord
    }

    public struct SheetRecord: Codable, Equatable, Sendable {
        public var pages: [PageRecord]
        /// Apparence propre à la fiche (absente : celle par défaut, ou celle du template).
        public var themeID: String?
        public var themeColor: String?
    }

    public struct PageRecord: Codable, Equatable, Sendable {
        public var title: String
        public var rows: [RowRecord]
    }

    public struct RowRecord: Codable, Equatable, Sendable {
        public var columnWeights: [Double]
        /// Colonne par colonne, de haut en bas.
        public var sections: [SectionRecord]
    }

    public struct SectionRecord: Codable, Equatable, Sendable {
        public var title: String
        public var column: Int
        public var kind: String
        public var arrangement: String
        public var columnCount: Int
        public var labelColumnTitle: String
        public var fields: [FieldRecord]
        public var columns: [ColumnRecord]
        public var groups: [GroupRecord]
        /// Section Besace (version 2).
        public var inventory: InventoryRecord?
        /// Vue de la Besace (version 2) : types montrés et propriétés en colonnes.
        public var viewTypeCodes: [String]?
        public var viewPropertyCodes: [String]?
    }

    // Besace. Les objets désignent leur type, leur monnaie et leurs propriétés par leur position
    // dans les listes de la Besace (les codes peuvent être vides).

    public struct InventoryRecord: Codable, Equatable, Sendable {
        public var code: String
        public var tracksWeight: Bool
        public var weightUnit: String
        public var weightLimitFormula: String?
        public var appliesMalus: Bool
        public var itemTypes: [ItemTypeRecord]
        public var currencies: [CurrencyRecord]
        public var levels: [LevelRecord]
        public var slots: [SlotRecord]
    }

    public struct ItemTypeRecord: Codable, Equatable, Sendable {
        public var name: String
        public var code: String
        public var icon: String
        public var properties: [PropertyRecord]
    }

    public struct PropertyRecord: Codable, Equatable, Sendable {
        public var label: String
        public var code: String
        public var kind: String
        public var formula: String?
        public var isLive: Bool
        public var textValue: String?
        public var numberValue: Double?
        public var boolValue: Bool?
    }

    public struct CurrencyRecord: Codable, Equatable, Sendable {
        public var name: String
        public var abbreviation: String
        public var rate: Double
    }

    public struct LevelRecord: Codable, Equatable, Sendable {
        public var name: String
        public var thresholdFormula: String?
        public var malus: Double?
        public var effect: String
    }

    public struct SlotRecord: Codable, Equatable, Sendable {
        public var name: String
        public var icon: String
        public var countsTowardEncumbrance: Bool
        public var capacity: Double?
        public var items: [ItemRecord]
    }

    public struct ItemRecord: Codable, Equatable, Sendable {
        public var name: String
        public var quantity: Double
        public var unitWeight: Double?
        public var price: String
        public var isEquipped: Bool
        public var isContainer: Bool
        public var summary: String
        public var notes: String
        /// Image encodée en base64.
        public var imageData: Data?
        /// Position du type dans `itemTypes`.
        public var type: Int?
        /// Position de la monnaie dans `currencies` (compteur d'argent).
        public var currency: Int?
        public var values: [ItemValueRecord]
        /// Contenu d'un contenant (un seul niveau).
        public var contents: [ItemRecord]?
    }

    public struct ItemValueRecord: Codable, Equatable, Sendable {
        /// Position de la propriété dans le type de l'objet.
        public var property: Int
        public var textValue: String?
        public var numberValue: Double?
        public var boolValue: Bool?
        public var formula: String?
    }

    public struct FieldRecord: Codable, Equatable, Sendable {
        public var label: String
        public var code: String
        public var kind: String
        public var labelPlacement: String
        public var listIndex: Int
        public var isLive: Bool
        public var isNameField: Bool
        public var unit: String?
        public var hint: String?
        public var minimum: Double?
        public var maximum: Double?
        public var step: Double?
        public var options: [String]
        public var resourceStyle: String
        public var formula: String?
        public var textValue: String?
        public var numberValue: Double?
        public var resourceMax: Double?
        public var boolValue: Bool?
        public var dateValue: Date?
        /// Image encodée en base64.
        public var imageData: Data?
    }

    public struct ColumnRecord: Codable, Equatable, Sendable {
        public var title: String
        public var code: String
        public var kind: String
        public var formula: String?
        public var isLive: Bool
    }

    public struct GroupRecord: Codable, Equatable, Sendable {
        public var title: String
        public var hasValue: Bool
        public var numberValue: Double?
        public var rows: [TableRowRecord]
    }

    public struct TableRowRecord: Codable, Equatable, Sendable {
        public var label: String
        public var specialization: String?
        public var allowsSpecialization: Bool
        public var isFromTemplate: Bool
        /// Une cellule par colonne du tableau, dans l'ordre des colonnes.
        public var cells: [CellRecord]
    }

    public struct CellRecord: Codable, Equatable, Sendable {
        public var textValue: String?
        public var numberValue: Double?
        public var boolValue: Bool?
        public var formula: String?
    }

    /// Nom de l'élément exporté (pour le nom de fichier).
    public var title: String {
        template?.name ?? character?.name ?? "Fiche"
    }
}

/// Erreur d'import, avec un message en français.
public enum SheetImportError: Error, Equatable, LocalizedError {
    case notASheetDocument
    case unsupportedVersion(Int)
    case empty
    case invalid(String)

    public var errorDescription: String? {
        switch self {
        case .notASheetDocument:
            "Ce fichier n'est pas une fiche exportée par l'app."
        case .unsupportedVersion(let version):
            "Ce fichier vient d'une version plus récente de l'app (format \(version)). Mettez l'app à jour pour l'importer."
        case .empty:
            "Ce fichier ne contient ni template ni personnage."
        case .invalid(let detail):
            "Fichier illisible : \(detail)"
        }
    }
}

/// Élément créé par un import.
public enum ImportedItem {
    case template(SheetTemplate)
    case character(PlayerCharacter)
}

// MARK: - Encodage

extension SheetDocument {
    public init(template: SheetTemplate, exportedAt: Date = Date()) {
        self.init(
            format: Self.formatIdentifier, version: Self.currentVersion, exportedAt: exportedAt,
            template: TemplateRecord(
                uid: template.uid, name: template.name, system: template.system, notes: template.notes,
                createdAt: template.createdAt, updatedAt: template.updatedAt,
                sheet: SheetRecord(template.sheet)
            ),
            character: nil
        )
    }

    public init(character: PlayerCharacter, exportedAt: Date = Date()) {
        self.init(
            format: Self.formatIdentifier, version: Self.currentVersion, exportedAt: exportedAt,
            template: nil,
            character: CharacterRecord(
                uid: character.uid, name: character.displayName,
                sourceTemplateUID: character.sourceTemplateUID, sourceTemplateName: character.sourceTemplateName,
                createdAt: character.createdAt, updatedAt: character.updatedAt,
                sheet: SheetRecord(character.sheet)
            )
        )
    }

    /// JSON indenté, clés triées (diff lisible), dates ISO 8601 à la milliseconde.
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.isoString(date))
        }
        return try encoder.encode(self)
    }

    /// « 2026-11-09T20:24:25.978Z » : millisecondes arrondies (et non tronquées), pour qu'une date
    /// relue puis réécrite donne exactement le même texte.
    static func isoString(_ date: Date) -> String {
        let milliseconds = Int64((date.timeIntervalSince1970 * 1000).rounded())
        let (seconds, remainder) = (milliseconds.floorDivided(by: 1000), milliseconds.floorModulo(1000))
        let base = Date.ISO8601FormatStyle().format(Date(timeIntervalSince1970: Double(seconds)))
        return base.dropLast() + String(format: ".%03lldZ", remainder)
    }

    /// Lit un document ; vérifie le format et la version.
    public static func decode(_ data: Data) throws(SheetImportError) -> SheetDocument {
        struct Header: Decodable {
            var format: String?
            var version: Int?
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
            if let date = (try? fractional.parse(text)) ?? (try? Date.ISO8601FormatStyle().parse(text)) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "date « \(text) »")
        }
        guard let header = try? decoder.decode(Header.self, from: data),
              let format = header.format, acceptedFormatIdentifiers.contains(format), let version = header.version else {
            throw .notASheetDocument
        }
        guard version <= currentVersion else { throw .unsupportedVersion(version) }
        let document: SheetDocument
        do {
            document = try decoder.decode(SheetDocument.self, from: data)
        } catch let error as DecodingError {
            throw .invalid(Self.describe(error))
        } catch {
            throw .invalid(error.localizedDescription)
        }
        guard document.template != nil || document.character != nil else { throw .empty }
        return document
    }

    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map { $0.intValue.map(String.init) ?? $0.stringValue }.joined(separator: ".")
        }
        switch error {
        case .keyNotFound(let key, let context): return "« \(key.stringValue) » manquant (\(path(context)))"
        case .typeMismatch(_, let context), .valueNotFound(_, let context): return "valeur inattendue (\(path(context)))"
        case .dataCorrupted(let context): return context.debugDescription
        @unknown default: return "contenu inattendu"
        }
    }

    /// Nom de fichier proposé : « Leo.json ».
    public var suggestedFilename: String {
        let forbidden = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = title.components(separatedBy: forbidden).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned.isEmpty ? "Fiche" : cleaned) + ".json"
    }
}

extension SheetDocument.SheetRecord {
    init(_ sheet: Sheet?) {
        pages = (sheet?.sortedPages ?? []).map { page in
            SheetDocument.PageRecord(title: page.title, rows: page.sortedRows.map { row in
                SheetDocument.RowRecord(
                    columnWeights: row.columnWeights,
                    sections: row.sortedSections.map { SheetDocument.SectionRecord($0, column: row.effectiveColumn(of: $0)) }
                )
            })
        }
        themeID = sheet?.themeID
        themeColor = sheet?.themeColor
    }
}

extension SheetDocument.SectionRecord {
    init(_ section: SheetSection, column: Int) {
        let columns = section.sortedColumns
        self.init(
            title: section.title, column: column, kind: section.kindRaw, arrangement: section.arrangementRaw,
            columnCount: section.columnCount, labelColumnTitle: section.labelColumnTitle,
            fields: section.sortedFields.map(SheetDocument.FieldRecord.init),
            columns: columns.map {
                SheetDocument.ColumnRecord(title: $0.title, code: $0.code, kind: $0.kindRaw, formula: $0.formula, isLive: $0.isLive)
            },
            groups: section.sortedGroups.map { group in
                SheetDocument.GroupRecord(
                    title: group.title, hasValue: group.hasValue, numberValue: group.numberValue,
                    rows: group.sortedRows.map { row in
                        SheetDocument.TableRowRecord(
                            label: row.label, specialization: row.specialization,
                            allowsSpecialization: row.allowsSpecialization, isFromTemplate: row.isFromTemplate,
                            cells: columns.map { column in
                                let cell = row.cell(for: column)
                                return SheetDocument.CellRecord(
                                    textValue: cell?.textValue, numberValue: cell?.numberValue,
                                    boolValue: cell?.boolValue, formula: cell?.formula
                                )
                            }
                        )
                    }
                )
            },
            inventory: section.inventory.map(SheetDocument.InventoryRecord.init),
            viewTypeCodes: section.viewTypeCodes.isEmpty ? nil : section.viewTypeCodes,
            viewPropertyCodes: section.viewPropertyCodes.isEmpty ? nil : section.viewPropertyCodes
        )
    }
}

extension SheetDocument.InventoryRecord {
    init(_ inventory: Inventory) {
        let types = inventory.sortedItemTypes
        let currencies = inventory.sortedCurrencies
        func record(_ item: InventoryItem) -> SheetDocument.ItemRecord {
            let properties = item.type?.sortedProperties ?? []
            return SheetDocument.ItemRecord(
                name: item.name, quantity: item.quantity, unitWeight: item.unitWeight, price: item.price,
                isEquipped: item.isEquipped, isContainer: item.isContainer, summary: item.summary, notes: item.notes,
                imageData: item.imageData,
                type: item.type.flatMap { type in types.firstIndex { $0 === type } },
                currency: item.currency.flatMap { currency in currencies.firstIndex { $0 === currency } },
                values: properties.enumerated().compactMap { index, property in
                    item.value(for: property).map {
                        SheetDocument.ItemValueRecord(property: index, textValue: $0.textValue, numberValue: $0.numberValue,
                                                      boolValue: $0.boolValue, formula: $0.formula)
                    }
                },
                contents: item.isContainer ? item.sortedContents.map(record) : nil
            )
        }
        self.init(
            code: inventory.code, tracksWeight: inventory.tracksWeight, weightUnit: inventory.weightUnit,
            weightLimitFormula: inventory.weightLimitFormula, appliesMalus: inventory.appliesMalus,
            itemTypes: types.map { type in
                SheetDocument.ItemTypeRecord(name: type.name, code: type.code, icon: type.icon, properties: type.sortedProperties.map {
                    SheetDocument.PropertyRecord(label: $0.label, code: $0.code, kind: $0.kindRaw, formula: $0.formula, isLive: $0.isLive,
                                                 textValue: $0.textValue, numberValue: $0.numberValue, boolValue: $0.boolValue)
                })
            },
            currencies: currencies.map { SheetDocument.CurrencyRecord(name: $0.name, abbreviation: $0.abbreviation, rate: $0.rate) },
            levels: inventory.sortedLevels.map {
                SheetDocument.LevelRecord(name: $0.name, thresholdFormula: $0.thresholdFormula, malus: $0.malus, effect: $0.effect)
            },
            slots: inventory.sortedSlots.map { slot in
                SheetDocument.SlotRecord(name: slot.name, icon: slot.icon, countsTowardEncumbrance: slot.countsTowardEncumbrance,
                                         capacity: slot.capacity, items: slot.looseItems.map(record))
            }
        )
    }

    func makeInventory(in section: SheetSection, context: ModelContext) {
        let inventory = Inventory()
        context.insert(inventory)
        inventory.section = section
        inventory.code = code
        inventory.tracksWeight = tracksWeight
        inventory.weightUnit = weightUnit
        inventory.weightLimitFormula = weightLimitFormula
        inventory.appliesMalus = appliesMalus

        var types: [ItemType] = []
        for (order, record) in itemTypes.enumerated() {
            let type = ItemType(name: record.name, code: record.code, icon: record.icon, order: order)
            context.insert(type)
            type.inventory = inventory
            for (propertyOrder, propertyRecord) in record.properties.enumerated() {
                let property = ItemProperty(label: propertyRecord.label, code: propertyRecord.code, order: propertyOrder)
                context.insert(property)
                property.type = type
                property.kindRaw = propertyRecord.kind
                property.formula = propertyRecord.formula
                property.isLive = propertyRecord.isLive
                property.textValue = propertyRecord.textValue
                property.numberValue = propertyRecord.numberValue
                property.boolValue = propertyRecord.boolValue
            }
            types.append(type)
        }
        var currencyModels: [Currency] = []
        for (order, record) in currencies.enumerated() {
            let currency = Currency(name: record.name, abbreviation: record.abbreviation, rate: record.rate, order: order)
            context.insert(currency)
            currency.inventory = inventory
            currencyModels.append(currency)
        }
        for (order, record) in levels.enumerated() {
            let level = EncumbranceLevel(name: record.name, thresholdFormula: record.thresholdFormula, order: order)
            context.insert(level)
            level.inventory = inventory
            level.malus = record.malus
            level.effect = record.effect
        }

        func makeItem(_ record: SheetDocument.ItemRecord, order: Int, slot: InventorySlot, container: InventoryItem?) {
            let item = InventoryItem(name: record.name, quantity: record.quantity, order: order)
            context.insert(item)
            item.slot = slot
            item.container = container
            item.unitWeight = record.unitWeight
            item.price = record.price
            item.isEquipped = record.isEquipped
            item.isContainer = record.isContainer
            item.summary = record.summary
            item.notes = record.notes
            item.imageData = record.imageData
            item.type = record.type.flatMap { types.indices.contains($0) ? types[$0] : nil }
            item.currency = record.currency.flatMap { currencyModels.indices.contains($0) ? currencyModels[$0] : nil }
            let properties = item.type?.sortedProperties ?? []
            for valueRecord in record.values where properties.indices.contains(valueRecord.property) {
                let value = ItemPropertyValue()
                context.insert(value)
                value.item = item
                value.property = properties[valueRecord.property]
                value.textValue = valueRecord.textValue
                value.numberValue = valueRecord.numberValue
                value.boolValue = valueRecord.boolValue
                value.formula = valueRecord.formula
            }
            // Un seul niveau de contenant : le contenu d'un contenu est ignoré.
            if container == nil, record.isContainer {
                for (contentOrder, content) in (record.contents ?? []).enumerated() {
                    makeItem(content, order: contentOrder, slot: slot, container: item)
                }
            }
        }

        for (order, record) in slots.enumerated() {
            let slot = InventorySlot(name: record.name, icon: record.icon, order: order)
            context.insert(slot)
            slot.inventory = inventory
            slot.countsTowardEncumbrance = record.countsTowardEncumbrance
            slot.capacity = record.capacity
            for (itemOrder, itemRecord) in record.items.enumerated() {
                makeItem(itemRecord, order: itemOrder, slot: slot, container: nil)
            }
        }
    }
}

extension SheetDocument.FieldRecord {
    init(_ field: SheetField) {
        self.init(
            label: field.label, code: field.code, kind: field.kindRaw, labelPlacement: field.labelPlacementRaw,
            listIndex: field.listIndex, isLive: field.isLive, isNameField: field.isNameField,
            unit: field.unit, hint: field.hint, minimum: field.minimum, maximum: field.maximum, step: field.step,
            options: field.options, resourceStyle: field.resourceStyleRaw, formula: field.formula,
            textValue: field.textValue, numberValue: field.numberValue, resourceMax: field.resourceMax,
            boolValue: field.boolValue, dateValue: field.dateValue, imageData: field.imageData
        )
    }
}

// MARK: - Import

extension SheetDocument {
    /// Crée le template ou le personnage du document dans `context`. Si un élément de même
    /// identifiant existe déjà (fichier importé deux fois), le nouveau reçoit un nouvel identifiant.
    @discardableResult
    public func insert(into context: ModelContext) throws -> ImportedItem {
        if let record = template {
            let uid = record.uid
            let existing = try context.fetchCount(FetchDescriptor<SheetTemplate>(predicate: #Predicate { $0.uid == uid }))
            let template = SheetTemplate(name: record.name, system: record.system)
            context.insert(template)
            template.uid = existing > 0 ? UUID() : uid
            template.notes = record.notes
            template.createdAt = record.createdAt
            template.updatedAt = record.updatedAt
            template.sheet = record.sheet.makeSheet(in: context)
            return .template(template)
        }
        if let record = character {
            let uid = record.uid
            let existing = try context.fetchCount(FetchDescriptor<PlayerCharacter>(predicate: #Predicate { $0.uid == uid }))
            let character = PlayerCharacter(name: record.name)
            context.insert(character)
            character.uid = existing > 0 ? UUID() : uid
            character.sourceTemplateUID = record.sourceTemplateUID
            character.sourceTemplateName = record.sourceTemplateName
            character.createdAt = record.createdAt
            character.updatedAt = record.updatedAt
            character.sheet = record.sheet.makeSheet(in: context)
            return .character(character)
        }
        throw SheetImportError.empty
    }
}

extension SheetDocument.SheetRecord {
    func makeSheet(in context: ModelContext) -> Sheet {
        let sheet = Sheet()
        context.insert(sheet)
        sheet.themeID = themeID
        sheet.themeColor = themeColor
        for (pageOrder, pageRecord) in pages.enumerated() {
            let page = Page(title: pageRecord.title, order: pageOrder)
            context.insert(page)
            page.sheet = sheet
            for (rowOrder, rowRecord) in pageRecord.rows.enumerated() {
                let row = SheetRow(order: rowOrder)
                context.insert(row)
                row.page = page
                row.columnWeights = rowRecord.columnWeights.isEmpty ? [1] : rowRecord.columnWeights
                var orderInColumn: [Int: Int] = [:]
                for sectionRecord in rowRecord.sections {
                    let column = min(max(0, sectionRecord.column), row.columnCount - 1)
                    let order = orderInColumn[column, default: 0]
                    orderInColumn[column] = order + 1
                    sectionRecord.makeSection(in: row, column: column, order: order, context: context)
                }
            }
        }
        return sheet
    }
}

extension SheetDocument.SectionRecord {
    func makeSection(in row: SheetRow, column: Int, order: Int, context: ModelContext) {
        let section = SheetSection(title: title, order: order)
        context.insert(section)
        section.row = row
        section.columnIndex = column
        section.kindRaw = kind
        section.arrangementRaw = arrangement
        section.columnCount = max(1, columnCount)
        section.labelColumnTitle = labelColumnTitle
        section.viewTypeCodes = viewTypeCodes ?? []
        section.viewPropertyCodes = viewPropertyCodes ?? []
        inventory?.makeInventory(in: section, context: context)

        for (fieldOrder, record) in fields.enumerated() {
            let field = SheetField(label: record.label, code: record.code, order: fieldOrder)
            context.insert(field)
            field.section = section
            field.kindRaw = record.kind
            field.labelPlacementRaw = record.labelPlacement
            field.listIndex = record.listIndex
            field.isLive = record.isLive
            field.isNameField = record.isNameField
            field.unit = record.unit
            field.hint = record.hint
            field.minimum = record.minimum
            field.maximum = record.maximum
            field.step = record.step
            field.options = record.options
            field.resourceStyleRaw = record.resourceStyle
            field.formula = record.formula
            field.textValue = record.textValue
            field.numberValue = record.numberValue
            field.resourceMax = record.resourceMax
            field.boolValue = record.boolValue
            field.dateValue = record.dateValue
            field.imageData = record.imageData
        }

        var tableColumns: [SheetTableColumn] = []
        for (columnOrder, record) in columns.enumerated() {
            let tableColumn = SheetTableColumn(title: record.title, kind: .text, code: record.code, order: columnOrder)
            context.insert(tableColumn)
            tableColumn.section = section
            tableColumn.kindRaw = record.kind
            tableColumn.formula = record.formula
            tableColumn.isLive = record.isLive
            tableColumns.append(tableColumn)
        }

        for (groupOrder, record) in groups.enumerated() {
            let group = SheetTableGroup(title: record.title, order: groupOrder, hasValue: record.hasValue)
            context.insert(group)
            group.section = section
            group.numberValue = record.numberValue
            for (rowOrder, rowRecord) in record.rows.enumerated() {
                let tableRow = SheetTableRow(label: rowRecord.label, order: rowOrder)
                context.insert(tableRow)
                tableRow.group = group
                tableRow.specialization = rowRecord.specialization
                tableRow.allowsSpecialization = rowRecord.allowsSpecialization
                tableRow.isFromTemplate = rowRecord.isFromTemplate
                // Une cellule par colonne, même si le fichier en contient moins (invariant du modèle).
                for (index, tableColumn) in tableColumns.enumerated() {
                    let cell = SheetTableCell()
                    context.insert(cell)
                    cell.row = tableRow
                    cell.column = tableColumn
                    if index < rowRecord.cells.count {
                        let values = rowRecord.cells[index]
                        cell.textValue = values.textValue
                        cell.numberValue = values.numberValue
                        cell.boolValue = values.boolValue
                        cell.formula = values.formula
                    }
                }
            }
        }
    }
}

private extension Int64 {
    func floorDivided(by divisor: Int64) -> Int64 {
        let quotient = self / divisor
        return (self % divisor < 0) ? quotient - 1 : quotient
    }

    func floorModulo(_ divisor: Int64) -> Int64 {
        let remainder = self % divisor
        return remainder < 0 ? remainder + divisor : remainder
    }
}
