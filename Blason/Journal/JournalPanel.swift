import SwiftUI
import SwiftData
import SheetKit

/// Écran du journal dans le panneau latéral (feuille sur iPhone) : sessions, carnet (PNJ, lieux,
/// indices…), documents, recherche. Toujours modifiable, quel que soit le mode de la fiche : on écrit
/// le journal pendant la partie. La navigation est propre au panneau (pas de `NavigationStack`, dont
/// la barre se mélangerait à celle de la fenêtre sur Mac).
struct JournalPanel: View {
    let journal: Journal
    let onClose: () -> Void

    @State private var path: [JournalRoute] = []
    @State private var tab: JournalTab = .sessions
    @State private var query = ""
    @Environment(\.modelContext) private var context

    init(journal: Journal, onClose: @escaping () -> Void) {
        self.journal = journal
        self.onClose = onClose
        #if DEBUG
        // Captures : -demoJournalTab documents, -demoSession 2, -demoDocument YES (premier document ;
        // -demoViewer YES l'ouvre en plus dans la visionneuse).
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "demoJournalTab"), let value = JournalTab(rawValue: raw) {
            _tab = State(initialValue: value)
        }
        let number = defaults.integer(forKey: "demoSession")
        if number > 0, let session = journal.sortedSessions.first(where: { $0.number == number }) {
            _path = State(initialValue: [.session(session)])
        }
        if defaults.bool(forKey: "demoDocument"), let document = journal.sortedDocuments.first {
            _path = State(initialValue: [.document(document)])
        }
        #endif
    }

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
        .background(Color.groupedBackground)
        .animation(.snappy(duration: 0.25), value: path)
        .environment(\.journalNavigator, JournalNavigator { route in path.append(route) })
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
                Label("Fermer le journal", systemImage: "xmark")
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
        case nil: String(localized: "Journal")
        case .session(let session): session.numberTitle
        case .entry(let entry): String(localized: entry.kind.singularText)
        case .document: String(localized: "Document")
        }
    }

    // MARK: Pages

    @ViewBuilder
    private func destination(_ route: JournalRoute) -> some View {
        switch route {
        case .session(let session):
            JournalSessionView(session: session, journal: journal, onDelete: pop)
        case .entry(let entry):
            CodexEntryView(entry: entry, journal: journal, onDelete: pop)
        case .document(let document):
            JournalDocumentView(document: document, journal: journal, onDelete: pop)
        }
    }

    private func pop() {
        if !path.isEmpty { path.removeLast() }
        // Un élément supprimé peut encore figurer plus haut dans le chemin.
        path.removeAll { $0.isDeleted }
    }

    private var home: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                JournalSearchField(text: $query)
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
                case .sessions: SessionList(journal: journal)
                case .codex: CodexList(journal: journal)
                case .documents: DocumentList(journal: journal)
                }
            } else {
                JournalSearchResultsView(results: journal.search(query), query: query)
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

enum JournalTab: String, CaseIterable, Identifiable {
    case sessions
    case codex
    case documents

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .sessions: "Sessions"
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

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Rechercher dans le journal", text: $text)
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
        .background(Color.tertiaryFill, in: RoundedRectangle(cornerRadius: 10))
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
        }
    }
}

// MARK: - Sessions

struct SessionList: View {
    let journal: Journal

    @Environment(\.modelContext) private var context
    @Environment(\.journalNavigator) private var navigator

    var body: some View {
        let sessions = journal.sortedSessions
        let today = journal.session(on: Date())
        List {
            Section {
                Button {
                    let (session, _) = journal.todaysSession(in: context)
                    navigator?.open(.session(session))
                } label: {
                    Label(today == nil ? "Session du jour" : "Ouvrir la session du jour",
                          systemImage: today == nil ? "plus.circle.fill" : "book.pages")
                        .font(.body.weight(.semibold))
                }
            } footer: {
                if sessions.isEmpty {
                    Text("Une entrée par partie : date, récit, gains, et les PNJ ou lieux rencontrés.")
                }
            }
            if !sessions.isEmpty {
                Section {
                    ForEach(sessions) { session in
                        JournalLink(route: .session(session)) { SessionRow(session: session) }
                    }
                }
            }
        }
    }
}

struct SessionRow: View {
    let session: JournalSession

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.numberTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Text(session.date, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(session.title.isEmpty ? String(localized: "Sans titre") : session.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(session.title.isEmpty ? .secondary : .primary)
            if !session.gameDate.isEmpty {
                Text(session.gameDate)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            if !session.summary.isEmpty {
                Text(session.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Carnet

struct CodexList: View {
    let journal: Journal

    @Environment(\.modelContext) private var context
    @Environment(\.journalNavigator) private var navigator

    var body: some View {
        List {
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
                    Text("PNJ, lieux, indices, factions : des fiches courtes, reliées aux sessions où ils apparaissent.")
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
        let documents = journal.sortedDocuments
        List {
            Section {
                DocumentAddMenu(journal: journal)
            } footer: {
                if documents.isEmpty {
                    Text("Aides de jeu, cartes, lettres du MJ : PDF et images, depuis Fichiers, Photos ou par glisser-déposer.")
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
        .dropDestination(for: DroppedDocument.self) { dropped, _ in
            for item in dropped {
                journal.addDocument(title: item.document.title, contentType: item.document.type, data: item.document.data,
                                    in: context)
            }
            return !dropped.isEmpty
        }
    }
}
