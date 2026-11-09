import Foundation
import SwiftData
import Testing
@testable import SheetKit

@MainActor
@Suite("Apparence : thème du template, suivi ou remplacé par le personnage")
struct AppearanceTests {

    @Test("Le personnage suit le template, même après coup, jusqu'à choisir son propre thème")
    func inheritance() throws {
        let context = try makeContext()
        let template = SheetTemplate.create(name: "T", firstPage: "P", in: context)
        let character = template.makeCharacter(named: "Leo", in: context)
        let sheet = try #require(character.sheet)
        #expect(sheet.appearance(in: context) == .standard)

        template.sheet?.ownAppearance = SheetAppearance(themeID: "paper", colorID: "red")
        #expect(sheet.appearance(in: context) == SheetAppearance(themeID: "paper", colorID: "red"))
        // Un personnage créé ensuite suit aussi le template (il n'en copie pas le thème).
        let other = template.makeCharacter(named: "Ana", in: context)
        #expect(other.sheet?.ownAppearance == nil)

        sheet.ownAppearance = SheetAppearance(themeID: "native", colorID: "green")
        template.sheet?.ownAppearance = SheetAppearance(themeID: "templateColor", colorID: "teal")
        #expect(sheet.appearance(in: context) == SheetAppearance(themeID: "native", colorID: "green"))
        #expect(other.sheet?.appearance(in: context) == SheetAppearance(themeID: "templateColor", colorID: "teal"))

        // Revenir au template.
        sheet.ownAppearance = nil
        #expect(sheet.appearance(in: context).themeID == "templateColor")

        // Template supprimé : thème natif.
        context.delete(template)
        try context.save()
        #expect(other.sheet?.appearance(in: context) == .standard)
    }

    @Test("Dupliquer garde le thème ; l'export le transporte, sans rien écrire quand il n'y en a pas")
    func copyAndExport() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let plain = try SheetDocument(template: template).jsonData()
        #expect(!String(decoding: plain, as: UTF8.self).contains("theme"))

        template.sheet?.ownAppearance = SheetAppearance(themeID: "paper", colorID: "brown")
        #expect(template.sheet?.deepCopy(in: context).ownAppearance == SheetAppearance(themeID: "paper", colorID: "brown"))

        let data = try SheetDocument(template: template).jsonData()
        guard case .template(let imported) = try SheetDocument.decode(data).insert(into: try makeContext()) else {
            Issue.record("pas un template"); return
        }
        #expect(imported.sheet?.ownAppearance == SheetAppearance(themeID: "paper", colorID: "brown"))
    }
}
