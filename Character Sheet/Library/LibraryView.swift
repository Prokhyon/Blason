import SwiftUI
import SwiftData
import SheetKit

/// Bibliothèque provisoire (M1) : sert à vérifier le modèle et les opérations
/// de copie. Elle sera remplacée par la vraie bibliothèque au jalon M3.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlayerCharacter.updatedAt, order: .reverse) private var characters: [PlayerCharacter]
    @Query(sort: \SheetTemplate.name) private var templates: [SheetTemplate]

    var body: some View {
        NavigationStack {
            List {
                Section("Personnages") {
                    ForEach(characters) { character in
                        NavigationLink {
                            SheetOutlineView(title: character.displayName, sheet: character.sheet)
                        } label: {
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
                            SheetOutlineView(title: template.name, sheet: template.sheet)
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
