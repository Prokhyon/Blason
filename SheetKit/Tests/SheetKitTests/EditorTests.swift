import Foundation
import SwiftData
import Testing
@testable import SheetKit

/// Template vide (une page, une rangée), son éditeur, et la rangée.
@MainActor
private func makeEditor(_ context: ModelContext, name: String = "T") -> (StructureEditor, SheetRow) {
    let template = SheetTemplate.create(name: name, firstPage: "Fiche", in: context)
    let editor = StructureEditor(sheet: template.sheet)
    let row = editor.currentPage!.sortedRows[0]
    return (editor, row)
}

@MainActor
@Suite("Éditeur : sélection, presse-papiers, glisser-déposer")
struct EditorTests {

    @Test("Ajouter un champ le sélectionne ; Entrée enchaîne un champ du même type juste après")
    func chainedFields() throws {
        let context = try makeContext()
        let (editor, row) = makeEditor(context)
        editor.addSection(.fields, to: row, column: 0)
        guard case .section(let section) = editor.primary else { Issue.record("section non sélectionnée"); return }
        #expect(editor.focusLabel == .section(section))

        editor.addField(.integer, to: section)
        guard case .field(let force) = editor.primary else { Issue.record("champ non sélectionné"); return }
        force.label = "Force"
        editor.addNext(after: .field(force))
        guard case .field(let con) = editor.primary else { Issue.record("champ suivant non sélectionné"); return }
        con.label = "Constitution"
        #expect(con.kind == .integer)
        #expect(editor.focusLabel == .field(con))

        // Un nouveau champ s'insère après le champ sélectionné.
        editor.select(.field(force))
        editor.addField(.text, to: section)
        #expect(section.sortedFields.map(\.label) == ["Force", "", "Constitution"])
    }

    @Test("Un tableau neuf a une colonne et un groupe ; Entrée enchaîne les lignes")
    func newTable() throws {
        let context = try makeContext()
        let (editor, row) = makeEditor(context)
        editor.addSection(.table, to: row, column: 0)
        guard case .section(let table) = editor.primary else { Issue.record("tableau non sélectionné"); return }
        #expect(table.sortedColumns.map(\.code) == ["valeur"])
        let group = try #require(table.sortedGroups.first)

        editor.addTableRow(to: group)
        guard case .tableRow(let first) = editor.primary else { Issue.record("ligne non sélectionnée"); return }
        first.label = "Esquive"
        editor.addNext(after: .tableRow(first))
        guard case .tableRow(let second) = editor.primary else { Issue.record("ligne suivante non sélectionnée"); return }
        second.label = "Escrime"
        editor.select(.tableRow(first))
        editor.addTableRow(to: group)
        #expect(group.sortedRows.map(\.label) == ["Esquive", "", "Escrime"])
        #expect(group.sortedRows.allSatisfy { $0.cells?.count == 1 })
    }

    @Test("Copier des champs d'un template et les coller dans un autre, après le champ sélectionné")
    func copyPasteAcrossTemplates() throws {
        let context = try makeContext()
        let brp = DemoData.brpTemplate(in: context)
        let source = StructureEditor(sheet: brp.sheet)
        let sheet = try #require(brp.sheet)
        source.select(.field(try #require(sheet.field(code: "FOR"))))
        source.select(.field(try #require(sheet.field(code: "CON"))), extending: true)
        source.copy()
        #expect(source.clipboard.items.count == 2)

        let (editor, row) = makeEditor(context, name: "Autre")
        let section = row.addSection(title: "Caracs", kind: .fields, in: context)
        let first = section.addField(label: "Nom", kind: .text, in: context)
        section.addField(label: "Notes", kind: .longText, in: context)

        editor.select(.field(first))
        #expect(editor.canPaste)
        editor.paste()
        #expect(section.sortedFields.map(\.label) == ["Nom", "FOR", "CON", "Notes"])
        #expect(editor.selection.count == 2)

        // Coller encore : les codes deviennent uniques dans cette fiche.
        editor.paste()
        #expect(section.sortedFields.map(\.code).filter { !$0.isEmpty } == ["FOR", "CON", "FOR2", "CON2"])

        // Des champs ne se collent pas dans un tableau.
        let table = row.addSection(title: "Tableau", kind: .table, in: context)
        editor.select(.section(table))
        editor.paste()
        #expect(editor.notice != nil)
        #expect(table.fields?.isEmpty == true)
    }

    @Test("Coller une section : après la section sélectionnée, ou dans la page sélectionnée")
    func pasteSections() throws {
        let context = try makeContext()
        let brp = DemoData.brpTemplate(in: context)
        let source = StructureEditor(sheet: brp.sheet)
        source.select(.section(try #require(brp.sheet?.section(titled: "Points de vie"))))
        source.copy()

        let (editor, row) = makeEditor(context, name: "Autre")
        let a = row.addSection(title: "A", kind: .fields, in: context)
        row.addSection(title: "B", kind: .fields, in: context)
        editor.select(.section(a))
        editor.paste()
        #expect(row.sections(inColumn: 0).map(\.title) == ["A", "Points de vie", "B"])

        let page = try #require(editor.currentPage)
        editor.select(.page(page))
        editor.paste()
        #expect(row.sections(inColumn: 0).last?.title == "Points de vie")
        #expect(editor.sheet?.field(code: "PV2") != nil)
    }

    @Test("Dupliquer et supprimer une sélection multiple")
    func duplicateAndDeleteSelection() throws {
        let context = try makeContext()
        let (editor, row) = makeEditor(context)
        let section = row.addSection(title: "S", kind: .fields, in: context)
        let a = section.addField(label: "A", kind: .integer, code: "A", in: context)
        let b = section.addField(label: "B", kind: .integer, code: "B", in: context)

        editor.select(.field(a))
        editor.select(.field(b), extending: true)
        editor.duplicate()
        #expect(section.sortedFields.map(\.label) == ["A", "A", "B", "B"])
        #expect(editor.selection.count == 2)

        editor.delete()
        try context.save()
        #expect(section.sortedFields.map(\.code) == ["A", "B"])
        #expect(editor.selection.isEmpty)

        // ⌘-toucher un élément sélectionné le retire.
        editor.select(.field(a))
        editor.select(.field(a), extending: true)
        #expect(editor.selection.isEmpty)
    }

    @Test("Un élément supprimé disparaît de la sélection et du presse-papiers")
    func deletedItemsAreIgnored() throws {
        let context = try makeContext()
        let (editor, row) = makeEditor(context)
        let section = row.addSection(title: "S", kind: .fields, in: context)
        let field = section.addField(label: "A", kind: .integer, in: context)
        editor.select(.field(field))
        editor.copy()

        context.delete(section)
        try context.save()
        #expect(editor.primary == nil)
        #expect(!editor.canPaste)
    }

    @Test("Glisser un champ sur un champ d'une autre section, une section sur un champ")
    func dragAndDrop() throws {
        let context = try makeContext()
        let (editor, row) = makeEditor(context)
        row.setColumnCount(2)
        let left = row.addSection(title: "Gauche", kind: .fields, column: 0, in: context)
        let right = row.addSection(title: "Droite", kind: .fields, column: 1, in: context)
        let force = left.addField(label: "Force", kind: .integer, in: context)
        let dex = right.addField(label: "DEX", kind: .integer, in: context)
        let pou = right.addField(label: "POU", kind: .integer, in: context)
        pou.listIndex = 1

        _ = editor.beginDrag(.field(force))
        #expect(editor.drop(onto: .field(pou)))
        #expect(right.sortedFields.map(\.label) == ["DEX", "Force", "POU"])
        #expect(force.listIndex == 1)
        #expect(left.sortedFields.isEmpty)
        #expect(editor.primary == .field(force))

        // Vers le bas dans la même liste : prend la place de la cible.
        _ = editor.beginDrag(.field(dex))
        #expect(editor.drop(onto: .field(pou)))
        #expect(right.sortedFields.map(\.label) == ["Force", "POU", "DEX"])

        // Une section lâchée sur un champ remonte à la section qui le contient.
        _ = editor.beginDrag(.section(left))
        #expect(editor.drop(onto: .field(force)))
        #expect(row.sections(inColumn: 1).map(\.title) == ["Gauche", "Droite"])

        // Bas de colonne.
        _ = editor.beginDrag(.section(right))
        #expect(editor.dropSection(into: row, column: 0))
        #expect(row.sections(inColumn: 0).map(\.title) == ["Droite"])

        // Sans glisser en cours, ou sur soi-même : refusé.
        #expect(!editor.drop(onto: .field(force)))
        _ = editor.beginDrag(.field(force))
        #expect(!editor.drop(onto: .field(force)))

        // Un champ ne va pas dans un tableau.
        let table = row.addSection(title: "T", kind: .table, in: context)
        _ = editor.beginDrag(.field(force))
        #expect(!editor.drop(onto: .section(table)))
    }

    @Test("Glisser des lignes, colonnes et groupes de tableau")
    func dragTableParts() throws {
        let context = try makeContext()
        let (editor, row) = makeEditor(context)
        let table = row.addSection(title: "T", kind: .table, in: context)
        let base = table.addColumn(title: "Base", kind: .number, code: "base", in: context)
        let exp = table.addColumn(title: "Exp.", kind: .checkbox, code: "exp", in: context)
        let g1 = table.addGroup(title: "G1", in: context)
        let g2 = table.addGroup(title: "G2", in: context)
        let a = table.addRow(label: "A", to: g1, in: context)
        table.addRow(label: "B", to: g2, in: context)

        _ = editor.beginDrag(.tableRow(a))
        #expect(editor.drop(onto: .group(g2)))
        #expect(g2.sortedRows.map(\.label) == ["B", "A"])

        _ = editor.beginDrag(.column(exp))
        #expect(editor.drop(onto: .column(base)))
        #expect(table.sortedColumns.map(\.title) == ["Exp.", "Base"])

        // Un groupe lâché sur l'une de ses lignes : refusé ; sur une ligne d'un autre groupe : prend sa place.
        _ = editor.beginDrag(.group(g2))
        #expect(!editor.drop(onto: .tableRow(a)))
        let c = table.addRow(label: "C", to: g1, in: context)
        _ = editor.beginDrag(.group(g2))
        #expect(editor.drop(onto: .tableRow(c)))
        #expect(table.sortedGroups.map(\.title) == ["G2", "G1"])
    }

    @Test("Monter, descendre ; les bornes sont respectées")
    func moveByDelta() throws {
        let context = try makeContext()
        let (editor, row) = makeEditor(context)
        let section = row.addSection(title: "S", kind: .fields, in: context)
        let a = section.addField(label: "A", kind: .integer, in: context)
        let b = section.addField(label: "B", kind: .integer, in: context)

        #expect(!editor.canMove(.field(a), by: -1))
        #expect(editor.canMove(.field(a), by: 1))
        editor.move(.field(a), by: 1)
        #expect(section.sortedFields.map(\.label) == ["B", "A"])
        editor.move(.field(a), by: 1)
        #expect(section.sortedFields.map(\.label) == ["B", "A"])
        _ = b

        editor.addPage()
        let pages = try #require(editor.sheet).sortedPages
        #expect(pages.count == 2)
        #expect(editor.pageIndex == 1)
        editor.move(.page(pages[1]), by: -1)
        #expect(editor.pageIndex == 0)
        #expect(try #require(editor.sheet).sortedPages.first === pages[1])
    }

    @Test("Coller une liste dans la section ou le groupe sélectionnés")
    func pasteList() throws {
        let context = try makeContext()
        let (editor, row) = makeEditor(context)
        let section = row.addSection(title: "S", kind: .fields, in: context)
        let nom = section.addField(label: "Nom", kind: .text, in: context)
        section.addField(label: "Fin", kind: .text, in: context)

        editor.select(.field(nom))
        editor.requestPasteList(into: section)
        let request = try #require(editor.pasteList)
        editor.importList("Force;11;FOR\nTaille;15;TAI", request: request, kind: .integer)
        #expect(section.sortedFields.map(\.label) == ["Nom", "Force", "Taille", "Fin"])
        #expect(editor.selection.count == 2)

        let table = row.addSection(title: "T", kind: .table, in: context)
        table.addColumn(title: "Base", kind: .number, code: "base", in: context)
        let g1 = table.addGroup(title: "G1", in: context)
        let g2 = table.addGroup(title: "G2", in: context)
        editor.select(.group(g2))
        editor.requestPasteList(into: table)
        let rows = try #require(editor.pasteList)
        editor.importList("Esquive;=DEX*2\nGrimper;40", request: rows, kind: .integer)
        #expect(g2.sortedRows.map(\.label) == ["Esquive", "Grimper"])
        #expect(g1.sortedRows.isEmpty)
    }

    @Test("Annuler retire un ajout, Rétablir le remet")
    func undoRedo() throws {
        let context = try makeContext()
        let undo = UndoManager()
        undo.groupsByEvent = false
        context.undoManager = undo
        let (editor, row) = makeEditor(context)
        try context.save()

        undo.beginUndoGrouping()
        editor.addSection(.fields, to: row, column: 0)
        context.processPendingChanges()
        undo.endUndoGrouping()
        #expect(row.sections?.count == 1)

        undo.undo()
        #expect(row.sections?.isEmpty == true)
        #expect(editor.primary == nil)
        undo.redo()
        #expect(row.sections?.count == 1)
    }
}
