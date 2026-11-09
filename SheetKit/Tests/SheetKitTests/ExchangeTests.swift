import Foundation
import SwiftData
import Testing
@testable import SheetKit

@MainActor
@Suite("Export / import JSON")
struct ExchangeTests {

    /// Leo, avec une image, une date, une option de choix et un groupe valorisé : toutes les sortes de valeurs.
    private func richLeo(_ context: ModelContext) throws -> PlayerCharacter {
        let template = DemoData.brpTemplate(in: context)
        let leo = DemoData.leo(from: template, in: context)
        let sheet = try #require(leo.sheet)
        let image = sheet.allFields.first { $0.kind == .image }
        image?.imageData = Data((0..<2048).map { UInt8($0 % 251) })
        let personnel = try #require(sheet.section(titled: "Personnel"))
        let date = personnel.addField(label: "Naissance", kind: .date, in: context)
        date.dateValue = Date(timeIntervalSince1970: 1_234_567_890.125)
        let choice = personnel.addField(label: "Main", kind: .choice, in: context)
        choice.options = ["Droite", "Gauche"]
        choice.textValue = "Gauche"
        choice.hint = "main directrice"
        let skills = try #require(sheet.section(titled: "Compétences"))
        skills.group(titled: "Communication")?.numberValue = 5
        return leo
    }

    @Test("Aller-retour d'un personnage sans perte")
    func characterRoundTrip() throws {
        let context = try makeContext()
        let leo = try richLeo(context)
        let exported = SheetDocument(character: leo, exportedAt: Date(timeIntervalSince1970: 0))
        let data = try exported.jsonData()

        // Importé dans une autre base : même contenu, attribut par attribut.
        let other = try makeContext()
        let decoded = try SheetDocument.decode(data)
        // Les dates sont écrites à la milliseconde : on compare les fichiers plutôt que les structures.
        #expect(try decoded.jsonData() == data)
        guard case .character(let imported) = try decoded.insert(into: other) else {
            Issue.record("pas un personnage"); return
        }
        #expect(imported.uid == leo.uid)
        #expect(imported.displayName == "Leo")
        #expect(imported.sourceTemplateName == leo.sourceTemplateName)
        #expect(abs(imported.createdAt.timeIntervalSince(leo.createdAt)) < 0.001)
        #expect(signature(of: imported.sheet) == signature(of: leo.sheet))
        #expect(imported.portraitData == leo.portraitData)
        let date = imported.sheet?.allFields.first { $0.kind == .date }?.dateValue
        #expect(date == Date(timeIntervalSince1970: 1_234_567_890.125))

        // Réexporter donne exactement le même fichier.
        #expect(try SheetDocument(character: imported, exportedAt: Date(timeIntervalSince1970: 0)).jsonData() == data)

        // Les formules se calculent comme avant.
        let engine = FormulaEngine(sheet: imported.sheet)
        #expect(engine.value(of: try #require(imported.sheet?.field(code: "EFFORT"))) == .success(55))
    }

    @Test("Aller-retour d'un template ; importé deux fois, il reçoit un nouvel identifiant")
    func templateRoundTrip() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let data = try SheetDocument(template: template).jsonData()
        let before = try EntityCounts(context)

        guard case .template(let copy) = try SheetDocument.decode(data).insert(into: context) else {
            Issue.record("pas un template"); return
        }
        try context.save()
        #expect(copy.uid != template.uid)
        #expect(copy.name == template.name)
        #expect(copy.system == "BRP")
        #expect(signature(of: copy.sheet) == signature(of: template.sheet))

        // Le template importé est complet : chaque objet de la fiche existe en double.
        let after = try EntityCounts(context)
        for key in ["Sheet", "Page", "SheetRow", "SheetSection", "SheetField",
                    "SheetTableColumn", "SheetTableGroup", "SheetTableRow", "SheetTableCell"] {
            #expect(after[key] == before[key] * 2, "\(key)")
        }

        // Dans une base vide, l'identifiant est conservé (les personnages restent reliés à leur template).
        let other = try makeContext()
        guard case .template(let fresh) = try SheetDocument.decode(data).insert(into: other) else { return }
        #expect(fresh.uid == template.uid)
    }

    @Test("Le format couvre tous les attributs du modèle")
    func formatCoversModel() throws {
        // Si un attribut est ajouté au modèle, ce test rappelle de l'ajouter au format d'échange.
        func properties(_ value: Any) -> Set<String> {
            Set(Mirror(reflecting: value).children.compactMap(\.label))
        }
        let renamed = ["kindRaw": "kind", "arrangementRaw": "arrangement", "labelPlacementRaw": "labelPlacement",
                       "resourceStyleRaw": "resourceStyle", "columnIndex": "column"]
        let field = SheetDocument.FieldRecord(SheetField(label: "x"))
        let column = SheetDocument.ColumnRecord(title: "", code: "", kind: "", formula: nil, isLive: false)
        let cell = SheetDocument.CellRecord(textValue: nil, numberValue: nil, boolValue: nil, formula: nil)
        let group = SheetDocument.GroupRecord(title: "", hasValue: false, numberValue: nil, rows: [])
        let tableRow = SheetDocument.TableRowRecord(label: "", specialization: nil, allowsSpecialization: false, isFromTemplate: false, cells: [])
        let section = SheetDocument.SectionRecord(title: "", column: 0, kind: "", arrangement: "", columnCount: 1,
                                                  labelColumnTitle: "", fields: [], columns: [], groups: [])
        let row = SheetDocument.RowRecord(columnWeights: [], sections: [])
        let page = SheetDocument.PageRecord(title: "", rows: [])
        let sheetRecord = SheetDocument.SheetRecord(pages: [], themeID: nil, themeColor: nil)
        let document = SheetDocument(template: SheetTemplate(name: ""))
        let character = SheetDocument(character: PlayerCharacter(name: ""))
        let records: [String: Set<String>] = [
            "SheetField": properties(field), "SheetTableColumn": properties(column), "SheetTableCell": properties(cell),
            "SheetTableGroup": properties(group), "SheetTableRow": properties(tableRow), "SheetSection": properties(section),
            "SheetRow": properties(row), "Page": properties(page), "Sheet": properties(sheetRecord),
            "SheetTemplate": properties(try #require(document.template)),
            "PlayerCharacter": properties(try #require(character.character)),
        ]
        var checked = 0
        for entity in SheetStore.schema.entities {
            guard let recorded = records[entity.name] else { continue }
            checked += 1
            let attributes = Set(entity.attributes.map { renamed[$0.name] ?? $0.name }).subtracting(["order"])
            #expect(attributes.subtracting(recorded).isEmpty, "\(entity.name) : \(attributes.subtracting(recorded).sorted())")
        }
        #expect(checked == records.count, "entités : \(SheetStore.schema.entities.map(\.name))")
    }

    @Test("Fichiers refusés : autre JSON, version future, document vide, contenu abîmé")
    func rejectedFiles() throws {
        #expect(throws: SheetImportError.notASheetDocument) { try SheetDocument.decode(Data("pas du json".utf8)) }
        #expect(throws: SheetImportError.notASheetDocument) { try SheetDocument.decode(Data(#"{"name": "Leo"}"#.utf8)) }
        #expect(throws: SheetImportError.unsupportedVersion(2)) {
            try SheetDocument.decode(Data(#"{"format": "character-sheet", "version": 2}"#.utf8))
        }
        #expect(throws: SheetImportError.empty) {
            try SheetDocument.decode(Data(#"{"format": "character-sheet", "version": 1, "exportedAt": "2026-11-09T10:00:00Z"}"#.utf8))
        }
        do {
            _ = try SheetDocument.decode(Data(#"{"format": "character-sheet", "version": 1, "exportedAt": "2026-11-09T10:00:00Z", "template": {"name": "T"}}"#.utf8))
            Issue.record("un template incomplet devrait être refusé")
        } catch {
            guard case .invalid(let detail) = error else { Issue.record("\(error)"); return }
            #expect(detail.contains("manquant"))
            #expect(error.errorDescription?.hasPrefix("Fichier illisible") == true)
        }
    }

    @Test("Tolérance : cellules manquantes complétées, colonne de section ramenée dans la rangée")
    func lenientImport() throws {
        let context = try makeContext()
        let (sheet, row, _) = (SheetTemplate.create(name: "T", firstPage: "P", in: context).sheet!, 0, 0)
        let section = sheet.sortedPages[0].sortedRows[row].addSection(title: "Armes", kind: .table, in: context)
        section.addColumn(title: "A", kind: .number, code: "a", in: context)
        section.addColumn(title: "B", kind: .number, code: "b", in: context)
        let group = section.addGroup(title: "", in: context)
        section.addRow(label: "Épée", to: group, in: context).cell(code: "a")?.numberValue = 3

        var record = SheetDocument.SheetRecord(sheet)
        record.pages[0].rows[0].sections[0].groups[0].rows[0].cells.removeLast()
        record.pages[0].rows[0].sections[0].column = 7
        let rebuilt = record.makeSheet(in: context)
        let table = try #require(rebuilt.section(titled: "Armes"))
        let epee = try #require(table.tableRow(label: "Épée"))
        #expect(epee.cells?.count == 2)
        #expect(epee.cell(code: "a")?.numberValue == 3)
        #expect(table.columnIndex == 0)
    }

    @Test("Dates : millisecondes arrondies, relecture stable")
    func dates() throws {
        #expect(SheetDocument.isoString(Date(timeIntervalSince1970: 1_762_720_000.9779)) == "2025-11-09T20:26:40.978Z")
        #expect(SheetDocument.isoString(Date(timeIntervalSince1970: -0.25)) == "1969-12-31T23:59:59.750Z")
        let formatter = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        for milliseconds in stride(from: 0, to: 1000, by: 1) {
            let text = "2026-11-09T20:24:25.\(String(format: "%03d", milliseconds))Z"
            #expect(SheetDocument.isoString(try formatter.parse(text)) == text)
        }
    }

    @Test("Nom de fichier proposé")
    func filename() {
        #expect(SheetDocument(character: PlayerCharacter(name: "Leo")).suggestedFilename == "Leo.json")
        #expect(SheetDocument(template: SheetTemplate(name: "BRP / Cthulhu: v2")).suggestedFilename == "BRP - Cthulhu- v2.json")
        #expect(SheetDocument(template: SheetTemplate(name: "  ")).suggestedFilename == "Fiche.json")
    }
}
