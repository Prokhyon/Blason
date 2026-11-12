import Foundation

/// Récit d'une session (SPEC §5.14) : paragraphes mis en forme, références aux fiches du carnet,
/// pièces jointes (documents, croquis, zones manuscrites). Format indépendant de la plateforme :
/// l'app le convertit en texte de l'éditeur du système (UIKit ou AppKit) et inversement.
public struct JournalText: Codable, Equatable, Sendable {
    public static let currentVersion = 1
    /// Caractère d'une pièce jointe dans le texte (U+FFFC, comme `NSTextAttachment`).
    public static let attachmentCharacter = "\u{FFFC}"

    public var version: Int = JournalText.currentVersion
    public var paragraphs: [Paragraph]

    public init(paragraphs: [Paragraph] = []) {
        self.paragraphs = paragraphs
    }

    /// Style de paragraphe, comme dans Notes.
    public enum Style: String, Codable, CaseIterable, Sendable {
        case body
        case title
        case heading
        case subheading
        case monospaced
    }

    /// Liste : à puces, ou à cocher.
    public enum List: String, Codable, CaseIterable, Sendable {
        case bullet
        case checklist
    }

    public struct Paragraph: Codable, Equatable, Sendable {
        public var style: Style
        public var list: List?
        /// Case cochée (liste à cocher).
        public var checked: Bool?
        public var runs: [Run]

        public init(style: Style = .body, list: List? = nil, checked: Bool? = nil, runs: [Run] = []) {
            self.style = style
            self.list = list
            self.checked = checked
            self.runs = runs
        }

        public var plainText: String { runs.map(\.plainText).joined() }

        private enum CodingKeys: String, CodingKey { case style, list, checked, runs }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            style = (try? container.decode(Style.self, forKey: .style)) ?? .body
            list = try? container.decodeIfPresent(List.self, forKey: .list)
            checked = try container.decodeIfPresent(Bool.self, forKey: .checked)
            runs = try container.decodeIfPresent([Run].self, forKey: .runs) ?? []
        }

        /// Le style « corps » et les listes absentes ne s'écrivent pas : JSON compact.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if style != .body { try container.encode(style, forKey: .style) }
            try container.encodeIfPresent(list, forKey: .list)
            try container.encodeIfPresent(checked, forKey: .checked)
            if !runs.isEmpty { try container.encode(runs, forKey: .runs) }
        }
    }

    /// Suite de caractères de même mise en forme. Une référence est le nom d'une fiche du carnet ;
    /// une pièce jointe est un seul caractère U+FFFC.
    public struct Run: Codable, Equatable, Sendable {
        public var text: String
        public var bold: Bool
        public var italic: Bool
        public var underline: Bool
        public var strikethrough: Bool
        /// Fiche citée (`CodexEntry.uid`).
        public var reference: UUID?
        /// Pièce jointe (`JournalDocument.uid`).
        public var attachment: UUID?

        public init(text: String, bold: Bool = false, italic: Bool = false, underline: Bool = false,
                    strikethrough: Bool = false, reference: UUID? = nil, attachment: UUID? = nil) {
            self.text = text
            self.bold = bold
            self.italic = italic
            self.underline = underline
            self.strikethrough = strikethrough
            self.reference = reference
            self.attachment = attachment
        }

        public static func attachment(_ uid: UUID) -> Run {
            Run(text: JournalText.attachmentCharacter, attachment: uid)
        }

        /// Même mise en forme (les deux suites peuvent être fusionnées).
        public func hasSameFormat(as other: Run) -> Bool {
            bold == other.bold && italic == other.italic && underline == other.underline
                && strikethrough == other.strikethrough && reference == other.reference
                && attachment == nil && other.attachment == nil
        }

        var plainText: String { attachment == nil ? text : "" }

        private enum CodingKeys: String, CodingKey {
            case text, bold, italic, underline, strikethrough, reference, attachment
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
            bold = try container.decodeIfPresent(Bool.self, forKey: .bold) ?? false
            italic = try container.decodeIfPresent(Bool.self, forKey: .italic) ?? false
            underline = try container.decodeIfPresent(Bool.self, forKey: .underline) ?? false
            strikethrough = try container.decodeIfPresent(Bool.self, forKey: .strikethrough) ?? false
            reference = try container.decodeIfPresent(UUID.self, forKey: .reference)
            attachment = try container.decodeIfPresent(UUID.self, forKey: .attachment)
        }

        /// Les attributs absents valent « non » : seuls ceux qui servent s'écrivent.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(text, forKey: .text)
            if bold { try container.encode(true, forKey: .bold) }
            if italic { try container.encode(true, forKey: .italic) }
            if underline { try container.encode(true, forKey: .underline) }
            if strikethrough { try container.encode(true, forKey: .strikethrough) }
            try container.encodeIfPresent(reference, forKey: .reference)
            try container.encodeIfPresent(attachment, forKey: .attachment)
        }
    }
}

// MARK: - Lecture

extension JournalText {
    /// Texte brut (recherche, export lisible) : un paragraphe par ligne, pièces jointes omises.
    public var plainText: String {
        paragraphs.map(\.plainText).joined(separator: "\n")
    }

    /// Fiches citées, dans l'ordre d'apparition (sans doublon).
    public var referencedEntries: [UUID] {
        var seen = Set<UUID>()
        return paragraphs.flatMap(\.runs).compactMap(\.reference).filter { seen.insert($0).inserted }
    }

    /// Pièces jointes, dans l'ordre d'apparition (sans doublon).
    public var attachments: [UUID] {
        var seen = Set<UUID>()
        return paragraphs.flatMap(\.runs).compactMap(\.attachment).filter { seen.insert($0).inserted }
    }

    public var isEmpty: Bool {
        paragraphs.allSatisfy { $0.runs.allSatisfy { $0.text.isEmpty } && $0.list == nil }
    }

    /// Texte brut découpé en paragraphes de corps (anciens récits, récits d'exemple).
    public init(plainText: String) {
        self.init(paragraphs: plainText.isEmpty ? [] : plainText.components(separatedBy: "\n").map {
            Paragraph(runs: $0.isEmpty ? [] : [Run(text: $0)])
        })
    }

    /// Fusionne les suites voisines de même mise en forme et retire les suites vides.
    public func normalized() -> JournalText {
        var copy = self
        copy.paragraphs = paragraphs.map { paragraph in
            var merged: [Run] = []
            for run in paragraph.runs where !run.text.isEmpty {
                if let last = merged.last, last.hasSameFormat(as: run) {
                    merged[merged.count - 1].text += run.text
                } else {
                    merged.append(run)
                }
            }
            var result = paragraph
            result.runs = merged
            return result
        }
        return copy
    }

    // MARK: Encodage

    public func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(self)
    }

    /// Récit enregistré ; nil si les données ne sont pas un `JournalText` (ancien format, données abîmées).
    public static func decode(_ data: Data?) -> JournalText? {
        guard let data, let text = try? JSONDecoder().decode(JournalText.self, from: data),
              text.version <= currentVersion else { return nil }
        return text
    }
}
