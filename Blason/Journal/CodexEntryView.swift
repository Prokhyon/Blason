import SwiftUI
import PhotosUI
import SwiftData
import SheetKit

/// Fiche courte du journal (PNJ, lieu, indice…) : nom, genre, état, image, description, sessions
/// où elle apparaît, documents rattachés.
struct CodexEntryView: View {
    @Bindable var entry: CodexEntry
    let journal: Journal
    let onDelete: () -> Void

    @State private var photo: PhotosPickerItem?
    @State private var confirmingDelete = false
    @FocusState private var nameFocused: Bool
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                TextField("Nom", text: $entry.name, prompt: Text("Nom"))
                    .font(.title3.weight(.semibold))
                    .focused($nameFocused)
                Picker("Genre", selection: $entry.kind) {
                    ForEach(CodexKind.allCases, id: \.self) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }
                TextField("État", text: $entry.status, prompt: Text("vivant, disparu, résolu…"))
            }
            Section("Image") {
                image
            }
            Section("Description") {
                TextField("Description", text: $entry.summary, prompt: Text("Qui, quoi, où ; ce qu'on en sait"),
                          axis: .vertical)
                    .lineLimit(3...12)
            }
            Section("Sessions") {
                let sessions = entry.sortedSessions
                if sessions.isEmpty {
                    Text("N'apparaît dans aucune session.")
                        .foregroundStyle(.secondary)
                }
                ForEach(sessions) { session in
                    JournalLink(route: .session(session)) { SessionRow(session: session) }
                }
            }
            Section("Documents") {
                ForEach(entry.sortedDocuments) { document in
                    JournalLink(route: .document(document)) { DocumentRow(document: document) }
                }
                DocumentAddMenu(journal: journal, entry: entry)
            }
            Section {
                Button("Supprimer la fiche", systemImage: "trash", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .formStyle(.grouped)
        .task(id: entry.persistentModelID) {
            // Fiche tout juste créée : le curseur va dans le nom.
            guard entry.name.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(250))
            nameFocused = true
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    entry.imageData = ImageData.downscaled(data)
                }
                photo = nil
            }
        }
        .confirmationDialog("Supprimer « \(entry.displayName) » ?", isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                let deleted = entry
                onDelete()
                context.delete(deleted)
            }
        } message: {
            Text("Elle disparaît des sessions où elle apparaît ; ses documents restent dans le journal.")
        }
    }

    @ViewBuilder
    private var image: some View {
        if let data = entry.imageData, let picture = PlatformImage(data: data) {
            Image(platformImage: picture)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel(entry.displayName)
        }
        HStack(spacing: 16) {
            PhotosPicker(entry.imageData == nil ? "Choisir une image" : "Changer d'image",
                         selection: $photo, matching: .images)
            if entry.imageData != nil {
                Button("Retirer", role: .destructive) { entry.imageData = nil }
            }
        }
        .buttonStyle(.borderless)
        // Glisser une image depuis le Finder, Photos ou une autre app.
        .dropDestination(for: DroppedImage.self) { images, _ in
            guard let image = images.first else { return false }
            entry.imageData = ImageData.downscaled(image.data)
            return true
        }
    }
}
