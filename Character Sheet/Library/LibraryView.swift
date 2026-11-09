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
                        initialMode: .fill,
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
        .task { openDemoTarget() }
        #endif
    }

    #if DEBUG
    /// Arguments de lancement pour les captures : -demoCategory templates, -demoOpen Leo.
    private func openDemoTarget() {
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "demoCategory"), let value = Category(rawValue: raw) {
            category = value
        }
        if path.isEmpty, let name = defaults.string(forKey: "demoOpen"),
           let character = characters.first(where: { $0.displayName == name }) {
            path.append(character)
        }
    }
    #endif
}

#Preview {
    LibraryView()
        .modelContainer(PreviewData.container)
}
