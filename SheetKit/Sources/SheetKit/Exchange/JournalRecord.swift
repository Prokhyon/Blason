import Foundation
import SwiftData

// Journal d'un personnage dans le format d'échange (version 2). Les sessions désignent leurs fiches,
// les documents leur session ou leur fiche, par leur position dans les listes du journal.
// Sessions dans l'ordre chronologique, fiches genre par genre puis par nom, documents du plus ancien
// au plus récent : réexporter un fichier importé donne le même fichier.

extension SheetDocument {
    public struct JournalRecord: Codable, Equatable, Sendable {
        public var sessions: [SessionRecord]
        public var entries: [EntryRecord]
        public var documents: [DocumentRecord]
    }

    public struct SessionRecord: Codable, Equatable, Sendable {
        public var number: Int
        public var date: Date
        public var gameDate: String
        public var title: String
        public var summary: String
        /// Récit mis en forme (JSON d'un `AttributedString`, en base64).
        public var richText: Data?
        public var plainText: String
        public var gains: String
        public var createdAt: Date
        /// Positions des fiches qui apparaissent dans la session.
        public var entries: [Int]
    }

    public struct EntryRecord: Codable, Equatable, Sendable {
        public var name: String
        public var kind: String
        public var summary: String
        public var status: String
        /// Image encodée en base64.
        public var imageData: Data?
        public var createdAt: Date
    }

    public struct DocumentRecord: Codable, Equatable, Sendable {
        public var title: String
        public var contentType: String
        /// Contenu (PDF, image) encodé en base64.
        public var data: Data?
        public var createdAt: Date
        /// Position de la session ou de la fiche de rattachement.
        public var session: Int?
        public var entry: Int?
    }
}

extension SheetDocument.JournalRecord {
    init(_ journal: Journal) {
        let sessions = journal.sortedSessions.reversed().map { $0 }
        let entries = journal.sortedEntries
        let documents = journal.sortedDocuments.reversed().map { $0 }
        func position<T: AnyObject>(_ element: T?, in list: [T]) -> Int? {
            element.flatMap { element in list.firstIndex { $0 === element } }
        }
        self.init(
            sessions: sessions.map { session in
                SheetDocument.SessionRecord(
                    number: session.number, date: session.date, gameDate: session.gameDate, title: session.title,
                    summary: session.summary, richText: session.richText, plainText: session.plainText,
                    gains: session.gains, createdAt: session.createdAt,
                    entries: session.sortedEntries.compactMap { position($0, in: entries) }
                )
            },
            entries: entries.map {
                SheetDocument.EntryRecord(name: $0.name, kind: $0.kindRaw, summary: $0.summary, status: $0.status,
                                          imageData: $0.imageData, createdAt: $0.createdAt)
            },
            documents: documents.map {
                SheetDocument.DocumentRecord(title: $0.title, contentType: $0.contentType, data: $0.data,
                                             createdAt: $0.createdAt, session: position($0.session, in: sessions),
                                             entry: position($0.entry, in: entries))
            }
        )
    }

    func makeJournal(in context: ModelContext) -> Journal {
        let journal = Journal()
        context.insert(journal)
        let entryModels = entries.map { record in
            let entry = CodexEntry(name: record.name)
            context.insert(entry)
            entry.journal = journal
            entry.kindRaw = record.kind
            entry.summary = record.summary
            entry.status = record.status
            entry.imageData = record.imageData
            entry.createdAt = record.createdAt
            return entry
        }
        func entry(at index: Int?) -> CodexEntry? {
            index.flatMap { entryModels.indices.contains($0) ? entryModels[$0] : nil }
        }
        let sessionModels = sessions.map { record in
            let session = JournalSession(number: record.number, date: record.date)
            context.insert(session)
            session.journal = journal
            session.gameDate = record.gameDate
            session.title = record.title
            session.summary = record.summary
            session.richText = record.richText
            session.plainText = record.plainText
            session.gains = record.gains
            session.createdAt = record.createdAt
            session.entries = record.entries.compactMap(entry(at:))
            return session
        }
        for record in documents {
            let document = JournalDocument(title: record.title, contentType: record.contentType)
            context.insert(document)
            document.journal = journal
            document.data = record.data
            document.createdAt = record.createdAt
            document.session = record.session.flatMap { sessionModels.indices.contains($0) ? sessionModels[$0] : nil }
            document.entry = entry(at: record.entry)
        }
        return journal
    }
}
