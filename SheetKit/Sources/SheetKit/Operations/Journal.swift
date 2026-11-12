import Foundation
import SwiftData
import UniformTypeIdentifiers

// Journal du personnage (SPEC §5.14) : sessions, fiches (PNJ, lieux, indices…), documents, recherche.
// Le texte riche des sessions est encodé par l'app (attributs SwiftUI) : SheetKit le garde tel quel,
// avec sa version en texte brut pour la recherche.

// MARK: - Création

extension PlayerCharacter {
    /// Journal du personnage, créé s'il n'existe pas encore.
    @discardableResult
    public func ensureJournal(in context: ModelContext) -> Journal {
        if let journal { return journal }
        let journal = Journal()
        context.insert(journal)
        self.journal = journal
        return journal
    }
}

extension Journal {
    /// Numéro proposé pour une nouvelle session : le plus grand + 1.
    public var nextSessionNumber: Int {
        ((sessions ?? []).map(\.number).max() ?? 0) + 1
    }

    /// Session de ce jour (date réelle), s'il y en a une.
    public func session(on day: Date, calendar: Calendar = .current) -> JournalSession? {
        sortedSessions.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// « Session du jour » : celle d'aujourd'hui si elle existe, sinon une nouvelle, numérotée.
    public func todaysSession(now: Date = Date(), calendar: Calendar = .current,
                              in context: ModelContext) -> (session: JournalSession, created: Bool) {
        if let existing = session(on: now, calendar: calendar) { return (existing, false) }
        return (addSession(date: now, in: context), true)
    }

    @discardableResult
    public func addSession(date: Date = Date(), in context: ModelContext) -> JournalSession {
        let session = JournalSession(number: nextSessionNumber, date: date)
        context.insert(session)
        session.journal = self
        return session
    }

    @discardableResult
    public func addEntry(named name: String = "", kind: CodexKind, in context: ModelContext) -> CodexEntry {
        let entry = CodexEntry(name: name, kind: kind)
        context.insert(entry)
        entry.journal = self
        return entry
    }

    /// Ajoute un document (PDF, image), rattaché ou non à une session ou à une fiche.
    @discardableResult
    public func addDocument(title: String, contentType: UTType, data: Data,
                            session: JournalSession? = nil, entry: CodexEntry? = nil,
                            in context: ModelContext) -> JournalDocument {
        let document = JournalDocument(title: title, contentType: contentType.identifier)
        context.insert(document)
        document.data = data
        document.journal = self
        document.session = session
        document.entry = entry
        return document
    }
}

// MARK: - Listes triées

extension Journal {
    /// Sessions, de la plus récente à la plus ancienne.
    public var sortedSessions: [JournalSession] {
        (sessions ?? []).sorted(by: JournalSession.newestFirst)
    }

    /// Fiches d'un genre, par nom.
    public func entries(of kind: CodexKind) -> [CodexEntry] {
        (entries ?? []).filter { $0.kind == kind }.sorted(by: CodexEntry.byName)
    }

    /// Toutes les fiches, genre par genre puis par nom.
    public var sortedEntries: [CodexEntry] {
        CodexKind.allCases.flatMap(entries(of:))
    }

    /// Documents, du plus récent au plus ancien.
    public var sortedDocuments: [JournalDocument] {
        (documents ?? []).sorted(by: JournalDocument.newestFirst)
    }

    public var isEmpty: Bool {
        (sessions ?? []).isEmpty && (entries ?? []).isEmpty && (documents ?? []).isEmpty
    }
}

extension JournalSession {
    static func newestFirst(_ a: JournalSession, _ b: JournalSession) -> Bool {
        if a.date != b.date { return a.date > b.date }
        if a.number != b.number { return a.number > b.number }
        return a.createdAt > b.createdAt
    }

    /// Fiches qui apparaissent dans la session, genre par genre puis par nom.
    public var sortedEntries: [CodexEntry] {
        (entries ?? []).sorted(by: CodexEntry.byKindThenName)
    }

    public var sortedDocuments: [JournalDocument] {
        (documents ?? []).sorted(by: JournalDocument.newestFirst)
    }

    /// La fiche apparaît dans la session.
    public func contains(_ entry: CodexEntry) -> Bool {
        (entries ?? []).contains { $0 === entry }
    }

    /// Ajoute ou retire une fiche des apparitions de la session.
    public func setAppears(_ entry: CodexEntry, _ appears: Bool) {
        if appears {
            guard !contains(entry) else { return }
            entries = (entries ?? []) + [entry]
        } else {
            entries = (entries ?? []).filter { $0 !== entry }
        }
    }

    /// Enregistre le récit : texte riche encodé par l'app et sa version brute.
    public func setText(richText: Data?, plainText: String) {
        self.richText = richText
        self.plainText = plainText
    }
}

extension CodexEntry {
    public var kind: CodexKind {
        get { CodexKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }

    /// Sessions où la fiche apparaît, de la plus récente à la plus ancienne.
    public var sortedSessions: [JournalSession] {
        (sessions ?? []).sorted(by: JournalSession.newestFirst)
    }

    public var sortedDocuments: [JournalDocument] {
        (documents ?? []).sorted(by: JournalDocument.newestFirst)
    }

    static func byName(_ a: CodexEntry, _ b: CodexEntry) -> Bool {
        let order = a.name.localizedStandardCompare(b.name)
        return order == .orderedSame ? a.createdAt < b.createdAt : order == .orderedAscending
    }

    static func byKindThenName(_ a: CodexEntry, _ b: CodexEntry) -> Bool {
        let (ka, kb) = (CodexKind.allCases.firstIndex(of: a.kind) ?? 0, CodexKind.allCases.firstIndex(of: b.kind) ?? 0)
        return ka == kb ? byName(a, b) : ka < kb
    }
}

extension JournalDocument {
    static func newestFirst(_ a: JournalDocument, _ b: JournalDocument) -> Bool {
        a.createdAt > b.createdAt
    }

    public var type: UTType? { UTType(contentType) }

    /// PDF (sinon : image).
    public var isPDF: Bool { type?.conforms(to: .pdf) == true }
}

// MARK: - Recherche

/// Résultats d'une recherche dans le journal.
public struct JournalSearchResults {
    public var sessions: [JournalSession] = []
    public var entries: [CodexEntry] = []
    public var documents: [JournalDocument] = []

    public var isEmpty: Bool { sessions.isEmpty && entries.isEmpty && documents.isEmpty }
}

extension Journal {
    /// Recherche dans tout le journal, sans tenir compte des majuscules ni des accents : chaque mot
    /// doit se trouver quelque part dans l'élément (titre, résumé, récit, gains, date en jeu ; nom,
    /// état, description ; titre d'un document).
    public func search(_ query: String) -> JournalSearchResults {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return JournalSearchResults() }
        func matches(_ texts: [String]) -> Bool {
            words.allSatisfy { word in
                texts.contains { $0.range(of: word, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
            }
        }
        return JournalSearchResults(
            sessions: sortedSessions.filter {
                matches([$0.title, $0.summary, $0.plainText, $0.gains, $0.gameDate, "\($0.number)"])
            },
            entries: sortedEntries.filter { matches([$0.name, $0.status, $0.summary]) },
            documents: sortedDocuments.filter { matches([$0.title]) }
        )
    }
}
