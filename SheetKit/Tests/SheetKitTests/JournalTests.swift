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

    @Test("Apparitions : une fiche liste ses sessions, une session ses fiches")
    func appearances() throws {
        let context = try makeContext()
        let journal = leo(context).ensureJournal(in: context)
        let one = journal.addSession(date: Date(timeIntervalSince1970: 1000), in: context)
        let two = journal.addSession(date: Date(timeIntervalSince1970: 2000), in: context)
        let aldo = journal.addEntry(named: "Aldo", kind: .npc, in: context)
        let phare = journal.addEntry(named: "Phare", kind: .place, in: context)
        one.setAppears(phare, true)
        one.setAppears(aldo, true)
        one.setAppears(aldo, true)
        two.setAppears(aldo, true)
        try context.save()
        #expect(one.sortedEntries.map(\.name) == ["Aldo", "Phare"])
        #expect(aldo.sortedSessions.map(\.number) == [2, 1])
        one.setAppears(aldo, false)
        #expect(aldo.sortedSessions.map(\.number) == [2])
        #expect(journal.sortedEntries.map(\.name) == ["Aldo", "Phare"])
        #expect(journal.entries(of: .place).map(\.name) == ["Phare"])
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
        first.richText = Data("{\"texte\":1}".utf8)
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
