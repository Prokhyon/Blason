import Foundation
import SwiftData
import Testing
@testable import SheetKit

@MainActor
@Suite("Copie, duplication et suppression")
struct LibraryTests {

    @Test("Créer un personnage copie toute la structure du template")
    func characterCopiesTemplate() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let before = try EntityCounts(context)

        let character = template.makeCharacter(named: "Ada", in: context)
        let after = try EntityCounts(context)

        #expect(character.sheet != nil)
        #expect(character.sheet !== template.sheet)
        #expect(character.sourceTemplateName == template.name)
        #expect(character.sourceTemplateUID == template.uid)

        // Chaque objet de la fiche existe désormais en double, et rien d'autre n'a été créé.
        for key in ["Sheet", "Page", "SheetRow", "SheetSection", "SheetField",
                    "TableColumn", "TableGroup", "TableRow", "TableCell"] {
            #expect(after[key] == before[key] * 2, "\(key) : \(before[key]) → \(after[key])")
        }
        #expect(after["PlayerCharacter"] == 1)
        #expect(after["SheetTemplate"] == 1)

        // Même structure, à l'exception du nom renseigné dans la fiche du personnage.
        var expected = signature(of: template.sheet)
        if let index = expected.firstIndex(where: { $0.contains("field 0 Nom NOM text") }) {
            expected[index] = expected[index].replacingOccurrences(of: "NOM text ", with: "NOM text Ada")
        }
        #expect(signature(of: character.sheet) == expected)
        #expect(character.displayName == "Ada")
    }

    @Test("Modifier un personnage ne touche pas le template")
    func characterEditsAreIsolated() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let reference = signature(of: template.sheet)

        let character = template.makeCharacter(named: "Ada", in: context)
        character.sheet?.field(code: "FOR")?.numberValue = 18
        let skills = try #require(character.sheet?.section(titled: "Compétences"))
        let combat = try #require(skills.group(titled: "Combat"))
        skills.addRow(label: "Escrime", to: combat, isFromTemplate: false, in: context)
        try context.save()

        #expect(signature(of: template.sheet) == reference)
        #expect(template.sheet?.field(code: "FOR")?.numberValue == nil)
    }

    @Test("Modifier le template ne touche pas les personnages existants")
    func templateEditsAreIsolated() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let character = template.makeCharacter(named: "Ada", in: context)
        let reference = signature(of: character.sheet)

        template.sheet?.field(code: "MOUV")?.numberValue = 12
        let personal = try #require(template.sheet?.section(titled: "Personnel"))
        personal.addField(label: "Nouveau champ", kind: .text, in: context)
        try context.save()

        #expect(signature(of: character.sheet) == reference)
    }

    @Test("Supprimer un personnage ne laisse aucun orphelin")
    func deletingCharacterLeavesNoOrphans() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let before = try EntityCounts(context)

        let character = DemoData.leo(from: template, in: context)
        _ = try EntityCounts(context)
        context.delete(character)

        #expect(try EntityCounts(context) == before)
    }

    @Test("Supprimer un template garde ses personnages intacts")
    func deletingTemplateKeepsCharacters() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let character = DemoData.leo(from: template, in: context)
        let reference = signature(of: character.sheet)
        let withBoth = try EntityCounts(context)

        context.delete(template)
        let after = try EntityCounts(context)

        #expect(after["SheetTemplate"] == 0)
        #expect(after["PlayerCharacter"] == 1)
        #expect(after["Sheet"] == 1)
        #expect(after["SheetField"] < withBoth["SheetField"])
        #expect(signature(of: character.sheet) == reference)
    }

    @Test("Dupliquer un personnage crée une copie indépendante")
    func duplicateCharacter() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let leo = DemoData.leo(from: template, in: context)
        let reference = signature(of: leo.sheet)

        let copy = leo.duplicate(in: context)
        try context.save()

        #expect(copy.displayName == "Leo (copie)")
        #expect(copy.sourceTemplateUID == leo.sourceTemplateUID)
        copy.sheet?.field(code: "FOR")?.numberValue = 3
        #expect(leo.sheet?.field(code: "FOR")?.numberValue == 11)
        #expect(signature(of: leo.sheet) == reference)
    }

    @Test("Dupliquer un template crée une copie indépendante")
    func duplicateTemplate() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let copy = template.duplicate(in: context)
        try context.save()

        #expect(copy.name == "\(template.name) (copie)")
        #expect(signature(of: copy.sheet) == signature(of: template.sheet))
        copy.sheet?.section(titled: "Personnel")?.title = "Identité"
        #expect(template.sheet?.section(titled: "Personnel") != nil)
    }

    @Test("Enregistrer comme template crée un nouveau template avec les valeurs du personnage")
    func templateFromCharacter() throws {
        let context = try makeContext()
        let source = DemoData.brpTemplate(in: context)
        let leo = DemoData.leo(from: source, in: context)

        let template = leo.makeTemplate(named: "BRP — Leo", system: "BRP", in: context)
        try context.save()

        #expect(template !== source)
        #expect(signature(of: template.sheet) == signature(of: leo.sheet))
        template.sheet?.field(code: "FOR")?.numberValue = 1
        #expect(leo.sheet?.field(code: "FOR")?.numberValue == 11)
        #expect(try context.fetchCount(FetchDescriptor<SheetTemplate>()) == 2)
    }
}

@MainActor
@Suite("Suppressions dans la structure")
struct StructureDeletionTests {

    @Test("Supprimer une colonne supprime ses cellules")
    func deletingColumnDeletesCells() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let skills = try #require(template.sheet?.section(titled: "Compétences"))
        let rowCount = skills.allTableRows.count
        let before = try EntityCounts(context)

        context.delete(try #require(skills.column(code: "exp")))
        let after = try EntityCounts(context)

        #expect(after["TableColumn"] == before["TableColumn"] - 1)
        #expect(after["TableCell"] == before["TableCell"] - rowCount)
        #expect(skills.allTableRows.allSatisfy { $0.cell(code: "exp") == nil })
    }

    @Test("Supprimer une section supprime ses champs, colonnes, groupes, lignes et cellules")
    func deletingSectionDeletesChildren() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let skills = try #require(template.sheet?.section(titled: "Compétences"))
        let rows = skills.allTableRows.count
        let columns = skills.sortedColumns.count
        let groups = skills.sortedGroups.count
        let before = try EntityCounts(context)

        context.delete(skills)
        let after = try EntityCounts(context)

        #expect(after["SheetSection"] == before["SheetSection"] - 1)
        #expect(after["TableColumn"] == before["TableColumn"] - columns)
        #expect(after["TableGroup"] == before["TableGroup"] - groups)
        #expect(after["TableRow"] == before["TableRow"] - rows)
        #expect(after["TableCell"] == before["TableCell"] - rows * columns)
    }

    @Test("Supprimer un champ ne touche que ce champ")
    func deletingField() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let before = try EntityCounts(context)

        context.delete(try #require(template.sheet?.field(code: "AGE")))
        let after = try EntityCounts(context)

        #expect(after["SheetField"] == before["SheetField"] - 1)
        #expect(template.sheet?.field(code: "AGE") == nil)
    }

    @Test("Ajouter une colonne crée une cellule dans chaque ligne existante")
    func addingColumnCreatesCells() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let skills = try #require(template.sheet?.section(titled: "Compétences"))

        skills.addColumn(title: "½", kind: .formula, code: "moitie", in: context)
        try context.save()

        #expect(skills.allTableRows.allSatisfy { $0.cells?.count == 4 && $0.cell(code: "moitie") != nil })
    }
}
