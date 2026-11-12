import SwiftUI
import SwiftData
import SheetKit

/// Grille des personnages, du plus récemment modifié au plus ancien.
struct CharacterGrid: View {
    /// Ouvre une fiche (plein écran sur iPhone et iPad, poussée sur Mac).
    let open: (LibraryRoute) -> Void
    /// Source de la transition « zoom » d'une carte vers sa fiche.
    let transition: Namespace.ID
    /// Demande venue d'un menu (Nouveau, Importer) : traitée puis effacée.
    @Binding var request: LibraryRequest?

    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \PlayerCharacter.updatedAt, order: .reverse) private var characters: [PlayerCharacter]
    @Query(sort: \SheetTemplate.name) private var templates: [SheetTemplate]

    @State private var search = ""
    @State private var showingNew = false
    @State private var importing = false
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
            LazyVGrid(columns: LibraryGridLayout.columns(for: sizeClass), spacing: 16) {
                ForEach(filtered) { character in
                    Button {
                        open(.character(character))
                    } label: {
                        CharacterCard(character: character)
                    }
                    .buttonStyle(.plain)
                    .zoomTransitionSource(id: LibraryRoute.character(character), in: transition)
                    .contextMenu { menu(for: character) }
                }
            }
            .padding()
        }
        .background(Color.groupedBackground)
        .overlay { emptyState }
        .navigationTitle("Personnages")
        .searchable(text: $search, prompt: "Rechercher un personnage")
        .toolbar {
            Button("Importer", systemImage: "square.and.arrow.down") { importing = true }
            Menu {
                Button("Nouveau personnage", systemImage: "plus") { showingNew = true }
                ExampleButton()
            } label: {
                Label("Nouveau personnage", systemImage: "plus")
            } primaryAction: {
                showingNew = true
            }
        }
        .onChange(of: request, initial: true) { _, value in
            switch value {
            case .newCharacter: showingNew = true
            case .importFiles: importing = true
            default: return
            }
            request = nil
        }
        .sheetImporter(isPresented: $importing) { item in
            switch item {
            case .template(let template): open(.template(template))
            case .character(let character): open(.character(character))
            }
        }
        .sheet(isPresented: $showingNew) {
            NewCharacterView(templates: templates) { character in
                open(.character(character))
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
        ExportButton(file: SheetExportFile(character: character))
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
                Button("Importer un fichier") { importing = true }
                ExampleButton()
                    .labelStyle(.titleOnly)
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

/// Ajoute le template BRP et Leo, pour découvrir l'app sans tout saisir.
/// Rien n'est créé automatiquement : avec iCloud, chaque appareil créerait le sien (SPEC §5.10).
struct ExampleButton: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        Button("Ajouter l'exemple BRP", systemImage: "wand.and.stars") {
            withAnimation { _ = try? DemoData.addExample(in: context) }
        }
    }
}
