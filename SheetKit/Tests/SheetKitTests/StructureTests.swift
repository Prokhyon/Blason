import Foundation
import SwiftData
import Testing
@testable import SheetKit

/// Petite fiche : une page, une rangée de deux colonnes, sections A et B à gauche, C à droite.
@MainActor
private func makeSheet(_ context: ModelContext) -> (Sheet, SheetRow, [SheetSection]) {
    let template = SheetTemplate.create(name: "T", in: context)
    let sheet = template.sheet!
    let row = sheet.addPage(title: "P", in: context).addRow(columnWeights: [1, 1], in: context)
    let a = row.addSection(title: "A", kind: .fields, column: 0, in: context)
    let b = row.addSection(title: "B", kind: .fields, column: 0, in: context)
    let c = row.addSection(title: "C", kind: .fields, column: 1, in: context)
    return (sheet, row, [a, b, c])
}

@MainActor
private func titles(_ sections: [SheetSection]) -> [String] { sections.map(\.title) }

@MainActor
@Suite("Éditeur de structure")
struct StructureTests {

    @Test("Déplacer une section dans une autre colonne renumérote les deux colonnes")
    func moveSectionAcrossColumns() throws {
        let context = try makeContext()
        let (_, row, sections) = makeSheet(context)
        let (a, b, _) = (sections[0], sections[1], sections[2])

        a.move(to: row, column: 1, at: 0)
        #expect(titles(row.sections(inColumn: 0)) == ["B"])
        #expect(titles(row.sections(inColumn: 1)) == ["A", "C"])
        #expect(b.order == 0)

        a.move(to: row, column: 1, at: nil)
        #expect(titles(row.sections(inColumn: 1)) == ["C", "A"])
        #expect(row.sections(inColumn: 1).map(\.order) == [0, 1])
    }

    @Test("Déplacer une section vers une autre rangée")
    func moveSectionAcrossRows() throws {
        let context = try makeContext()
        let (_, row, sections) = makeSheet(context)
        let other = try #require(row.page).addRow(columnWeights: [1, 2, 1], in: context)

        sections[2].move(to: other, column: 2)
        #expect(row.sections(inColumn: 1).isEmpty)
        #expect(titles(other.sections(inColumn: 2)) == ["C"])
        // Colonne hors limites : ramenée à la dernière.
        sections[0].move(to: other, column: 9)
        #expect(titles(other.sections(inColumn: 2)) == ["C", "A"])
    }

    @Test("Réduire le nombre de colonnes regroupe les sections dans la dernière colonne gardée")
    func reduceColumns() throws {
        let context = try makeContext()
        let (_, row, _) = makeSheet(context)
        row.setColumnCount(3)
        #expect(row.columnWeights == [1, 1, 1])

        row.setColumnCount(1)
        #expect(row.columnWeights == [1])
        #expect(titles(row.sections(inColumn: 0)) == ["A", "B", "C"])
        #expect(row.sections(inColumn: 0).map(\.columnIndex) == [0, 0, 0])
    }

    @Test("Supprimer une colonne fusionne avec la voisine et décale les suivantes")
    func removeColumn() throws {
        let context = try makeContext()
        let (_, row, sections) = makeSheet(context)
        row.setColumnCount(3)
        let d = row.addSection(title: "D", kind: .fields, column: 2, in: context)

        row.removeColumn(at: 0)
        #expect(row.columnCount == 2)
        #expect(titles(row.sections(inColumn: 0)) == ["A", "B", "C"])
        #expect(titles(row.sections(inColumn: 1)) == ["D"])
        #expect(d.columnIndex == 1)

        row.removeColumn(at: 1)
        #expect(titles(row.sections(inColumn: 0)) == ["A", "B", "C", "D"])
        _ = sections
    }

    @Test("Insérer un champ après un autre, puis le déplacer")
    func insertAndMoveFields() throws {
        let context = try makeContext()
        let (_, _, sections) = makeSheet(context)
        let a = sections[0]
        let force = a.addField(label: "Force", kind: .integer, code: "FOR", in: context)
        a.addField(label: "Taille", kind: .integer, code: "TAI", in: context)
        a.insertField(label: "Constitution", kind: .integer, after: force, in: context)
        #expect(a.sortedFields.map(\.label) == ["Force", "Constitution", "Taille"])

        force.move(to: sections[1])
        #expect(a.sortedFields.map(\.label) == ["Constitution", "Taille"])
        #expect(a.sortedFields.map(\.order) == [0, 1])
        #expect(sections[1].sortedFields.map(\.label) == ["Force"])
    }

    @Test("Dupliquer un champ le place juste après, avec un code unique")
    func duplicateField() throws {
        let context = try makeContext()
        let (sheet, _, sections) = makeSheet(context)
        let force = sections[0].addField(label: "Force", kind: .integer, code: "FOR", in: context)
        force.numberValue = 11
        sections[0].addField(label: "Taille", kind: .integer, code: "TAI", in: context)

        let copy = try #require(force.duplicate(in: context))
        #expect(sections[0].sortedFields.map(\.code) == ["FOR", "FOR2", "TAI"])
        #expect(copy.numberValue == 11)
        #expect(try #require(copy.duplicate(in: context)).code == "FOR3")
        #expect(sheet.uniqueFieldCode("TAI") == "TAI2")
        #expect(sheet.uniqueFieldCode("") == "")
    }

    @Test("Coller un champ dans un autre template")
    func pasteFieldAcrossTemplates() throws {
        let context = try makeContext()
        let brp = DemoData.brpTemplate(in: context)
        let (other, _, sections) = makeSheet(context)
        sections[0].addField(label: "Force", kind: .integer, code: "FOR", in: context)

        let pv = try #require(brp.sheet?.field(code: "PV"))
        let nom = try #require(brp.sheet?.nameField)
        let pasted = pv.paste(into: sections[0], at: 0, in: context)
        let pastedName = nom.paste(into: sections[0], in: context)
        #expect(pasted.code == "PV")
        #expect(pasted.formula == pv.formula)
        #expect(pasted.kind == .resource)
        #expect(sections[0].sortedFields.map(\.label) == ["Points de vie", "Force", "Nom"])
        // Le champ « nom » garde son rôle s'il n'y en a pas déjà un.
        #expect(pastedName.isNameField)
        #expect(other.nameField === pastedName)
        // Le template d'origine n'a pas changé.
        #expect(brp.sheet?.field(code: "PV") === pv)

        let again = nom.paste(into: sections[1], in: context)
        #expect(!again.isNameField)
    }

    @Test("Dupliquer une section, une rangée, une page")
    func duplicateContainers() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let sheet = try #require(template.sheet)
        let before = try EntityCounts(context)

        let caracs = try #require(sheet.section(titled: "Caractéristiques"))
        let copy = try #require(caracs.duplicate(in: context))
        #expect(copy.title == "Caractéristiques (copie)")
        #expect(copy.row === caracs.row)
        let column = try #require(caracs.row).sections(inColumn: caracs.columnIndex)
        #expect(column.firstIndex { $0 === copy } == column.firstIndex { $0 === caracs }! + 1)
        #expect(copy.sortedFields.first?.code == "FOR2")

        let page = sheet.sortedPages[2]
        let pageCopy = try #require(page.duplicate(in: context))
        #expect(sheet.sortedPages.map(\.title) == ["Personnage", "Compétences", "Combat", "Combat (copie)", "Pouvoirs et notes"])
        #expect(signature(of: sheet).filter { $0.hasPrefix("page") }.count == 5)
        _ = pageCopy

        let row = sheet.sortedPages[0].sortedRows[0]
        _ = try #require(row.duplicate(in: context))
        #expect(sheet.sortedPages[0].sortedRows.count == 2)

        // Coller la première page de BRP dans une autre fiche : le champ « nom » n'est pas dupliqué.
        let (other, _, _) = makeSheet(context)
        sheet.sortedPages[0].paste(into: other, at: 0, in: context)
        sheet.sortedPages[0].paste(into: other, in: context)
        #expect(other.sortedPages.map(\.title) == ["Personnage", "P", "Personnage"])
        #expect(other.allFields.filter(\.isNameField).count == 1)

        // Tous les codes de champ restent uniques dans la fiche.
        let codes = sheet.allFields.map(\.code).filter { !$0.isEmpty }
        #expect(Set(codes.map { $0.uppercased() }).count == codes.count)

        let after = try EntityCounts(context)
        #expect(after["SheetField"] > before["SheetField"])
    }

    @Test("Coller une ligne de tableau dans un autre tableau suit les codes de colonnes")
    func moveRowAcrossTables() throws {
        let context = try makeContext()
        let (_, row, _) = makeSheet(context)
        let skills = row.addSection(title: "Compétences", kind: .table, column: 0, in: context)
        skills.addColumn(title: "Base", kind: .number, code: "base", in: context)
        skills.addColumn(title: "Valeur", kind: .number, code: "valeur", in: context)
        let group = skills.addGroup(title: "G", in: context)
        let line = skills.addRow(label: "Escrime", to: group, in: context)
        line.cell(code: "base")?.numberValue = 5
        line.cell(code: "valeur")?.numberValue = 70

        let combat = row.addSection(title: "Combat", kind: .table, column: 1, in: context)
        combat.addColumn(title: "Valeur", kind: .number, code: "valeur", in: context)
        combat.addColumn(title: "Dégâts", kind: .text, code: "deg", in: context)
        let weapons = combat.addGroup(title: "", in: context)

        let copy = line.paste(into: weapons, in: context)
        #expect(copy.cells?.count == 2)
        #expect(copy.cell(code: "valeur")?.numberValue == 70)
        #expect(copy.cell(code: "deg")?.textValue == nil)

        line.move(to: weapons, at: 0, in: context)
        try context.save()
        #expect(weapons.sortedRows.map(\.label) == ["Escrime", "Escrime"])
        #expect(group.sortedRows.isEmpty)
        #expect(line.cells?.count == 2)
        #expect(line.cell(code: "valeur")?.numberValue == 70)
        #expect(line.cell(code: "base") == nil)
        // Les anciennes cellules ont été supprimées.
        #expect(try context.fetchCount(FetchDescriptor<SheetTableCell>()) == 4)
    }

    @Test("Colonnes et groupes : insérer, déplacer, dupliquer")
    func tableColumnsAndGroups() throws {
        let context = try makeContext()
        let (_, row, _) = makeSheet(context)
        let table = row.addSection(title: "Armes", kind: .table, in: context)
        let valeur = table.addColumn(title: "Valeur", kind: .number, code: "valeur", in: context)
        table.addColumn(title: "Dégâts", kind: .text, code: "deg", in: context)
        let group = table.addGroup(title: "", in: context)
        let sword = table.addRow(label: "Épée", to: group, in: context)
        sword.cell(for: valeur)?.numberValue = 40

        table.insertColumn(title: "Base", kind: .number, code: "valeur", after: nil, in: context)
        #expect(table.sortedColumns.map(\.code) == ["valeur", "deg", "valeur2"])
        table.move(table.sortedColumns[2], to: 0)
        #expect(table.sortedColumns.map(\.title) == ["Base", "Valeur", "Dégâts"])
        #expect(sword.cells?.count == 3)

        let copy = try #require(valeur.duplicate(in: context))
        #expect(table.sortedColumns.map(\.title) == ["Base", "Valeur", "Valeur (copie)", "Dégâts"])
        #expect(sword.cell(for: copy)?.numberValue == 40)

        let groupCopy = try #require(group.duplicate(in: context))
        #expect(groupCopy.sortedRows.map(\.label) == ["Épée"])
        #expect(groupCopy.sortedRows.first?.cell(for: valeur)?.numberValue == 40)
        table.move(groupCopy, to: 0)
        #expect(table.sortedGroups.first === groupCopy)
    }
}

@MainActor
@Suite("Coller une liste")
struct ListImportTests {

    @Test("Découpage : tabulations, points-virgules, groupes, lignes vides")
    func parse() {
        let entries = ListImport.parse("""
        Marchander;5
        # Communication ; 0

        Escrime\t70\t\t
        Langue (…)
        """)
        #expect(entries == [
            ListEntry(label: "Marchander", values: ["5"]),
            ListEntry(label: "Communication", values: ["0"], isGroup: true),
            ListEntry(label: "Escrime", values: ["70"]),
            ListEntry(label: "Langue (…)"),
        ])
    }

    @Test("Nombres et spécialisations")
    func helpers() {
        #expect(ListImport.number(from: "25%") == 25)
        #expect(ListImport.number(from: "1,5") == 1.5)
        #expect(ListImport.number(from: "−3") == -3)
        #expect(ListImport.number(from: "+2") == 2)
        #expect(ListImport.number(from: "1d4") == nil)
        // Séparateurs de milliers, tels que la fiche les affiche (fr_CH : « 1’234 », fr_FR : espace fine).
        // La virgule est toujours décimale (app en français) : « 1,234.5 » (en_US) n’est pas reconnu.
        for locale in ["fr_CH", "fr_FR", "de_CH"] {
            #expect(ListImport.number(from: 1234.5.formatted(.number.locale(Locale(identifier: locale)))) == 1234.5, "\(locale)")
        }
        #expect(ListImport.number(from: "-") == nil)
        #expect(ListImport.splitSpecialization("Monter (Navire)") == ("Monter", "Navire", true))
        #expect(ListImport.splitSpecialization("Art (…)") == ("Art", nil, true))
        #expect(ListImport.splitSpecialization("Art ()") == ("Art", nil, true))
        #expect(ListImport.splitSpecialization("Esquive") == ("Esquive", nil, false))
    }

    @Test("Champs : libellé, valeur, code")
    func importFields() throws {
        let context = try makeContext()
        let (sheet, _, sections) = makeSheet(context)
        let first = sections[0].addField(label: "Nom", kind: .text, in: context)
        sections[0].addField(label: "Notes", kind: .longText, in: context)

        let created = sections[0].importFields(ListImport.parse("""
        Force;11;FOR
        Constitution;12;CON
        Taille;;TAI
        Points de vie;=plafond((CON+TAI)/2);PV
        """), kind: .integer, after: first, in: context)

        #expect(created.count == 4)
        #expect(sections[0].sortedFields.map(\.label) == ["Nom", "Force", "Constitution", "Taille", "Points de vie", "Notes"])
        #expect(sheet.field(code: "FOR")?.numberValue == 11)
        #expect(sheet.field(code: "TAI")?.numberValue == nil)
        #expect(sheet.field(code: "PV")?.formula == "=plafond((CON+TAI)/2)")

        let resources = sections[1].importFields(ListImport.parse("SAN;47/65;FOR"), kind: .resource, in: context)
        #expect(resources[0].numberValue == 47)
        #expect(resources[0].resourceMax == 65)
        #expect(resources[0].isLive)
        #expect(resources[0].code == "FOR2")
    }

    @Test("Tableau : groupes, valeurs par colonne, colonnes formule sautées")
    func importRows() throws {
        let context = try makeContext()
        let (_, row, _) = makeSheet(context)
        let table = row.addSection(title: "Compétences", kind: .table, in: context)
        table.addColumn(title: "Base", kind: .number, code: "base", in: context)
        table.addColumn(title: "Total", kind: .formula, code: "total", in: context)
        table.addColumn(title: "Exp.", kind: .checkbox, code: "exp", in: context)

        let rows = table.importRows(ListImport.parse("""
        Esquive;=DEX*2;x
        # Communication;5
        Marchander;5
        Langue (Latin);=INT
        Art (…);5
        # Manipulation
        Conduite;20
        """), in: context)

        #expect(rows.count == 5)
        #expect(table.sortedGroups.map(\.title) == ["", "Communication", "Manipulation"])
        #expect(table.sortedGroups[1].hasValue)
        #expect(table.sortedGroups[1].numberValue == 5)
        #expect(!table.sortedGroups[2].hasValue)

        let esquive = try #require(table.tableRow(label: "Esquive"))
        #expect(esquive.cell(code: "base")?.formula == "=DEX*2")
        #expect(esquive.cell(code: "exp")?.boolValue == true)

        let langue = try #require(table.tableRow(label: "Langue"))
        #expect(langue.specialization == "Latin")
        #expect(langue.allowsSpecialization)
        #expect(langue.group?.title == "Communication")
        let art = try #require(table.tableRow(label: "Art"))
        #expect(art.specialization == nil && art.allowsSpecialization)
        #expect(table.tableRow(label: "Conduite")?.cell(code: "base")?.numberValue == 20)

        // Coller dans un groupe existant ajoute à la fin de ce groupe.
        let communication = table.sortedGroups[1]
        table.importRows(ListImport.parse("Persuasion;15"), into: communication, in: context)
        #expect(communication.sortedRows.last?.label == "Persuasion")
    }
}
