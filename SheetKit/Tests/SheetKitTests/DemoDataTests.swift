import Foundation
import SwiftData
import Testing
@testable import SheetKit

@MainActor
@Suite("Données de démo (BRP et Leo)")
struct DemoDataTests {

    @Test("Le template BRP a ses quatre pages")
    func templatePages() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let titles = template.sheet?.sortedPages.map(\.title)
        #expect(titles == ["Personnage", "Compétences", "Combat", "Pouvoirs et notes"])
    }

    @Test("Chaque ligne de tableau a une cellule par colonne")
    func everyRowHasAllCells() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let leo = DemoData.leo(from: template, in: context)
        for sheet in [template.sheet, leo.sheet] {
            for section in sheet?.allSections ?? [] where section.kind == .table {
                let columns = section.sortedColumns.count
                for row in section.allTableRows {
                    #expect(row.cells?.count == columns, "\(section.title) / \(row.label)")
                    #expect(row.cells?.allSatisfy { $0.column != nil } == true)
                }
            }
        }
    }

    @Test("Les codes des champs sont uniques")
    func uniqueCodes() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let codes = (template.sheet?.allFields ?? []).map(\.code).filter { !$0.isEmpty }
        #expect(Set(codes.map { $0.uppercased() }).count == codes.count)
    }

    @Test("Leo a les valeurs de la fiche de référence")
    func leoValues() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let leo = DemoData.leo(from: template, in: context)
        try context.save()
        let sheet = try #require(leo.sheet)

        #expect(leo.displayName == "Leo")
        #expect(sheet.field(code: "FOR")?.numberValue == 11)
        #expect(sheet.field(code: "DEX")?.numberValue == 16)
        #expect(sheet.field(code: "SAN")?.displayValue == "47 / 65")
        #expect(sheet.field(code: "PV")?.displayValue == "14 / 14")

        let skills = try #require(sheet.section(titled: "Compétences"))
        #expect(skills.tableRow(label: "Repérer")?.cell(code: "valeur")?.numberValue == 75)
        #expect(skills.tableRow(label: "Connaissance")?.displayLabel == "Connaissance (Hautes sphères)")
        #expect(skills.tableRow(label: "Monter")?.cell(code: "valeur")?.displayValue == "80 %")
        #expect(skills.tableRow(label: "Esquive")?.cell(code: "base")?.formula == "=DEX*2")

        let fencing = try #require(skills.tableRow(label: "Escrime"))
        #expect(fencing.isFromTemplate == false)
        #expect(fencing.group?.title == "Combat")
        #expect(fencing.cell(code: "valeur")?.numberValue == 70)

        let weapons = try #require(sheet.section(titled: "Armes"))
        #expect(weapons.allTableRows.map(\.label) ==
                ["Bagarre", "Lutte", "Fleuret", "Pistolet", "Sabre d'officier", "Poignard de main"])
        #expect(weapons.tableRow(label: "Pistolet")?.cell(code: "pct")?.numberValue == 75)

        #expect(sheet.section(titled: "Défauts")?.allTableRows.map(\.label) == ["Impulsif"])
    }

    @Test("Le template n'est créé qu'une fois")
    func seedIsIdempotent() throws {
        let context = try makeContext()
        try DemoData.seedIfEmpty(in: context)
        try DemoData.seedIfEmpty(in: context)
        #expect(try context.fetchCount(FetchDescriptor<SheetTemplate>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<PlayerCharacter>()) == 1)
    }

    @Test("L'exemple s'ajoute à la demande, à côté des fiches existantes")
    func addExample() throws {
        let context = try makeContext()
        let first = try DemoData.addExample(in: context)
        #expect(first.template.name == DemoData.templateName)
        #expect(first.character.sourceTemplateUID == first.template.uid)
        #expect(first.character.displayName == "Leo")

        let second = try DemoData.addExample(in: context)
        #expect(second.template.uid != first.template.uid)
        #expect(try context.fetchCount(FetchDescriptor<SheetTemplate>()) == 2)
        #expect(try context.fetchCount(FetchDescriptor<PlayerCharacter>()) == 2)
    }
}
