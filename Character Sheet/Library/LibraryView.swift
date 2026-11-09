import SwiftUI
import SwiftData
import SheetKit

/// Bibliothèque provisoire : elle sera remplacée par la vraie bibliothèque au jalon M3.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlayerCharacter.updatedAt, order: .reverse) private var characters: [PlayerCharacter]
    @Query(sort: \SheetTemplate.name) private var templates: [SheetTemplate]
    @State private var path: [PlayerCharacter] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Personnages") {
                    ForEach(characters) { character in
                        NavigationLink(value: character) {
                            LibraryRow(title: character.displayName, subtitle: character.sourceTemplateName)
                        }
                        .contextMenu {
                            Button("Dupliquer", systemImage: "plus.square.on.square") {
                                character.duplicate(in: context)
                            }
                            Button("Enregistrer comme template", systemImage: "doc.badge.plus") {
                                character.makeTemplate(named: "Template de \(character.displayName)", in: context)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(characters[index]) }
                    }
                }

                Section("Templates") {
                    ForEach(templates) { template in
                        NavigationLink {
                            SheetView(title: template.name, sheet: template.sheet, initialMode: .fill)
                        } label: {
                            LibraryRow(title: template.name, subtitle: template.system)
                        }
                        .contextMenu {
                            Button("Nouveau personnage", systemImage: "person.badge.plus") {
                                template.makeCharacter(named: "Nouveau personnage", in: context)
                            }
                            Button("Dupliquer", systemImage: "plus.square.on.square") {
                                template.duplicate(in: context)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(templates[index]) }
                    }
                }
            }
            .overlay {
                if characters.isEmpty && templates.isEmpty {
                    ContentUnavailableView(
                        "Bibliothèque vide",
                        systemImage: "books.vertical",
                        description: Text("Crée un template pour commencer.")
                    )
                }
            }
            .navigationTitle("Bibliothèque")
            .navigationDestination(for: PlayerCharacter.self) { character in
                SheetView(title: character.displayName, sheet: character.sheet, initialMode: .play)
            }
            #if DEBUG
            .task {
                // Argument de lancement pour les captures : -demoOpen Leo
                if path.isEmpty, let name = UserDefaults.standard.string(forKey: "demoOpen"),
                   let character = characters.first(where: { $0.displayName == name }) {
                    path = [character]
                }
            }
            #endif
            .toolbar {
                Button("Nouveau template", systemImage: "plus") {
                    SheetTemplate.create(name: "Nouveau template", in: context)
                }
            }
        }
    }
}

private struct LibraryRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    LibraryView()
        .modelContainer(PreviewData.container)
}
