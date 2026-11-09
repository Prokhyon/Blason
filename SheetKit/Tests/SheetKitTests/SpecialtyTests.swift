import Foundation
import SwiftData
import Testing
@testable import SheetKit

@MainActor
@Suite("Spécialités : catégorie et lignes en retrait")
struct SpecialtyTests {

    /// « # Catégorie », « ␣␣Spécialité » (« ␣␣… » sans précision), ou la ligne seule.
    private func describe(_ lines: [TableLine]) -> [String] {
        lines.map { line in
            switch line {
            case .row(let row, indented: false):
                row.hasSpecialization ? "\(row.label) (\(row.specialization!))" : row.label
            case .row(let row, indented: true):
                "  " + (row.hasSpecialization ? row.specialization! : "…")
            case .category(let row):
                "# \(row.label)"
            }
        }
    }

    private func leoSkills(_ context: ModelContext) throws -> SheetSection {
        let template = DemoData.brpTemplate(in: context)
        let leo = DemoData.leo(from: template, in: context)
        return try #require(leo.sheet?.section(titled: "Compétences"))
    }

    @Test("Lecture : une précision saisie donne catégorie + retrait ; sans précision, une seule ligne")
    func reading() throws {
        let context = try makeContext()
        let skills = try leoSkills(context)
        let mental = try #require(skills.group(titled: "Mental"))
        let lines = describe(mental.lines(editing: false))
        #expect(Array(lines.prefix(6)) == ["Évaluer", "Premiers soins", "Jeu", "# Connaissance", "  Hautes sphères", "Lire / écrire"])

        let communication = describe(try #require(skills.group(titled: "Communication")).lines(editing: false))
        #expect(communication.contains("Langue"))
        #expect(!communication.contains("# Langue"))

        let physique = describe(try #require(skills.group(titled: "Physique")).lines(editing: false))
        #expect(physique.contains("# Monter"))
        #expect(physique.contains("  Navire"))
    }

    @Test("Saisie : toujours catégorie et spécialités en retrait, même sans précision")
    func editing() throws {
        let context = try makeContext()
        let skills = try leoSkills(context)
        let lines = describe(try #require(skills.group(titled: "Communication")).lines(editing: true))
        let langue = try #require(lines.firstIndex(of: "# Langue"))
        #expect(Array(lines[langue...].prefix(3)) == ["# Langue", "  …", "Représentation"])
        #expect(lines.contains("Marchander"))
    }

    @Test("Ajouter une spécialité : valeurs du template reprises, saisies du joueur laissées vides")
    func addSpecialty() throws {
        let context = try makeContext()
        let skills = try leoSkills(context)
        let hautes = try #require(skills.tableRow(label: "Connaissance", specialization: "Hautes sphères"))
        hautes.cell(code: "exp")?.boolValue = true
        #expect(hautes.cell(code: "valeur")?.numberValue == 24)

        let added = try #require(hautes.addSpecialty(in: context))
        added.specialization = "Héraldique"
        #expect(added.label == "Connaissance")
        #expect(added.allowsSpecialization)
        #expect(!added.isFromTemplate)
        #expect(added.cell(code: "base")?.numberValue == 5)
        #expect(added.cell(code: "valeur")?.numberValue == nil)
        #expect(added.cell(code: "exp")?.boolValue != true)
        #expect(FormulaEngine(sheet: added.cell(code: "valeur")?.sheet).value(of: try #require(added.cell(code: "valeur"))) == .success(5))

        let mental = try #require(skills.group(titled: "Mental"))
        #expect(Array(describe(mental.lines(editing: false)).prefix(7))
                == ["Évaluer", "Premiers soins", "Jeu", "# Connaissance", "  Hautes sphères", "  Héraldique", "Lire / écrire"])
        // Une base calculée (Langue natale : =EDU*5) reste une formule.
        let natale = try #require(skills.tableRow(label: "Langue natale"))
        #expect(natale.addSpecialty(in: context)?.cell(code: "base")?.formula == "=EDU*5")
    }

    @Test("Les lignes d'une même famille se regroupent même séparées")
    func scatteredFamily() throws {
        let context = try makeContext()
        let sheet = try #require(SheetTemplate.create(name: "T", firstPage: "P", in: context).sheet)
        let table = sheet.sortedPages[0].sortedRows[0].addSection(title: "Compétences", kind: .table, in: context)
        table.addColumn(title: "%", kind: .percentage, code: "valeur", in: context)
        let group = table.addGroup(title: "", in: context)
        table.addRow(label: "Art", to: group, allowsSpecialization: true, in: context).specialization = "Peinture"
        table.addRow(label: "Baratin", to: group, in: context)
        table.addRow(label: "Art", to: group, allowsSpecialization: true, in: context).specialization = "Chant"
        #expect(describe(group.lines(editing: false)) == ["# Art", "  Peinture", "  Chant", "Baratin"])
        // Une ligne non spécialisable de même libellé n'entre pas dans la famille.
        table.addRow(label: "Art", to: group, in: context)
        #expect(describe(group.lines(editing: false)).last == "Art")
    }
}
