import SwiftUI
import SwiftData
import SheetKit

/// Compte rendu d'une session : en-tête, résumé, récit mis en forme, gains, fiches qui y apparaissent,
/// documents rattachés.
struct JournalSessionView: View {
    @Bindable var session: JournalSession
    let journal: Journal
    let onDelete: () -> Void

    @State private var choosingEntries = false
    @State private var confirmingDelete = false
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                TextField("Titre", text: $session.title, prompt: Text("Titre de la session"))
                    .font(.title3.weight(.semibold))
                Stepper(value: $session.number, in: 0...9999) {
                    LabeledContent("Numéro", value: "\(session.number)")
                }
                DatePicker("Date", selection: $session.date, displayedComponents: .date)
                LabeledContent("Date en jeu") {
                    TextField("Date en jeu", text: $session.gameDate, prompt: Text("ex. 3 Thermidor 1792"))
                        .multilineTextAlignment(.trailing)
                        .labelsHidden()
                }
            }
            Section("Résumé") {
                TextField("Résumé", text: $session.summary, prompt: Text("En une ou deux phrases"), axis: .vertical)
                    .lineLimit(2...5)
            }
            Section {
                SessionTextEditor(session: session)
            } header: {
                Text("Récit")
            } footer: {
                Text("Gras, italique, taille du texte : sélectionnez du texte pour le mettre en forme.")
            }
            Section {
                TextField("Gains", text: $session.gains, prompt: Text("Expérience, objets, argent…"), axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                Text("Gains")
            } footer: {
                Text("À reporter à la main sur la fiche et dans la Besace.")
            }
            appearances
            Section("Documents") {
                ForEach(session.sortedDocuments) { document in
                    JournalLink(route: .document(document)) { DocumentRow(document: document) }
                }
                DocumentAddMenu(journal: journal, session: session)
            }
            Section {
                Button("Supprimer la session", systemImage: "trash", role: .destructive) {
                    confirmingDelete = true
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $choosingEntries) {
            AppearancePicker(session: session, journal: journal)
        }
        .confirmationDialog("Supprimer la session \(session.number) ?", isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                let deleted = session
                onDelete()
                context.delete(deleted)
            }
        } message: {
            Text("Les fiches et les documents de la session restent dans le journal.")
        }
    }

    private var appearances: some View {
        Section {
            ForEach(session.sortedEntries) { entry in
                JournalLink(route: .entry(entry)) { CodexEntryRow(entry: entry, showsKind: true) }
                    .contextMenu {
                        Button("Retirer de la session", systemImage: "minus.circle") {
                            session.setAppears(entry, false)
                        }
                    }
            }
            Button {
                choosingEntries = true
            } label: {
                Label("Choisir…", systemImage: "person.2.badge.plus")
            }
        } header: {
            Text("Apparaissent")
        }
    }
}

/// Récit de la session : éditeur de texte riche du système. Le texte est relu depuis la session
/// à l'ouverture, et enregistré (texte riche et texte brut) à chaque modification.
struct SessionTextEditor: View {
    let session: JournalSession

    @State private var text = AttributedString()
    @State private var saved: AttributedString?

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: 220)
            .scrollContentBackground(.hidden)
            .accessibilityLabel("Récit")
            .onAppear {
                let loaded = RichText.decode(session.richText, fallback: session.plainText)
                saved = loaded
                text = loaded
            }
            .onChange(of: text) { _, newValue in
                guard newValue != saved else { return }
                saved = newValue
                session.setText(richText: RichText.encode(newValue), plainText: String(newValue.characters))
            }
    }
}

/// Choix des fiches qui apparaissent dans une session, genre par genre ; création d'une fiche au passage.
struct AppearancePicker: View {
    let session: JournalSession
    let journal: Journal

    @State private var newName = ""
    @State private var newKind: CodexKind = .npc
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Nouvelle fiche", text: $newName, prompt: Text("Nom d'une nouvelle fiche"))
                            .onSubmit(addEntry)
                        Picker("Genre", selection: $newKind) {
                            ForEach(CodexKind.allCases, id: \.self) { kind in
                                Label(kind.title, systemImage: kind.symbol).tag(kind)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                        Button("Ajouter", action: addEntry)
                            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                ForEach(CodexKind.allCases, id: \.self) { kind in
                    let entries = journal.entries(of: kind)
                    if !entries.isEmpty {
                        Section {
                            ForEach(entries) { entry in
                                row(entry)
                            }
                        } header: {
                            Label(kind.pluralTitle, systemImage: kind.symbol)
                        }
                    }
                }
            }
            .navigationTitle("Apparaissent")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .frame(minWidth: 380, minHeight: 460)
    }

    private func row(_ entry: CodexEntry) -> some View {
        let appears = session.contains(entry)
        return Button {
            session.setAppears(entry, !appears)
        } label: {
            HStack {
                CodexEntryRow(entry: entry)
                Spacer()
                Image(systemName: appears ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(appears ? Color.accentColor : .secondary)
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(appears ? .isSelected : [])
    }

    private func addEntry() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        session.setAppears(journal.addEntry(named: name, kind: newKind, in: context), true)
        newName = ""
    }
}
