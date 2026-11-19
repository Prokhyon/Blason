import SwiftUI
import SwiftData
import SheetKit

/// Carnet (PNJ, lieux, indices…) et documents du journal, à côté de la session (feuille sur iPhone).
/// Tout ce qui est cité ou joint dans les sessions s'y retrouve ; on peut aussi y ajouter une fiche ou
/// un document à la main. La navigation est propre au panneau (pas de `NavigationStack`, dont la barre
/// se mélangerait à celle de la fenêtre sur Mac).
struct JournalLibrary: View {
    let journal: Journal
    @Binding var path: [JournalRoute]
    @Binding var tab: JournalTab
    let onClose: () -> Void

    @State private var query = ""
    @Environment(\.sheetTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Group {
                if let route = path.last {
                    destination(route)
                        .id(route)
                        .transition(.move(edge: .trailing))
                } else {
                    home
                        .transition(.move(edge: .leading))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .background { theme.panelBackground() }
        .animation(.snappy(duration: 0.25), value: path)
        .onChange(of: path) { _, _ in
            // Un élément supprimé peut encore figurer dans le chemin.
            if path.contains(where: \.isDeleted) { path.removeAll { $0.isDeleted } }
        }
    }

    // MARK: En-tête

    private var header: some View {
        HStack(spacing: 8) {
            if !path.isEmpty {
                Button {
                    path.removeLast()
                } label: {
                    Label("Retour", systemImage: "chevron.backward")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 28, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("[", modifiers: .command)
            }
            Text(headerTitle)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Button {
                onClose()
            } label: {
                Label("Fermer", systemImage: "xmark")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var headerTitle: String {
        switch path.last {
        case nil, .session: String(localized: "Carnet et documents")
        case .entry(let entry): String(localized: entry.kind.singularText)
        case .document(let document): document.isDrawing ? String(localized: "Croquis") : String(localized: "Document")
        }
    }

    // MARK: Pages

    @ViewBuilder
    private func destination(_ route: JournalRoute) -> some View {
        switch route {
        case .session:
            EmptyView()
        case .entry(let entry):
            CodexEntryView(entry: entry, journal: journal, onDelete: pop)
        case .document(let document):
            JournalDocumentView(document: document, journal: journal, onDelete: pop)
        }
    }

    private func pop() {
        if !path.isEmpty { path.removeLast() }
    }

    /// Recherche dans le carnet et les documents (les sessions sont dans la liste de gauche).
    private var searchResults: JournalSearchResults {
        var results = journal.search(query)
        results.sessions = []
        return results
    }

    private var home: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                JournalSearchField(text: $query, prompt: "Rechercher dans le carnet")
                if query.isEmpty {
                    Picker("Rubrique", selection: $tab) {
                        ForEach(JournalTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
            if query.isEmpty {
                switch tab {
                case .codex: CodexList(journal: journal)
                case .documents: DocumentList(journal: journal)
                }
            } else {
                JournalSearchResultsView(results: searchResults, query: query)
            }
        }
    }
}

// MARK: - Navigation

enum JournalRoute: Hashable {
    case session(JournalSession)
    case entry(CodexEntry)
    case document(JournalDocument)

    var isDeleted: Bool {
        switch self {
        case .session(let session): session.isDeleted || session.modelContext == nil
        case .entry(let entry): entry.isDeleted || entry.modelContext == nil
        case .document(let document): document.isDeleted || document.modelContext == nil
        }
    }
}

/// Ouvre une page du journal (session, fiche, document) par-dessus la page courante.
struct JournalNavigator {
    let open: @MainActor (JournalRoute) -> Void
}

extension EnvironmentValues {
    @Entry var journalNavigator: JournalNavigator?
}

/// Rubrique du panneau : carnet ou documents.
enum JournalTab: String, CaseIterable, Identifiable {
    case codex
    case documents

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .codex: "Carnet"
        case .documents: "Documents"
        }
    }
}

extension CodexKind {
    /// Genre au singulier, en texte (titre de l'en-tête).
    var singularText: String.LocalizationValue {
        switch self {
        case .npc: "PNJ"
        case .place: "Lieu"
        case .clue: "Indice"
        case .faction: "Faction"
        case .other: "Autre"
        }
    }
}

/// Ligne qui ouvre une page du journal : contenu, puis chevron.
struct JournalLink<Label: View>: View {
    let route: JournalRoute
    @ViewBuilder let label: Label

    @Environment(\.journalNavigator) private var navigator

    var body: some View {
        Button {
            navigator?.open(route)
        } label: {
            HStack(spacing: 10) {
                label
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recherche

struct JournalSearchField: View {
    @Binding var text: String
    var prompt: LocalizedStringKey = "Rechercher dans le journal"
    var focus: FocusState<Bool>.Binding?

    @Environment(\.sheetTheme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            field
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Label("Effacer la recherche", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(theme.inputFill, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var field: some View {
        if let focus {
            TextField(prompt, text: $text).focused(focus)
        } else {
            TextField(prompt, text: $text)
        }
    }
}

struct JournalSearchResultsView: View {
    let results: JournalSearchResults
    let query: String

    var body: some View {
        if results.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List {
                Group {
                    if !results.sessions.isEmpty {
                        Section("Sessions") {
                            ForEach(results.sessions) { session in
                                JournalLink(route: .session(session)) { SessionRow(session: session) }
                            }
                        }
                    }
                    if !results.entries.isEmpty {
                        Section("Carnet") {
                            ForEach(results.entries) { entry in
                                JournalLink(route: .entry(entry)) { CodexEntryRow(entry: entry, showsKind: true) }
                            }
                        }
                    }
                    if !results.documents.isEmpty {
                        Section("Documents") {
                            ForEach(results.documents) { document in
                                JournalLink(route: .document(document)) { DocumentRow(document: document) }
                            }
                        }
                    }
                }
                .themedRows()
            }
            .themedList()
        }
    }
}

// MARK: - Carnet

struct CodexList: View {
    let journal: Journal

    @Environment(\.modelContext) private var context
    @Environment(\.journalNavigator) private var navigator

    var body: some View {
        List {
            Group {
                Section {
                    Menu {
                        ForEach(CodexKind.allCases, id: \.self) { kind in
                            Button {
                                navigator?.open(.entry(journal.addEntry(kind: kind, in: context)))
                            } label: {
                                Label(kind.title, systemImage: kind.symbol)
                            }
                        }
                    } label: {
                        Label("Nouvelle fiche", systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                    }
                } footer: {
                    if (journal.entries ?? []).isEmpty {
                        Text("PNJ, lieux, indices, factions : les fiches citées dans les sessions, et celles ajoutées ici.")
                    }
                }
                ForEach(CodexKind.allCases, id: \.self) { kind in
                    let entries = journal.entries(of: kind)
                    if !entries.isEmpty {
                        Section {
                            ForEach(entries) { entry in
                                JournalLink(route: .entry(entry)) { CodexEntryRow(entry: entry) }
                            }
                        } header: {
                            Label(kind.pluralTitle, systemImage: kind.symbol)
                        }
                    }
                }
            }
            .themedRows()
        }
        .themedList()
    }
}

struct CodexEntryRow: View {
    let entry: CodexEntry
    var showsKind = false

    var body: some View {
        HStack(spacing: 10) {
            CodexThumbnail(entry: entry, side: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .foregroundStyle(entry.name.isEmpty ? .secondary : .primary)
                let detail = [showsKind ? String(localized: entry.kind.singularText) : nil,
                              entry.status.isEmpty ? nil : entry.status]
                    .compactMap { $0 }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Image d'une fiche, ou le symbole de son genre.
struct CodexThumbnail: View {
    let entry: CodexEntry
    let side: CGFloat

    var body: some View {
        Group {
            if let data = entry.imageData, let image = PlatformImage(data: data) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: entry.kind.symbol)
                    .font(.system(size: side * 0.42))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.tertiaryFill)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.22))
        .accessibilityHidden(true)
    }
}

// MARK: - Documents

struct DocumentList: View {
    let journal: Journal

    @Environment(\.modelContext) private var context

    var body: some View {
        let documents = journal.listedDocuments
        List {
            Group {
                Section {
                    DocumentAddMenu(journal: journal)
                } footer: {
                    if documents.isEmpty {
                        Text("Aides de jeu, cartes, lettres du MJ, croquis : ceux joints aux sessions, et ceux ajoutés ici (Fichiers, Photos, glisser-déposer).")
                    }
                }
                if !documents.isEmpty {
                    Section {
                        ForEach(documents) { document in
                            JournalLink(route: .document(document)) { DocumentRow(document: document, showsAttachment: true) }
                        }
                    }
                }
            }
            .themedRows()
        }
        .themedList()
        .dropDestination(for: DroppedDocument.self) { dropped, _ in
            for item in dropped {
                journal.addDocument(title: item.document.title, contentType: item.document.type, data: item.document.data,
                                    in: context)
            }
            return !dropped.isEmpty
        }
    }
}
