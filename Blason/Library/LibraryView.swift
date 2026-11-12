import SwiftUI
import SwiftData
import SheetKit

/// Type d'appareil, pour les choix de disposition qui ne doivent pas changer avec la largeur.
enum DeviceKind {
    static var isPhone: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }
}

/// Fiche ouverte depuis la bibliothèque.
enum LibraryRoute: Hashable, Identifiable {
    case character(PlayerCharacter)
    case template(SheetTemplate)

    var id: Self { self }
}

/// Bibliothèque : barre latérale (Personnages / Templates) et grille de cartes sur iPad,
/// un onglet par catégorie sur iPhone. Une fiche s'ouvre en plein écran par-dessus, comme un
/// document (iPhone, iPad) ; sur Mac, elle est poussée dans la pile et masque la barre latérale.
struct LibraryView: View {
    enum Category: String, Hashable {
        case characters
        case templates
    }

    @Query private var characters: [PlayerCharacter]
    @Query private var templates: [SheetTemplate]
    @Environment(SyncMonitor.self) private var syncMonitor

    @State private var category: Category? = .characters
    /// Fiche ouverte.
    @State private var opened: LibraryRoute?
    @Namespace private var transition
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    /// Demande venue d'un menu (nouveau, importer), traitée par la grille concernée.
    @State private var request: LibraryRequest?

    private var currentCategory: Category { category ?? .characters }

    /// Mac : la fiche ouverte, seul élément de la pile.
    private var openedPath: Binding<[LibraryRoute]> {
        Binding(
            get: { opened.map { [$0] } ?? [] },
            set: { opened = $0.last }
        )
    }

    var body: some View {
        Group {
            // Choisi selon l'appareil, pas la largeur : tourner un grand iPhone (largeur « normale »
            // en paysage) ou redimensionner une fenêtre d'iPad ne doit pas recréer la fiche ouverte.
            if DeviceKind.isPhone {
                // iPhone : un onglet par catégorie, chacun avec sa pile.
                TabView(selection: $category) {
                    Tab("Personnages", systemImage: "person.2", value: Category.characters) {
                        stack(for: .characters)
                    }
                    Tab("Templates", systemImage: "doc.on.doc", value: Category.templates) {
                        stack(for: .templates)
                    }
                }
            } else {
                splitView
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $opened) { route in
            screen(for: route)
                .zoomTransition(sourceID: route, in: transition)
        }
        #endif
        .focusedSceneValue(\.libraryActions, LibraryActions(perform: perform))
        #if DEBUG
        .task { await openDemoTarget() }
        #endif
    }

    /// Menu Fichier : revient à la grille concernée (fiche ouverte refermée) et lui passe la demande.
    private func perform(_ newRequest: LibraryRequest) {
        let target: Category = switch newRequest {
        case .newCharacter: .characters
        case .newTemplate: .templates
        case .importFiles: currentCategory
        }
        opened = nil
        category = target
        request = newRequest
    }

    /// iPad : barre latérale (Personnages / Templates), masquée quand une fiche est ouverte.
    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $category) {
                Label("Personnages", systemImage: "person.2")
                    .badge(characters.count)
                    .tag(Category.characters)
                Label("Templates", systemImage: "doc.on.doc")
                    .badge(templates.count)
                    .tag(Category.templates)
            }
            .navigationTitle("Bibliothèque")
        } detail: {
            stack(for: currentCategory)
                .id(currentCategory)
        }
        #if os(macOS)
        .onChange(of: category) {
            // Changer de catégorie dans la barre latérale revient à sa grille (sur iPad, la fiche
            // ouverte couvre la barre latérale).
            opened = nil
        }
        .onChange(of: opened == nil) { _, closed in
            withAnimation {
                columnVisibility = closed ? .automatic : .detailOnly
            }
        }
        #endif
    }

    /// Pile de navigation d'une catégorie : sa grille ; sur Mac, la fiche ouverte y est poussée.
    private func stack(for category: Category) -> some View {
        // Seule la grille affichée reçoit les demandes des menus.
        let request = category == currentCategory ? $request : .constant(nil)
        let grid = Group {
            switch category {
            case .characters: CharacterGrid(open: open, transition: transition, request: request)
            case .templates: TemplateGrid(open: open, transition: transition, request: request)
            }
        }
        // Sous les cartes (la barre latérale est souvent masquée en portrait) ; pas dans les fiches.
        .safeAreaInset(edge: .bottom) {
            if let problem = syncMonitor.problem { SyncNotice(problem: problem) }
        }
        #if os(iOS)
        return NavigationStack { grid }
        #else
        return NavigationStack(path: openedPath) {
            grid.navigationDestination(for: LibraryRoute.self) { screen(for: $0) }
        }
        #endif
    }

    private func open(_ route: LibraryRoute) {
        opened = route
    }

    /// Écran d'une fiche : onglets, modes ; il se referme en revenant à la bibliothèque.
    @ViewBuilder
    private func screen(for route: LibraryRoute) -> some View {
        switch route {
        case .character(let character):
            SheetScreen(title: character.displayName, sheet: character.sheet,
                        onEdit: { character.touch() }, onClose: close)
        case .template(let template):
            SheetScreen(title: template.name, sheet: template.sheet,
                        onEdit: { template.updatedAt = Date() }, onClose: close)
        }
    }

    private func close() {
        opened = nil
    }

    #if DEBUG
    /// Arguments de lancement pour les captures : -demoCategory templates, -demoOpen Leo
    /// (début du nom d'un personnage ou d'un template).
    private func openDemoTarget() async {
        let defaults = UserDefaults.standard
        // -demoExport /chemin.json : écrit le JSON du premier personnage ;
        // -demoImport /chemin.json : importe ce fichier et l'ouvre.
        if let path = defaults.string(forKey: "demoExport"), let character = characters.first {
            try? SheetDocument(character: character).jsonData().write(to: URL(filePath: path))
        }
        if let path = defaults.string(forKey: "demoImport"), let context = characters.first?.modelContext {
            do {
                switch try SheetDocument.decode(Data(contentsOf: URL(filePath: path))).insert(into: context) {
                case .character(let character): opened = .character(character)
                case .template(let template): opened = .template(template)
                }
                return
            } catch {
                print("Import de démo impossible : \(error)")
            }
        }
        if let raw = defaults.string(forKey: "demoCategory"), let value = Category(rawValue: raw) {
            category = value
            // Le changement de catégorie vide le chemin précédent : on attend qu'il soit passé.
            try? await Task.sleep(for: .milliseconds(300))
        }
        guard opened == nil, let name = defaults.string(forKey: "demoOpen") else { return }
        // Début du nom suffisant (« -demoOpen Basic ») : les arguments sont lus comme des plists,
        // les parenthèses et accents y passent mal.
        func same(_ candidate: String) -> Bool { candidate.hasPrefix(name) }
        if let character = characters.first(where: { same($0.displayName) }) {
            opened = .character(character)
        } else if let template = templates.first(where: { same($0.name) }) {
            opened = .template(template)
        }
    }
    #endif
}

#Preview {
    LibraryView()
        .modelContainer(PreviewData.container)
        .environment(SyncMonitor())
}
