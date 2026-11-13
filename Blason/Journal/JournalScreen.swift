import SwiftUI
import SwiftData
import SheetKit

/// Onglet Journal du personnage (SPEC §5.14, §5.17). Grand écran : sous les onglets, la rangée des
/// sessions dans l'ordre chronologique (repliée sur la session ouverte et ses deux précédentes) ;
/// la liste complète, avec la recherche, en panneau à gauche ; la session au centre ; le carnet et
/// les documents à droite à la demande.
/// iPhone : la liste, puis la session en plein écran ; carnet et documents en feuille.
struct JournalScreen: View {
    let character: PlayerCharacter

    @State private var selected: JournalSession?
    @State private var showsSessions = true
    @State private var showsLibrary = false
    @State private var libraryPath: [JournalRoute] = []
    @State private var libraryTab: JournalTab = .codex
    @State private var query = ""
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if let journal = character.journal {
                content(journal)
            } else {
                Color.clear
            }
        }
        .task(id: character.persistentModelID) {
            let journal = character.ensureJournal(in: context)
            setUp(journal)
        }
    }

    @ViewBuilder
    private func content(_ journal: Journal) -> some View {
        Group {
            if sizeClass == .compact {
                compact(journal)
            } else {
                regular(journal)
            }
        }
        .environment(\.journalNavigator, JournalNavigator { route in navigate(to: route) })
        .toolbar {
            ToolbarItem(placement: .primaryAction) { libraryButton }
            ToolbarSpacer(.fixed, placement: .primaryAction)
            ToolbarItem(placement: .primaryAction) {
                Button {
                    newSession(in: journal)
                    if sizeClass != .compact { hideSessions() }
                } label: {
                    Label(journal.session(on: Date()) == nil ? "Nouvelle session" : "Session du jour",
                          systemImage: "square.and.pencil")
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    /// Rangée des sessions, de la plus ancienne à la plus récente ; le bouton à gauche ouvre la liste.
    private func sessionBar(_ journal: Journal) -> some View {
        let sessions = Array(journal.sortedSessions.reversed())
        return HStack(spacing: 4) {
            Button {
                withAnimation(.snappy) { showsSessions.toggle() }
            } label: {
                Label("Sessions", systemImage: "list.bullet")
                    .labelStyle(.iconOnly)
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .keyboardShortcut("s", modifiers: [.command, .control])
            .padding(.leading)
            if !sessions.isEmpty {
                SecondaryRow(
                    items: sessions.map { .init(id: $0.persistentModelID, title: $0.title.isEmpty ? $0.numberTitle : $0.title) },
                    selection: selected?.persistentModelID,
                    collapsedBefore: 2
                ) { id in
                    selected = sessions.first { $0.persistentModelID == id }
                    hideSessions()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private var libraryButton: some View {
        Button {
            withAnimation(.snappy) { showsLibrary.toggle() }
        } label: {
            Label("Carnet et documents", systemImage: "books.vertical")
        }
        .keyboardShortcut("j", modifiers: [.command, .shift])
    }

    // MARK: Grand écran

    /// La session occupe toute la largeur ; les panneaux flottent par-dessus, sur les côtés, sous la
    /// rangée des sessions (elle reste visible, avec le bouton qui les ouvre et les ferme).
    private func regular(_ journal: Journal) -> some View {
        ZStack {
            Group {
                if let session = selected, !session.isDeleted {
                    JournalSessionEditor(session: session, journal: journal) { delete(session, in: journal) }
                        .id(session.persistentModelID)
                } else {
                    noSession(journal)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(alignment: .leading) {
            if showsSessions {
                SessionSidebar(journal: journal, selection: sidebarSelection, query: $query,
                               onNew: { newSession(in: journal); hideSessions() })
                    .floatingPanel(width: 320)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .overlay(alignment: .trailing) {
            if showsLibrary {
                library(journal)
                    .floatingPanel(width: 360)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        // Après les panneaux : ils s'arrêtent sous la rangée au lieu de la couvrir.
        .safeAreaBar(edge: .top, spacing: 0) { sessionBar(journal) }
    }

    /// Choisir une session dans le panneau la montre et range le panneau.
    private var sidebarSelection: Binding<JournalSession?> {
        Binding(get: { selected }, set: { session in
            selected = session
            if session != nil { hideSessions() }
        })
    }

    private func hideSessions() {
        withAnimation(.snappy) { showsSessions = false }
    }

    private func noSession(_ journal: Journal) -> some View {
        ContentUnavailableView {
            Label("Aucune session", systemImage: "book.pages")
        } description: {
            Text("Une page par partie : le récit, les PNJ et lieux rencontrés, croquis et documents.")
        } actions: {
            Button("Session du jour") { newSession(in: journal) }
                .buttonStyle(.borderedProminent)
        }
        .background { Color.writingBackground.ignoresSafeArea() }
    }

    // MARK: iPhone

    private func compact(_ journal: Journal) -> some View {
        SessionSidebar(journal: journal, selection: $selected, query: $query, onNew: { newSession(in: journal) })
            .navigationDestination(item: $selected) { session in
                JournalSessionEditor(session: session, journal: journal) { delete(session, in: journal) }
                    .navigationTitle(session.numberTitle)
                    .inlineNavigationTitle()
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) { libraryButton }
                    }
            }
            .sheet(isPresented: $showsLibrary) {
                library(journal)
                    .presentationDetents([.medium, .large])
            }
    }

    // MARK: Carnet et documents

    private func library(_ journal: Journal) -> some View {
        JournalLibrary(journal: journal, path: $libraryPath, tab: $libraryTab) {
            withAnimation(.snappy) { showsLibrary = false }
        }
        .environment(\.journalNavigator, JournalNavigator { route in navigate(to: route, fromLibrary: true) })
    }

    /// Une session s'ouvre au centre ; une fiche ou un document dans le panneau.
    private func navigate(to route: JournalRoute, fromLibrary: Bool = false) {
        switch route {
        case .session(let session):
            selected = session
            if sizeClass == .compact { showsLibrary = false }
        case .entry, .document:
            if fromLibrary && showsLibrary {
                if libraryPath.last != route { libraryPath.append(route) }
            } else {
                libraryPath = [route]
                withAnimation(.snappy) { showsLibrary = true }
            }
        }
    }

    private func newSession(in journal: Journal) {
        let (session, _) = journal.todaysSession(in: context)
        query = ""
        selected = session
    }

    private func delete(_ session: JournalSession, in journal: Journal) {
        let sessions = journal.sortedSessions
        let index = sessions.firstIndex { $0 === session }
        selected = nil
        context.delete(session)
        journal.removeUnusedAttachments(in: context)
        if sizeClass != .compact, let index {
            let remaining = sessions.filter { $0 !== session }
            selected = remaining.isEmpty ? nil : remaining[min(index, remaining.count - 1)]
        }
    }

    private func setUp(_ journal: Journal) {
        if sizeClass != .compact, selected == nil { selected = journal.sortedSessions.first }
        // Les sessions s'affichent d'emblée seulement s'il n'y en a aucune d'ouverte.
        showsSessions = selected == nil
        #if DEBUG
        // Captures : -demoSession 2 ouvre la session 2 ; -demoLibrary codex | documents ouvre le panneau ;
        // -demoDocument YES y ouvre le premier document, -demoEntry Nom une fiche.
        let defaults = UserDefaults.standard
        let number = defaults.integer(forKey: "demoSession")
        if number > 0, let session = journal.sortedSessions.first(where: { $0.number == number }) {
            selected = session
        }
        // -demoSessions YES : panneau des sessions ouvert.
        if defaults.bool(forKey: "demoSessions") { showsSessions = true }
        if let raw = defaults.string(forKey: "demoLibrary"), let tab = JournalTab(rawValue: raw) {
            libraryTab = tab
            showsLibrary = true
        }
        if defaults.bool(forKey: "demoDocument"), let document = journal.listedDocuments.first {
            libraryPath = [.document(document)]
            showsLibrary = true
        }
        if let name = defaults.string(forKey: "demoEntry"), let entry = journal.sortedEntries.first(where: { $0.name == name }) {
            libraryPath = [.entry(entry)]
            showsLibrary = true
        }
        #endif
    }
}

extension View {
    /// Panneau flottant par-dessus la session (grand écran).
    func floatingPanel(width: CGFloat) -> some View {
        self
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.quaternary))
            .shadow(color: .black.opacity(0.18), radius: 18, y: 4)
            .padding(10)
    }
}

// MARK: - Liste des sessions

struct SessionSidebar: View {
    let journal: Journal
    @Binding var selection: JournalSession?
    @Binding var query: String
    let onNew: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                JournalSearchField(text: $query)
                if query.isEmpty {
                    Button(action: onNew) {
                        Label(journal.session(on: Date()) == nil ? "Session du jour" : "Ouvrir la session du jour",
                              systemImage: journal.session(on: Date()) == nil ? "square.and.pencil" : "book.pages")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)
            if query.isEmpty {
                sessionList
            } else {
                JournalSearchResultsView(results: journal.search(query), query: query)
            }
        }
        .background(Color.groupedBackground)
    }

    @ViewBuilder
    private var sessionList: some View {
        let sessions = journal.sortedSessions
        if sessions.isEmpty {
            ContentUnavailableView("Aucune session", systemImage: "book.pages",
                                   description: Text("Une page par partie : récit, rencontres, croquis."))
        } else {
            List(selection: $selection) {
                ForEach(sessions) { session in
                    SessionRow(session: session)
                        .tag(session)
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
                .lineLimit(2)
            if !preview.isEmpty {
                Text(preview)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    /// Le résumé, sinon les premières lignes du récit.
    private var preview: String {
        if !session.summary.isEmpty { return session.summary }
        return session.plainText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(3)
            .joined(separator: " ")
    }
}
