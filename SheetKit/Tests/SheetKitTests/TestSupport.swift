import Foundation
import SwiftData
@testable import SheetKit

/// Base en mémoire, neuve pour chaque test.
@MainActor
func makeContext() throws -> ModelContext {
    let container = try SheetStore.makeInMemoryContainer()
    // Le contexte ne retient pas son conteneur : on le garde en vie le temps du test.
    retainedContainers.append(container)
    return container.mainContext
}

@MainActor private var retainedContainers: [ModelContainer] = []

/// Nombre d'objets de chaque type dans la base (après sauvegarde).
struct EntityCounts: Equatable, CustomStringConvertible {
    var values: [String: Int]

    @MainActor
    init(_ context: ModelContext) throws {
        try context.save()
        values = [
            "SheetTemplate": try context.fetchCount(FetchDescriptor<SheetTemplate>()),
            "PlayerCharacter": try context.fetchCount(FetchDescriptor<PlayerCharacter>()),
            "Sheet": try context.fetchCount(FetchDescriptor<Sheet>()),
            "Page": try context.fetchCount(FetchDescriptor<Page>()),
            "SheetRow": try context.fetchCount(FetchDescriptor<SheetRow>()),
            "SheetSection": try context.fetchCount(FetchDescriptor<SheetSection>()),
            "SheetField": try context.fetchCount(FetchDescriptor<SheetField>()),
            "SheetTableColumn": try context.fetchCount(FetchDescriptor<SheetTableColumn>()),
            "SheetTableGroup": try context.fetchCount(FetchDescriptor<SheetTableGroup>()),
            "SheetTableRow": try context.fetchCount(FetchDescriptor<SheetTableRow>()),
            "SheetTableCell": try context.fetchCount(FetchDescriptor<SheetTableCell>()),
            "Inventory": try context.fetchCount(FetchDescriptor<Inventory>()),
            "ItemType": try context.fetchCount(FetchDescriptor<ItemType>()),
            "ItemProperty": try context.fetchCount(FetchDescriptor<ItemProperty>()),
            "InventoryItem": try context.fetchCount(FetchDescriptor<InventoryItem>()),
            "ItemPropertyValue": try context.fetchCount(FetchDescriptor<ItemPropertyValue>()),
            "Currency": try context.fetchCount(FetchDescriptor<Currency>()),
            "InventorySlot": try context.fetchCount(FetchDescriptor<InventorySlot>()),
            "EncumbranceLevel": try context.fetchCount(FetchDescriptor<EncumbranceLevel>()),
            "Journal": try context.fetchCount(FetchDescriptor<Journal>()),
            "JournalSession": try context.fetchCount(FetchDescriptor<JournalSession>()),
            "CodexEntry": try context.fetchCount(FetchDescriptor<CodexEntry>()),
            "JournalDocument": try context.fetchCount(FetchDescriptor<JournalDocument>()),
        ]
    }

    subscript(_ key: String) -> Int { values[key] ?? 0 }

    var description: String {
        values.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
    }
}

/// Empreinte textuelle de la structure et des valeurs d'une fiche, pour comparer deux copies.
func signature(of sheet: Sheet?) -> [String] {
    guard let sheet else { return [] }
    var lines: [String] = []
    for page in sheet.sortedPages {
        lines.append("page \(page.order) \(page.title)")
        for row in page.sortedRows {
            lines.append("  row \(row.order) \(row.columnWeights)")
            for section in row.sortedSections {
                lines.append("    section \(section.order) \(section.title) \(section.kindRaw) \(section.arrangementRaw) \(section.columnCount) col=\(section.columnIndex)")
                for field in section.sortedFields {
                    lines.append("      field \(field.order) \(field.label) \(field.code) \(field.kindRaw) \(field.displayValue) \(field.formula ?? "-") live=\(field.isLive)")
                }
                if !section.viewTypeCodes.isEmpty || !section.viewPropertyCodes.isEmpty {
                    lines.append("      view \(section.viewTypeCodes) \(section.viewPropertyCodes)")
                }
                if let inventory = section.inventory {
                    lines += inventorySignature(inventory).map { "      " + $0 }
                }
                for column in section.sortedColumns {
                    lines.append("      column \(column.order) \(column.title) \(column.code) \(column.kindRaw)")
                }
                for group in section.sortedGroups {
                    lines.append("      group \(group.order) \(group.title)")
                    for tableRow in group.sortedRows {
                        let cells = section.sortedColumns.map { tableRow.cell(for: $0)?.displayValue ?? "∅" }
                        lines.append("        row \(tableRow.order) \(tableRow.displayLabel) [\(cells.joined(separator: "|"))]")
                    }
                }
            }
        }
    }
    return lines
}

/// Empreinte d'une Besace : réglages, types, monnaies, paliers, emplacements, objets et valeurs.
func inventorySignature(_ inventory: Inventory) -> [String] {
    var lines = ["inventory \(inventory.code) weight=\(inventory.tracksWeight) \(inventory.weightUnit) \(inventory.weightLimitFormula ?? "-") malus=\(inventory.appliesMalus)"]
    for type in inventory.sortedItemTypes {
        lines.append("  type \(type.order) \(type.name) \(type.code) \(type.icon)")
        for property in type.sortedProperties {
            lines.append("    property \(property.order) \(property.label) \(property.code) \(property.kindRaw) \(property.formula ?? "-") live=\(property.isLive) \(property.textValue ?? "-") \(property.numberValue.map { "\($0)" } ?? "-") \(property.boolValue.map { "\($0)" } ?? "-")")
        }
    }
    for currency in inventory.sortedCurrencies {
        lines.append("  currency \(currency.order) \(currency.name) \(currency.abbreviation) \(currency.rate)")
    }
    for level in inventory.sortedLevels {
        lines.append("  level \(level.order) \(level.name) \(level.thresholdFormula ?? "-") \(level.malus.map { "\($0)" } ?? "-") \(level.effect)")
    }
    func itemLines(_ item: InventoryItem, indent: String) -> [String] {
        let values = (item.type?.sortedProperties ?? []).map { property in
            item.value(for: property).map { "\($0.textValue ?? "")|\($0.numberValue.map { "\($0)" } ?? "")|\($0.boolValue.map { "\($0)" } ?? "")|\($0.formula ?? "")" } ?? "∅"
        }
        var lines = ["\(indent)item \(item.order) \(item.name) ×\(item.quantity) \(item.unitWeight.map { "\($0)" } ?? "-") \(item.price) eq=\(item.isEquipped) box=\(item.isContainer) \(item.summary) \(item.notes) img=\(item.imageData?.count ?? 0) type=\(item.type?.name ?? "-") cur=\(item.currency?.name ?? "-") [\(values.joined(separator: ", "))]"]
        for content in item.sortedContents {
            lines += itemLines(content, indent: indent + "  ")
        }
        return lines
    }
    for slot in inventory.sortedSlots {
        lines.append("  slot \(slot.order) \(slot.name) \(slot.icon) counts=\(slot.countsTowardEncumbrance) \(slot.capacity.map { "\($0)" } ?? "-")")
        for loose in slot.looseItems {
            lines += itemLines(loose, indent: "    ")
        }
    }
    return lines
}
