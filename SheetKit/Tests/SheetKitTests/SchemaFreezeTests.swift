import Foundation
import SwiftData
import Testing
@testable import SheetKit

/// Le schéma V1 est en service (fiches réelles, base privée iCloud) : il ne change plus.
/// Si ce test échoue, ne pas mettre à jour la liste : créer un `SheetSchemaV2` (copie de V1
/// modifiée), l'ajouter à `SheetMigrationPlan` avec une étape testée, et garder ce test sur V1,
/// qui doit rester tel quel. Côté iCloud, un changement ne fait qu'ajouter : pas de renommage
/// ni de suppression (SPEC §5.7).
@Suite("Schéma V1 figé")
struct SchemaFreezeTests {

    /// Empreinte d'un schéma : une ligne par attribut (nom et type) et par relation (destination).
    static func fingerprint(of schema: Schema) -> [String] {
        schema.entities.flatMap { entity in
            entity.attributes.map { "\(entity.name).\($0.name): \($0.valueType)" }
                + entity.relationships.map {
                    "\(entity.name).\($0.name) → \($0.destination)\($0.isToOneRelationship ? "" : "[]")"
                }
        }.sorted()
    }

    @Test("Le schéma V1 n'a pas changé depuis la synchronisation iCloud")
    func schemaV1IsFrozen() {
        #expect(SheetSchemaV1.versionIdentifier == Schema.Version(1, 0, 0))
        let current = Self.fingerprint(of: Schema(versionedSchema: SheetSchemaV1.self))
        let added = Set(current).subtracting(Self.frozenV1)
        let removed = Set(Self.frozenV1).subtracting(current)
        #expect(added.isEmpty && removed.isEmpty, "ajouté : \(added.sorted()) ; retiré : \(removed.sorted())")
    }

    /// Schéma V1 au 11 novembre 2026 (clôture de la V1.2).
    static let frozenV1: [String] = [
            "Page.order: Int",
            "Page.rows → SheetRow[]",
            "Page.sheet → Sheet",
            "Page.title: String",
            "PlayerCharacter.createdAt: Date",
            "PlayerCharacter.name: String",
            "PlayerCharacter.sheet → Sheet",
            "PlayerCharacter.sourceTemplateName: String",
            "PlayerCharacter.sourceTemplateUID: Optional<UUID>",
            "PlayerCharacter.uid: UUID",
            "PlayerCharacter.updatedAt: Date",
            "Sheet.character → PlayerCharacter",
            "Sheet.pages → Page[]",
            "Sheet.template → SheetTemplate",
            "Sheet.themeColor: Optional<String>",
            "Sheet.themeID: Optional<String>",
            "SheetField.boolValue: Optional<Bool>",
            "SheetField.code: String",
            "SheetField.dateValue: Optional<Date>",
            "SheetField.formula: Optional<String>",
            "SheetField.hint: Optional<String>",
            "SheetField.imageData: Optional<Data>",
            "SheetField.isLive: Bool",
            "SheetField.isNameField: Bool",
            "SheetField.kindRaw: String",
            "SheetField.label: String",
            "SheetField.labelPlacementRaw: String",
            "SheetField.listIndex: Int",
            "SheetField.maximum: Optional<Double>",
            "SheetField.minimum: Optional<Double>",
            "SheetField.numberValue: Optional<Double>",
            "SheetField.options: Array<String>",
            "SheetField.order: Int",
            "SheetField.resourceMax: Optional<Double>",
            "SheetField.resourceStyleRaw: String",
            "SheetField.section → SheetSection",
            "SheetField.step: Optional<Double>",
            "SheetField.textValue: Optional<String>",
            "SheetField.unit: Optional<String>",
            "SheetRow.columnWeights: Array<Double>",
            "SheetRow.order: Int",
            "SheetRow.page → Page",
            "SheetRow.sections → SheetSection[]",
            "SheetSection.arrangementRaw: String",
            "SheetSection.columnCount: Int",
            "SheetSection.columnIndex: Int",
            "SheetSection.columns → SheetTableColumn[]",
            "SheetSection.fields → SheetField[]",
            "SheetSection.groups → SheetTableGroup[]",
            "SheetSection.kindRaw: String",
            "SheetSection.labelColumnTitle: String",
            "SheetSection.order: Int",
            "SheetSection.row → SheetRow",
            "SheetSection.title: String",
            "SheetTableCell.boolValue: Optional<Bool>",
            "SheetTableCell.column → SheetTableColumn",
            "SheetTableCell.formula: Optional<String>",
            "SheetTableCell.numberValue: Optional<Double>",
            "SheetTableCell.row → SheetTableRow",
            "SheetTableCell.textValue: Optional<String>",
            "SheetTableColumn.cells → SheetTableCell[]",
            "SheetTableColumn.code: String",
            "SheetTableColumn.formula: Optional<String>",
            "SheetTableColumn.isLive: Bool",
            "SheetTableColumn.kindRaw: String",
            "SheetTableColumn.order: Int",
            "SheetTableColumn.section → SheetSection",
            "SheetTableColumn.title: String",
            "SheetTableGroup.hasValue: Bool",
            "SheetTableGroup.numberValue: Optional<Double>",
            "SheetTableGroup.order: Int",
            "SheetTableGroup.rows → SheetTableRow[]",
            "SheetTableGroup.section → SheetSection",
            "SheetTableGroup.title: String",
            "SheetTableRow.allowsSpecialization: Bool",
            "SheetTableRow.cells → SheetTableCell[]",
            "SheetTableRow.group → SheetTableGroup",
            "SheetTableRow.isFromTemplate: Bool",
            "SheetTableRow.label: String",
            "SheetTableRow.order: Int",
            "SheetTableRow.specialization: Optional<String>",
            "SheetTemplate.createdAt: Date",
            "SheetTemplate.name: String",
            "SheetTemplate.notes: String",
            "SheetTemplate.sheet → Sheet",
            "SheetTemplate.system: String",
            "SheetTemplate.uid: UUID",
            "SheetTemplate.updatedAt: Date",
    ]
}
