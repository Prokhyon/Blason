import Foundation
import SwiftData
import UniformTypeIdentifiers

// Journal du personnage (SPEC §5.14) : sessions, carnet (PNJ, lieux, indices…), documents, recherche.
// Le récit d'une session (`JournalText`) cite des fiches et contient des pièces jointes : les apparitions
// de la session et le rattachement des documents s'en déduisent à chaque enregistrement.

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
        addDocument(title: title, contentTypeIdentifier: contentType.identifier, data: data,
                    session: session, entry: entry, in: context)
    }

    /// Ajoute un croquis ou une zone manuscrite (données PaperKit, rendu PNG).
    @discardableResult
    public func addDrawing(_ kind: JournalDocument.Kind, title: String, data: Data?, preview: Data?,
                           isListed: Bool, session: JournalSession? = nil, in context: ModelContext) -> JournalDocument {
        let document = addDocument(title: title, contentTypeIdentifier: kind.contentType, data: data,
                                   session: session, entry: nil, in: context)
        document.previewData = preview
        document.isListed = kind == .handwriting ? false : isListed
        return document
    }

    private func addDocument(title: String, contentTypeIdentifier: String, data: Data?,
                             session: JournalSession?, entry: CodexEntry?, in context: ModelContext) -> JournalDocument {
        let document = JournalDocument(title: title, contentType: contentTypeIdentifier)
        context.insert(document)
        document.data = data
        document.journal = self
        document.session = session
        document.entry = entry
        return document
    }

    public func entry(uid: UUID) -> CodexEntry? {
        (entries ?? []).first { $0.uid == uid }
    }

    public func document(uid: UUID) -> JournalDocument? {
        (documents ?? []).first { $0.uid == uid }
    }

    /// Supprime les pièces jointes qui ne figurent plus dans aucun récit et pas dans la liste des
    /// documents (zone manuscrite effacée, croquis non classé). À appeler en quittant l'éditeur :
    /// tant qu'il est ouvert, « annuler » peut les remettre dans le texte.
    public func removeUnusedAttachments(in context: ModelContext) {
        for document in documents ?? [] where !document.isListed && document.session == nil && document.entry == nil {
            context.delete(document)
        }
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

    /// Documents, du plus récent au plus ancien (pièces jointes non classées comprises).
    public var sortedDocuments: [JournalDocument] {
        (documents ?? []).sorted(by: JournalDocument.newestFirst)
    }

    /// Liste des documents : sans les croquis non classés ni les zones manuscrites.
    public var listedDocuments: [JournalDocument] {
        sortedDocuments.filter(\.isListed)
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
        (documents ?? []).filter(\.isListed).sorted(by: JournalDocument.newestFirst)
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

    /// Récit de la session (un ancien récit en texte brut devient des paragraphes simples).
    public var text: JournalText {
        JournalText.decode(richText) ?? JournalText(plainText: plainText)
    }

    /// Enregistre le récit et en déduit les apparitions (fiches citées) et les documents rattachés
    /// (pièces jointes). Une pièce jointe retirée du texte quitte la session : un document classé
    /// reste dans la liste des documents ; les autres sont supprimés en quittant l'éditeur
    /// (`Journal.removeUnusedAttachments`).
    public func apply(_ text: JournalText) {
        let text = text.normalized()
        let data = text.encoded()
        if data != richText { richText = data }
        let plain = text.plainText
        if plain != plainText { plainText = plain }
        guard let journal else { return }

        let cited = text.referencedEntries.compactMap(journal.entry(uid:))
        if Set(cited.map(\.persistentModelID)) != Set((entries ?? []).map(\.persistentModelID)) {
            entries = cited
        }
        let attached = Set(text.attachments)
        for document in journal.documents ?? [] {
            if attached.contains(document.uid) {
                if document.session !== self { document.session = self }
            } else if document.session === self {
                document.session = nil
            }
        }
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
    /// Nature d'un document du journal.
    public enum Kind: String, Sendable {
        case pdf
        case image
        /// Croquis (PaperKit).
        case sketch
        /// Zone manuscrite (PaperKit) : l'écriture reste de l'encre.
        case handwriting

        /// Types de contenu propres à l'app.
        public static let sketchType = "ch.loristhomas.blason.sketch"
        public static let handwritingType = "ch.loristhomas.blason.handwriting"

        public var contentType: String {
            switch self {
            case .pdf: UTType.pdf.identifier
            case .image: UTType.jpeg.identifier
            case .sketch: Self.sketchType
            case .handwriting: Self.handwritingType
            }
        }
    }

    static func newestFirst(_ a: JournalDocument, _ b: JournalDocument) -> Bool {
        a.createdAt > b.createdAt
    }

    public var type: UTType? { UTType(contentType) }

    public var kind: Kind {
        switch contentType {
        case Kind.sketchType: .sketch
        case Kind.handwritingType: .handwriting
        default: type?.conforms(to: .pdf) == true ? .pdf : .image
        }
    }

    /// PDF (sinon : image, croquis ou zone manuscrite).
    public var isPDF: Bool { kind == .pdf }

    /// Croquis ou zone manuscrite.
    public var isDrawing: Bool { kind == .sketch || kind == .handwriting }
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
            documents: listedDocuments.filter { matches([$0.title]) }
        )
    }
}
