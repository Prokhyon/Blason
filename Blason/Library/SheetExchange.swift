import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import SheetKit

/// Fichier JSON à partager (Fichiers, AirDrop, Mail…), écrit au moment du partage.
///
/// Le document est construit au moment de partager, pas à l'affichage : le menu contextuel de chaque
/// carte de la bibliothèque le construisait à chaque affichage de la grille, ce qui lisait toute la
/// fiche (la bibliothèque se redessinait alors à chaque frappe dans une fiche ouverte).
struct SheetExportFile: Transferable, @unchecked Sendable {
    /// Titre de l'aperçu de partage.
    let title: String
    private let makeDocument: @MainActor () -> SheetDocument

    init(template: SheetTemplate) {
        title = template.name
        // Modèle SwiftData lu sur le fil principal seulement (makeDocument est @MainActor).
        nonisolated(unsafe) let template = template
        makeDocument = { SheetDocument(template: template) }
    }

    init(character: PlayerCharacter) {
        title = character.displayName
        nonisolated(unsafe) let character = character
        makeDocument = { SheetDocument(character: character) }
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            let document = await file.makeDocument()
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("Export-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(document.suggestedFilename)
            try document.jsonData().write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// Bouton « Exporter… » : feuille de partage avec le fichier JSON.
struct ExportButton: View {
    let file: SheetExportFile

    var body: some View {
        ShareLink(item: file, preview: SharePreview(file.title)) {
            Label("Exporter…", systemImage: "square.and.arrow.up")
        }
    }
}

extension View {
    /// Import de fichiers JSON (templates ou personnages). `onImported` reçoit l'élément créé
    /// quand un seul fichier est importé, pour l'ouvrir.
    func sheetImporter(isPresented: Binding<Bool>, onImported: @escaping (ImportedItem) -> Void) -> some View {
        modifier(SheetImporterModifier(isPresented: isPresented, onImported: onImported))
    }
}

private struct SheetImporterModifier: ViewModifier {
    @Binding var isPresented: Bool
    let onImported: (ImportedItem) -> Void

    @Environment(\.modelContext) private var context
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $isPresented, allowedContentTypes: [.json], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): importFiles(urls)
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
            .alert("Import impossible", isPresented: Blason.isPresented($errorMessage)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private func importFiles(_ urls: [URL]) {
        var imported: [ImportedItem] = []
        var failures: [String] = []
        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                imported.append(try SheetDocument.decode(data).insert(into: context))
            } catch {
                failures.append("\(url.lastPathComponent) : \(error.localizedDescription)")
            }
        }
        if !failures.isEmpty {
            errorMessage = failures.joined(separator: "\n")
        }
        if imported.count == 1, failures.isEmpty, let item = imported.first {
            onImported(item)
        }
    }
}
