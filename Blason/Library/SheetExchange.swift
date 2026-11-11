import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import SheetKit

/// Fichier JSON à partager (Fichiers, AirDrop, Mail…), écrit au moment du partage.
struct SheetExportFile: Transferable {
    let document: SheetDocument

    init(template: SheetTemplate) {
        document = SheetDocument(template: template)
    }

    init(character: PlayerCharacter) {
        document = SheetDocument(character: character)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("Export-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(file.document.suggestedFilename)
            try file.document.jsonData().write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

/// Bouton « Exporter… » : feuille de partage avec le fichier JSON.
struct ExportButton: View {
    let file: SheetExportFile

    var body: some View {
        ShareLink(item: file, preview: SharePreview(file.document.title)) {
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
