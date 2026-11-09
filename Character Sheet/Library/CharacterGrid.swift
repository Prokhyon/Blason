import SwiftUI
import SwiftData
import SheetKit

/// Grille des personnages, du plus récemment modifié au plus ancien.
struct CharacterGrid: View {
    @Binding var path: NavigationPath

    @Environment(\.modelContext) private var context
    @Query(sort: \PlayerCharacter.updatedAt, order: .reverse) private var characters: [PlayerCharacter]
    @Query(sort: \SheetTemplate.name) private var templates: [SheetTemplate]

    @State private var search = ""
    @State private var showingNew = false
    @State private var renaming: PlayerCharacter?
    @State private var newName = ""
    @State private var deleting: PlayerCharacter?

    private var filtered: [PlayerCharacter] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return characters }
        return characters.filter {
            $0.displayName.localizedStandardContains(query)
                || $0.sourceTemplateName.localizedStandardContains(query)
        }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)], spacing: 16) {
                ForEach(filtered) { character in
                    NavigationLink(value: character) {
                        CharacterCard(character: character)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { menu(for: character) }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .overlay { emptyState }
        .navigationTitle("Personnages")
        .searchable(text: $search, prompt: "Rechercher un personnage")
        .toolbar {
            Button("Nouveau personnage", systemImage: "plus") { showingNew = true }
        }
        .sheet(isPresented: $showingNew) {
            NewCharacterView(templates: templates) { character in
                path.append(character)
            }
        }
        .alert("Renommer le personnage", isPresented: isPresented($renaming)) {
            TextField("Nom", text: $newName)
            Button("Renommer") { renaming?.rename(to: newName) }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog(
            "Supprimer « \(deleting?.displayName ?? "") » ?",
            isPresented: isPresented($deleting),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let deleting { context.delete(deleting) }
            }
        } message: {
            Text("La fiche et toutes ses valeurs seront supprimées. Cette action est définitive.")
        }
    }

    @ViewBuilder
    private func menu(for character: PlayerCharacter) -> some View {
        Button("Renommer", systemImage: "pencil") {
            newName = character.displayName
            renaming = character
        }
        Button("Dupliquer", systemImage: "plus.square.on.square") {
            character.duplicate(in: context)
        }
        Button("Enregistrer comme template", systemImage: "doc.badge.plus") {
            let system = templates.first { $0.uid == character.sourceTemplateUID }?.system ?? ""
            character.makeTemplate(named: "\(character.displayName) — template", system: system, in: context)
        }
        Divider()
        Button("Supprimer", systemImage: "trash", role: .destructive) {
            deleting = character
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if characters.isEmpty {
            ContentUnavailableView {
                Label("Aucun personnage", systemImage: "person.2")
            } description: {
                Text("Crée un personnage à partir d'un template, ou une fiche vierge.")
            } actions: {
                Button("Nouveau personnage") { showingNew = true }
                    .buttonStyle(.borderedProminent)
            }
        } else if filtered.isEmpty {
            ContentUnavailableView.search(text: search)
        }
    }
}

/// Liaison « présenté » pour une alerte ou un dialogue piloté par un élément optionnel.
func isPresented<Item>(_ item: Binding<Item?>) -> Binding<Bool> {
    Binding(
        get: { item.wrappedValue != nil },
        set: { if !$0 { item.wrappedValue = nil } }
    )
}
