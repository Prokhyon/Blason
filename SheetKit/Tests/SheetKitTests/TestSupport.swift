import Foundation
import SwiftData
@testable import SheetKit

/// Base en mémoire, neuve pour chaque test.
@MainActor
func makeContext() throws -> ModelContext {
    let container = try SheetStore.makeContainer(inMemory: true)
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
