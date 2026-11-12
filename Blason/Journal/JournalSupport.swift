import SwiftUI
import UniformTypeIdentifiers
import SheetKit

// Journal du personnage (SPEC §5.14) : libellés, aperçus, import des documents.

extension CodexKind {
    var title: LocalizedStringKey {
        switch self {
        case .npc: "PNJ"
        case .place: "Lieu"
        case .clue: "Indice"
        case .faction: "Faction"
        case .other: "Autre"
        }
    }

    var pluralTitle: LocalizedStringKey {
        switch self {
        case .npc: "PNJ"
        case .place: "Lieux"
        case .clue: "Indices"
        case .faction: "Factions"
        case .other: "Autres"
        }
    }

    var symbol: String {
        switch self {
        case .npc: "person.fill"
        case .place: "mappin.and.ellipse"
        case .clue: "magnifyingglass"
        case .faction: "flag.fill"
        case .other: "square.dashed"
        }
    }
}

extension JournalSession {
    /// « Session 12 ».
    var numberTitle: String { String(localized: "Session \(number)") }
    var displayTitle: String { title.isEmpty ? numberTitle : title }
}

extension CodexEntry {
    var displayName: String { name.isEmpty ? String(localized: "Sans nom") : name }
}

extension JournalDocument {
    var displayTitle: String { title.isEmpty ? String(localized: "Document sans titre") : title }
}

// MARK: - Aperçus

extension JournalDocument {
    /// Image d'aperçu : première page d'un PDF, l'image, ou le rendu d'un dessin.
    func previewImage(side: CGFloat) -> PlatformImage? {
        switch kind {
        case .pdf: data.flatMap { PDFContent.thumbnail(data: $0, isPDF: true, side: side) }
        case .image: data.flatMap(PlatformImage.init(data:))
        case .sketch, .handwriting: previewData.flatMap(PlatformImage.init(data:))
        }
    }

    /// Contenu à consulter : le PDF, l'image, ou le rendu d'un dessin.
    var viewerData: Data? { isDrawing ? previewData : data }

    var kindTitle: String {
        switch kind {
        case .pdf: String(localized: "PDF")
        case .image: String(localized: "Image")
        case .sketch: String(localized: "Croquis")
        case .handwriting: String(localized: "Écriture manuscrite")
        }
    }

    var kindSymbol: String {
        switch kind {
        case .pdf: "doc.richtext"
        case .image: "photo"
        case .sketch: "scribble"
        case .handwriting: "pencil.and.scribble"
        }
    }
}

// MARK: - Import des documents

/// Document prêt à entrer dans le journal : PDF tel quel, image réduite en JPEG.
nonisolated struct ImportedDocument: Sendable {
    var title: String
    var type: UTType
    var data: Data

    /// Côté le plus long d'une image importée : assez pour lire une carte en zoomant.
    static let imageMaxSide = 3072

    init(title: String, type: UTType, data: Data) {
        self.title = title
        if type.conforms(to: .pdf) {
            self.type = .pdf
            self.data = data
        } else {
            self.type = .jpeg
            self.data = ImageData.downscaled(data, maxSide: Self.imageMaxSide)
        }
    }

    /// Fichier choisi dans Fichiers (accès temporaire au fichier).
    init?(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let type = UTType(filenameExtension: url.pathExtension) ?? .data
        guard type.conforms(to: .pdf) || type.conforms(to: .image) else { return nil }
        self.init(title: url.deletingPathExtension().lastPathComponent, type: type, data: data)
    }

    static let allowedTypes: [UTType] = [.pdf, .image]
}

/// Document déposé par glisser-déposer (Fichiers, Finder, Photos) : PDF ou image.
nonisolated struct DroppedDocument: Transferable {
    let document: ImportedDocument

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .pdf) { received in
            guard let document = ImportedDocument(url: received.file) else { throw CocoaError(.fileReadCorruptFile) }
            return DroppedDocument(document: document)
        }
        DataRepresentation(importedContentType: .image) { data in
            DroppedDocument(document: ImportedDocument(title: String(localized: "Image"), type: .image, data: data))
        }
    }
}
