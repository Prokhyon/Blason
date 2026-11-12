import SwiftUI
import PhotosUI
import SwiftData
import UniformTypeIdentifiers
import SheetKit

/// Document du journal : aperçu, titre, rattachement à une session ou à une fiche, consultation.
struct JournalDocumentView: View {
    @Bindable var document: JournalDocument
    let journal: Journal
    let onDelete: () -> Void

    @State private var viewing: JournalDocument?
    @State private var confirmingDelete = false
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                Button {
                    viewing = document
                } label: {
                    DocumentPreview(document: document)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ouvrir \(document.displayTitle)")
                Button("Ouvrir", systemImage: "arrow.up.left.and.arrow.down.right") {
                    viewing = document
                }
            }
            Section {
                TextField("Titre", text: $document.title, prompt: Text("Titre du document"))
                    .font(.title3.weight(.semibold))
                LabeledContent("Ajouté le", value: document.createdAt.formatted(date: .abbreviated, time: .omitted))
            }
            Section {
                Picker("Session", selection: $document.session) {
                    Text("Aucune").tag(JournalSession?.none)
                    ForEach(journal.sortedSessions) { session in
                        Text("\(session.numberTitle) · \(session.title)").tag(Optional(session))
                    }
                }
                Picker("Fiche", selection: $document.entry) {
                    Text("Aucune").tag(CodexEntry?.none)
                    ForEach(journal.sortedEntries) { entry in
                        Label(entry.displayName, systemImage: entry.kind.symbol).tag(Optional(entry))
                    }
                }
            } header: {
                Text("Rattachement")
            }
            Section {
                Button("Supprimer le document", systemImage: "trash", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .formStyle(.grouped)
        .documentViewer(item: $viewing)
        #if DEBUG
        .task {
            if UserDefaults.standard.bool(forKey: "demoViewer") { viewing = document }
        }
        #endif
        .confirmationDialog("Supprimer « \(document.displayTitle) » ?", isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                let deleted = document
                onDelete()
                context.delete(deleted)
            }
        }
    }
}

/// Ligne d'un document : vignette, titre, genre (et rattachement).
struct DocumentRow: View {
    let document: JournalDocument
    var showsAttachment = false

    var body: some View {
        HStack(spacing: 10) {
            DocumentThumbnail(document: document, side: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(document.displayTitle)
                    .lineLimit(2)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var detail: String {
        var parts = [document.isPDF ? String(localized: "PDF") : String(localized: "Image")]
        if showsAttachment {
            if let session = document.session { parts.append(session.numberTitle) }
            if let entry = document.entry { parts.append(entry.displayName) }
        }
        return parts.joined(separator: " · ")
    }
}

/// Vignette d'un document (première page d'un PDF, ou l'image), calculée une fois.
struct DocumentThumbnail: View {
    let document: JournalDocument
    let side: CGFloat

    @State private var image: PlatformImage?

    var body: some View {
        Group {
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: document.isPDF ? "doc.richtext" : "photo")
                    .font(.system(size: side * 0.42))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.tertiaryFill)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
        .accessibilityHidden(true)
        .task(id: document.persistentModelID) {
            guard let data = document.data else { return }
            image = PDFContent.thumbnail(data: data, isPDF: document.isPDF, side: side * 3)
        }
    }
}

/// Grand aperçu d'un document dans sa page.
struct DocumentPreview: View {
    let document: JournalDocument

    @State private var image: PlatformImage?
    @State private var pages = 0

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let image {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: document.isPDF ? "doc.richtext" : "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 140)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 260)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            if document.isPDF, pages > 0 {
                Text("^[\(pages) page](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: document.persistentModelID) {
            guard let data = document.data else { return }
            image = PDFContent.thumbnail(data: data, isPDF: document.isPDF, side: 900)
            pages = PDFContent.pageCount(data: data, isPDF: document.isPDF)
        }
    }
}

/// Ajouter un document au journal (rattaché à la session ou à la fiche, s'il y en a une) :
/// depuis Fichiers ou Photos.
struct DocumentAddMenu: View {
    let journal: Journal
    var session: JournalSession?
    var entry: CodexEntry?

    @State private var importingFiles = false
    @State private var choosingPhotos = false
    @State private var photos: [PhotosPickerItem] = []
    @State private var failed = false
    @Environment(\.modelContext) private var context
    @Environment(\.journalNavigator) private var navigator

    var body: some View {
        Menu {
            Button("Depuis Fichiers…", systemImage: "folder") { importingFiles = true }
            Button("Depuis Photos…", systemImage: "photo.on.rectangle") { choosingPhotos = true }
        } label: {
            Label("Ajouter un document", systemImage: "doc.badge.plus")
        }
        .fileImporter(isPresented: $importingFiles, allowedContentTypes: ImportedDocument.allowedTypes,
                      allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            let documents = urls.compactMap(ImportedDocument.init(url:))
            failed = documents.count < urls.count
            add(documents)
        }
        .photosPicker(isPresented: $choosingPhotos, selection: $photos, matching: .images)
        .onChange(of: photos) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var documents: [ImportedDocument] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        documents.append(ImportedDocument(title: String(localized: "Image"), type: .image, data: data))
                    }
                }
                photos = []
                add(documents)
            }
        }
        .alert("Certains fichiers n'ont pas pu être lus.", isPresented: $failed) {
            Button("OK") {}
        } message: {
            Text("Le journal accepte les PDF et les images.")
        }
    }

    private func add(_ documents: [ImportedDocument]) {
        let added = documents.map {
            journal.addDocument(title: $0.title, contentType: $0.type, data: $0.data, session: session, entry: entry,
                                in: context)
        }
        // Un seul document, depuis la liste des documents : on l'ouvre pour lui donner un titre.
        if added.count == 1, session == nil, entry == nil, let document = added.first {
            navigator?.open(.document(document))
        }
    }
}

// MARK: - Consultation

/// Consultation d'un document : PDF paginé, image zoomable (PDFKit dans les deux cas).
struct DocumentViewer: View {
    let document: JournalDocument

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let data = document.data, let content = PDFContent.document(data: data, isPDF: document.isPDF) {
                    PDFDocumentView(document: content)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ContentUnavailableView("Document illisible", systemImage: "doc.questionmark")
                }
            }
            .navigationTitle(document.displayTitle)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
    }
}

extension View {
    /// Plein écran sur iPhone et iPad, grande feuille sur Mac.
    func documentViewer(item: Binding<JournalDocument?>) -> some View {
        #if os(iOS)
        fullScreenCover(item: item) { DocumentViewer(document: $0) }
        #else
        sheet(item: item) { DocumentViewer(document: $0).frame(minWidth: 760, minHeight: 560) }
        #endif
    }
}
