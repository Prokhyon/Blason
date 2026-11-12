import Foundation
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import SheetKit

@MainActor
@Suite("Journal")
struct JournalTests {

    private func leo(_ context: ModelContext) -> PlayerCharacter {
        DemoData.leo(from: DemoData.brpTemplate(in: context), in: context)
    }

    @Test("Créé à la première ouverture, une seule fois ; un template n'en a pas")
    func creation() throws {
        let context = try makeContext()
        let leo = leo(context)
        #expect(leo.journal == nil)
        let journal = leo.ensureJournal(in: context)
        #expect(leo.ensureJournal(in: context) === journal)
        #expect(journal.character === leo)
        #expect(try EntityCounts(context)["Journal"] == 1)
    }

    @Test("Session du jour : numérotée, et rouverte le même jour plutôt que recréée")
    func todaysSession() throws {
        let context = try makeContext()
        let journal = leo(context).ensureJournal(in: context)
        let calendar = Calendar(identifier: .gregorian)
        let monday = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 20)))
        let (first, created) = journal.todaysSession(now: monday, calendar: calendar, in: context)
        #expect(created && first.number == 1)
        let (again, createdAgain) = journal.todaysSession(now: monday.addingTimeInterval(3600), calendar: calendar, in: context)
        #expect(!createdAgain && again === first)
        first.number = 7
        let (next, _) = journal.todaysSession(now: monday.addingTimeInterval(7 * 86_400), calendar: calendar, in: context)
        #expect(next.number == 8)
        #expect(journal.sortedSessions.map(\.number) == [8, 7])
    }

    @Test("Apparitions : les fiches citées par le récit ; une fiche liste ses sessions")
    func appearances() throws {
        let context = try makeContext()
        let journal = leo(context).ensureJournal(in: context)
        let one = journal.addSession(date: Date(timeIntervalSince1970: 1000), in: context)
        let two = journal.addSession(date: Date(timeIntervalSince1970: 2000), in: context)
        let aldo = journal.addEntry(named: "Aldo", kind: .npc, in: context)
        let phare = journal.addEntry(named: "Phare", kind: .place, in: context)
        typealias Run = JournalText.Run
        one.apply(JournalText(paragraphs: [.init(runs: [
            Run(text: "Phare", reference: phare.uid), Run(text: " puis "), Run(text: "Aldo", reference: aldo.uid),
            Run(text: " et encore "), Run(text: "lui", reference: aldo.uid),
        ])]))
        two.apply(JournalText(paragraphs: [.init(runs: [Run(text: "Aldo", reference: aldo.uid)])]))
        try context.save()
        #expect(one.sortedEntries.map(\.name) == ["Aldo", "Phare"])
        #expect(aldo.sortedSessions.map(\.number) == [2, 1])
        #expect(one.plainText == "Phare puis Aldo et encore lui")
        // Citation effacée : l'apparition disparaît, la fiche reste dans le carnet.
        one.apply(JournalText(plainText: "Phare puis personne"))
        #expect(aldo.sortedSessions.map(\.number) == [2])
        #expect(one.sortedEntries.isEmpty)
        #expect(journal.sortedEntries.map(\.name) == ["Aldo", "Phare"])
        #expect(journal.entries(of: .place).map(\.name) == ["Phare"])
    }

    @Test("Pièces jointes : rattachées à la session du texte ; retirées, un document classé reste, le reste part")
    func attachments() throws {
        let context = try makeContext()
        let journal = leo(context).ensureJournal(in: context)
        let session = journal.addSession(in: context)
        let map = journal.addDocument(title: "Carte", contentType: .pdf, data: Data([1]), in: context)
        let sketch = journal.addDrawing(.sketch, title: "Le phare", data: Data([2]), preview: Data([3]), isListed: false, in: context)
        let notes = journal.addDrawing(.handwriting, title: "", data: Data([4]), preview: nil, isListed: true, in: context)
        #expect(!notes.isListed && notes.kind == .handwriting && sketch.kind == .sketch && map.kind == .pdf)
        session.apply(JournalText(paragraphs: [
            .init(runs: [.attachment(map.uid)]), .init(runs: [.attachment(sketch.uid), .attachment(notes.uid)]),
        ]))
        #expect(map.session === session && sketch.session === session && notes.session === session)
        #expect(session.sortedDocuments.map(\.title) == ["Carte"])
        #expect(journal.listedDocuments.map(\.title) == ["Carte"])
        #expect(session.plainText == "\n")

        session.apply(JournalText(plainText: "Plus rien"))
        #expect(map.session == nil && sketch.session == nil)
        journal.removeUnusedAttachments(in: context)
        try context.save()
        #expect(journal.sortedDocuments.map(\.title) == ["Carte"])
    }

    @Test("Récit : texte brut, citations et pièces jointes sans doublon, fusion des suites, JSON compact")
    func journalText() throws {
        typealias Run = JournalText.Run
        let (a, b, doc) = (UUID(), UUID(), UUID())
        let text = JournalText(paragraphs: [
            .init(style: .title, runs: [Run(text: "Nuit "), Run(text: "au phare"), Run(text: "", bold: true)]),
            .init(list: .checklist, checked: true, runs: [Run(text: "Aldo", reference: a), Run(text: " et "),
                                                          Run(text: "Mereth", reference: b), Run(text: "Aldo", reference: a)]),
            .init(runs: [.attachment(doc), .attachment(doc)]),
        ])
        #expect(text.plainText == "Nuit au phare\nAldo et MerethAldo\n")
        #expect(text.referencedEntries == [a, b])
        #expect(text.attachments == [doc])
        let normalized = text.normalized()
        #expect(normalized.paragraphs[0].runs == [Run(text: "Nuit au phare")])
        #expect(normalized.paragraphs[1].runs.count == 4)
        #expect(normalized.paragraphs[2].runs.count == 2)  // deux pièces jointes ne fusionnent pas
        let data = try #require(normalized.encoded())
        #expect(JournalText.decode(data) == normalized)
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("\"bold\"") && !json.contains("\"body\""))
        #expect(JournalText.decode(Data("{\"texte\":1}".utf8)) == nil)
        #expect(JournalText(plainText: "a\n\nb").paragraphs.map(\.plainText) == ["a", "", "b"])
        #expect(JournalText(plainText: "").isEmpty)
    }

    @Test("Ancien récit en texte brut : relu comme des paragraphes")
    func legacyText() throws {
        let context = try makeContext()
        let session = leo(context).ensureJournal(in: context).addSession(in: context)
        session.plainText = "Ligne 1\nLigne 2"
        session.richText = Data("pas du JSON de récit".utf8)
        #expect(session.text.paragraphs.map(\.plainText) == ["Ligne 1", "Ligne 2"])
    }

    @Test("Supprimer une session garde ses fiches et ses documents ; supprimer le personnage efface le journal")
    func deletion() throws {
        let context = try makeContext()
        let leo = leo(context)
        let journal = try #require(DemoData.addDemoJournal(to: leo, in: context))
        try context.save()
        let counts = try EntityCounts(context)
        #expect(counts["JournalSession"] == 3 && counts["CodexEntry"] == 5 && counts["JournalDocument"] == 1)

        let document = try #require(journal.sortedDocuments.first)
        let session = try #require(document.session)
        context.delete(session)
        try context.save()
        #expect(try EntityCounts(context)["CodexEntry"] == 5)
        #expect(document.session == nil && document.entry != nil)
        #expect(journal.sortedDocuments.count == 1)

        context.delete(leo)
        let after = try EntityCounts(context)
        for key in ["Journal", "JournalSession", "CodexEntry", "JournalDocument"] {
            #expect(after[key] == 0, "\(key)")
        }
    }

    @Test("Dupliquer un personnage ou en faire un template n'emporte pas le journal")
    func copiesLeaveJournal() throws {
        let context = try makeContext()
        let leo = leo(context)
        DemoData.addDemoJournal(to: leo, in: context)
        let copy = leo.duplicate(in: context)
        let template = leo.makeTemplate(named: "Pirates", in: context)
        let fromTemplate = template.makeCharacter(named: "Mira", in: context)
        try context.save()
        #expect(copy.journal == nil && fromTemplate.journal == nil)
        #expect(try EntityCounts(context)["Journal"] == 1)
    }

    @Test("Recherche dans tout le journal, sans majuscules ni accents, mot par mot")
    func search() throws {
        let context = try makeContext()
        let journal = try #require(DemoData.addDemoJournal(to: leo(context), in: context))
        #expect(journal.search("  ").isEmpty)
        let lettre = journal.search("LETTRE scellee")
        #expect(lettre.sessions.map(\.title) == ["La lettre scellée"])
        let phare = journal.search("phare")
        #expect(phare.sessions.map(\.number) == [3, 2])  // titre, récit
        #expect(phare.entries.map(\.name) == ["Capitaine Mereth", "Le phare de Kerlaz", "Sceau à l'étoile brisée"])
        #expect(journal.search("baie").documents.map(\.title) == ["Carte de la baie"])
        #expect(journal.search("thermidor 1792").sessions.count == 3)
        #expect(journal.search("disparue").entries.map(\.name) == ["Capitaine Mereth"])
        #expect(journal.search("zzz").isEmpty)
    }

    @Test("Export : le journal fait l'aller-retour, documents et rattachements compris")
    func exchange() throws {
        let context = try makeContext()
        let leo = leo(context)
        let journal = try #require(DemoData.addDemoJournal(to: leo, in: context))
        let first = try #require(journal.sortedSessions.last)
        journal.sortedEntries.first?.imageData = Data([1, 2, 3])
        let data = try SheetDocument(character: leo, exportedAt: Date(timeIntervalSince1970: 0)).jsonData()

        let other = try makeContext()
        guard case .character(let imported) = try SheetDocument.decode(data).insert(into: other) else {
            Issue.record("pas un personnage"); return
        }
        let copy = try #require(imported.journal)
        #expect(copy.sortedSessions.map(\.title) == journal.sortedSessions.map(\.title))
        #expect(copy.sortedSessions.map { $0.sortedEntries.map(\.name) } == journal.sortedSessions.map { $0.sortedEntries.map(\.name) })
        #expect(copy.sortedSessions.last?.richText == first.richText)
        #expect(copy.sortedEntries.map(\.kind) == journal.sortedEntries.map(\.kind))
        #expect(copy.sortedEntries.first?.imageData == Data([1, 2, 3]))
        let document = try #require(copy.sortedDocuments.first)
        #expect(document.isPDF && document.data == journal.sortedDocuments.first?.data)
        #expect(document.session?.title == "La lettre scellée" && document.entry?.name == "Le phare de Kerlaz")
        // Les citations du récit retrouvent leurs fiches, les pièces jointes leurs documents.
        let second = try #require(copy.sortedSessions.first { $0.number == 2 })
        #expect(second.text.referencedEntries.compactMap(copy.entry(uid:)).map(\.name)
                == ["Capitaine Mereth", "Sceau à l'étoile brisée", "Le phare de Kerlaz"])
        #expect(second.text.attachments.compactMap(copy.document(uid:)).map(\.title) == ["Carte de la baie"])
        #expect(try SheetDocument(character: imported, exportedAt: Date(timeIntervalSince1970: 0)).jsonData() == data)
    }

    @Test("Export : un personnage sans journal n'en a pas après import ; un fichier sans « journal » se lit")
    func exchangeWithoutJournal() throws {
        let context = try makeContext()
        let leo = leo(context)
        let data = try SheetDocument(character: leo).jsonData()
        #expect(!String(decoding: data, as: UTF8.self).contains("\"journal\""))
        guard case .character(let imported) = try SheetDocument.decode(data).insert(into: try makeContext()) else {
            Issue.record("pas un personnage"); return
        }
        #expect(imported.journal == nil)
    }

    @Test("Document : PDF ou image selon le type")
    func documentKind() throws {
        let context = try makeContext()
        let journal = leo(context).ensureJournal(in: context)
        let image = journal.addDocument(title: "Lettre", contentType: .jpeg, data: Data([0]), in: context)
        #expect(!image.isPDF && image.type == .jpeg)
        #expect(journal.addDocument(title: "Plan", contentType: .pdf, data: Data([0]), in: context).isPDF)
    }
}
