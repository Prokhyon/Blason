import SwiftUI
import SwiftData
import SheetKit

/// Bibliothèque : barre latérale (Personnages / Templates) et grille de cartes.
/// Ouvrir une fiche masque la barre latérale pour lui laisser toute la largeur.
struct LibraryView: View {
    enum Category: String, Hashable {
        case characters
        case templates
    }

    @Query private var characters: [PlayerCharacter]
    @Query private var templates: [SheetTemplate]

    @State private var category: Category? = .characters
    @State private var path = NavigationPath()
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
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
            NavigationStack(path: $path) {
                Group {
                    switch category ?? .characters {
                    case .characters: CharacterGrid(path: $path)
                    case .templates: TemplateGrid(path: $path)
                    }
                }
                .navigationDestination(for: PlayerCharacter.self) { character in
                    SheetView(
                        title: character.displayName,
                        sheet: character.sheet,
                        initialMode: .play,
                        onEdit: { character.touch() }
                    )
                }
                .navigationDestination(for: SheetTemplate.self) { template in
                    SheetView(
                        title: template.name,
                        sheet: template.sheet,
                        initialMode: .structure,
                        onEdit: { template.updatedAt = Date() }
                    )
                }
            }
        }
        .onChange(of: category) {
            path = NavigationPath()
        }
        .onChange(of: path.count) { _, count in
            withAnimation {
                columnVisibility = count == 0 ? .automatic : .detailOnly
            }
        }
        #if DEBUG
        .task { await openDemoTarget() }
        #endif
    }

    #if DEBUG
    /// Arguments de lancement pour les captures : -demoCategory templates, -demoOpen Leo
    /// (début du nom d'un personnage ou d'un template).
    private func openDemoTarget() async {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "demoCategory"), let value = Category(rawValue: raw) {
            category = value
            // Le changement de catégorie vide le chemin : on attend qu'il soit passé.
            try? await Task.sleep(for: .milliseconds(300))
        }
        guard path.isEmpty, let name = defaults.string(forKey: "demoOpen") else { return }
        // Début du nom suffisant (« -demoOpen Basic ») : les arguments sont lus comme des plists,
        // les parenthèses et accents y passent mal.
        func same(_ candidate: String) -> Bool { candidate.hasPrefix(name) }
        if let character = characters.first(where: { same($0.displayName) }) {
            path.append(character)
        } else if let template = templates.first(where: { same($0.name) }) {
            path.append(template)
        }
    }
    #endif
}

#Preview {
    LibraryView()
        .modelContainer(PreviewData.container)
}
