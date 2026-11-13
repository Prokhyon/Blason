import Foundation
import SwiftData
import Testing
@testable import SheetKit

@MainActor
@Suite("Disposition des champs")
struct FieldLayoutTests {

    @Test("Largeur auto selon le type, en sixièmes")
    func autoWidth() {
        #expect(FieldWidth.auto.sixths(for: .text) == 3)
        #expect(FieldWidth.auto.sixths(for: .integer) == 2)
        #expect(FieldWidth.auto.sixths(for: .checkbox) == 2)
        #expect(FieldWidth.auto.sixths(for: .longText) == 6)
        #expect(FieldWidth.auto.sixths(for: .image) == 6)
        #expect(FieldWidth.auto.sixths(for: .resource, resourceStyle: .track) == 6)
        #expect(FieldWidth.auto.sixths(for: .resource, resourceStyle: .counter) == 3)
        #expect(FieldWidth.full.sixths(for: .integer) == 6)
        #expect(FieldWidth.half.sixths(for: .longText) == 3)
        #expect(FieldWidth.third.sixths(for: .text) == 2)
    }

    @Test("Paires et Tuiles : deux listes, quel que soit le nombre de colonnes")
    func pairsUseTwoLists() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let section = try #require(template.sheet?.section(titled: "Caractéristiques"))
        #expect(section.arrangement == .pairs)
        section.columnCount = 4
        let field = try #require(section.sortedFields.first { $0.code == "EFFORT" })
        field.listIndex = 3
        #expect(field.effectiveListIndex == 1)
        section.arrangement = .list
        #expect(field.effectiveListIndex == 0)
    }

    @Test("Template BRP : chaque caractéristique en face de son jet")
    func brpPairs() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let section = try #require(template.sheet?.section(titled: "Caractéristiques"))
        let fields = section.sortedFields
        let left = fields.filter { $0.effectiveListIndex == 0 }.map(\.code)
        let right = fields.filter { $0.effectiveListIndex == 1 }.map(\.code)
        #expect(left == ["FOR", "CON", "TAI", "INT", "POU", "DEX", "CHA", "EDU"])
        #expect(right == ["EFFORT", "ENDURANCE", "MODDEG", "IDEE", "CHANCE", "AGILITE", "CHARME", "SAVOIR"])
    }

    @Test("Un champ ajouté après un autre du même type reprend sa largeur")
    func insertedFieldKeepsWidth() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let section = try #require(template.sheet?.section(titled: "Personnel"))
        let previous = try #require(section.sortedFields.first)
        previous.width = .full
        let same = section.insertField(label: "Surnom", kind: previous.kind, after: previous, in: context)
        let other = section.insertField(label: "Taille", kind: .integer, after: previous, in: context)
        #expect(same.width == .full)
        #expect(other.width == .auto)
    }

    @Test("Une copie garde la largeur")
    func copyKeepsWidth() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let field = try #require(template.sheet?.section(titled: "Personnel")?.sortedFields.first)
        field.width = .third
        let leo = DemoData.leo(from: template, in: context)
        #expect(leo.sheet?.section(titled: "Personnel")?.sortedFields.first?.width == .third)
    }
}
