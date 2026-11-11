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

/// Bibliothèque : barre latérale (Personnages / Templates) et grille de cartes sur iPad,
/// un onglet par catégorie sur iPhone. Ouvrir une fiche masque la barre latérale (ou les onglets)
/// pour lui laisser toute la place.
struct LibraryView: View {
    enum Category: String, Hashable {
        case characters
        case templates
    }

    @Query private var characters: [PlayerCharacter]
    @Query private var templates: [SheetTemplate]
    @Environment(SyncMonitor.self) private var syncMonitor

    @State private var category: Category? = .characters
    /// Un chemin de navigation par catégorie : sur iPhone, chaque onglet garde sa pile.
    @State private var paths: [Category: NavigationPath] = [:]
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    private var currentCategory: Category { category ?? .characters }

    private func path(for category: Category) -> Binding<NavigationPath> {
        Binding(
            get: { paths[category] ?? NavigationPath() },
            set: { paths[category] = $0 }
        )
    }

    /// Chemin de la catégorie affichée.
    private var path: Binding<NavigationPath> { path(for: currentCategory) }

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
        #if DEBUG
        .task { await openDemoTarget() }
        #endif
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
        .onChange(of: category) { old, _ in
            // Changer de catégorie dans la barre latérale revient à sa grille.
            if let old { paths[old] = nil }
        }
        .onChange(of: path.wrappedValue.count) { _, count in
            withAnimation {
                columnVisibility = count == 0 ? .automatic : .detailOnly
            }
        }
    }

    /// Pile de navigation d'une catégorie : sa grille, puis les fiches ouvertes.
    private func stack(for category: Category) -> some View {
        let path = path(for: category)
        return NavigationStack(path: path) {
            Group {
                switch category {
                case .characters: CharacterGrid(path: path)
                case .templates: TemplateGrid(path: path)
                }
            }
            // Sous les cartes (la barre latérale est souvent masquée en portrait) ; pas dans les fiches.
            .safeAreaInset(edge: .bottom) {
                if let problem = syncMonitor.problem { SyncNotice(problem: problem) }
            }
            .navigationDestination(for: PlayerCharacter.self) { character in
                SheetView(
                    title: character.displayName,
                    sheet: character.sheet,
                    initialMode: .play,
                    onEdit: { character.touch() }
                )
                .hidesTabBar()
            }
            .navigationDestination(for: SheetTemplate.self) { template in
                SheetView(
                    title: template.name,
                    sheet: template.sheet,
                    initialMode: .structure,
                    onEdit: { template.updatedAt = Date() }
                )
                .hidesTabBar()
            }
        }
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
                case .character(let character): self.path.wrappedValue.append(character)
                case .template(let template): self.path.wrappedValue.append(template)
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
        guard path.wrappedValue.isEmpty, let name = defaults.string(forKey: "demoOpen") else { return }
        // Début du nom suffisant (« -demoOpen Basic ») : les arguments sont lus comme des plists,
        // les parenthèses et accents y passent mal.
        func same(_ candidate: String) -> Bool { candidate.hasPrefix(name) }
        if let character = characters.first(where: { same($0.displayName) }) {
            path.wrappedValue.append(character)
        } else if let template = templates.first(where: { same($0.name) }) {
            path.wrappedValue.append(template)
        }
    }
    #endif
}

#Preview {
    LibraryView()
        .modelContainer(PreviewData.container)
        .environment(SyncMonitor())
}
