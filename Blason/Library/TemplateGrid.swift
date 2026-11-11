import SwiftUI
import SwiftData
import SheetKit

/// Grille des templates, par ordre alphabétique.
struct TemplateGrid: View {
    @Binding var path: NavigationPath

    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \SheetTemplate.name) private var templates: [SheetTemplate]
    @Query private var characters: [PlayerCharacter]

    @State private var search = ""
    @State private var showingNew = false
    @State private var importing = false
    @State private var renaming: SheetTemplate?
    @State private var newName = ""
    @State private var deleting: SheetTemplate?
    @State private var errorMessage: String?

    private var filtered: [SheetTemplate] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return templates }
        return templates.filter {
            $0.name.localizedStandardContains(query) || $0.system.localizedStandardContains(query)
        }
    }

    /// Nombre de personnages créés à partir de chaque template.
    private var usage: [UUID: Int] {
        Dictionary(grouping: characters.compactMap(\.sourceTemplateUID), by: { $0 }).mapValues(\.count)
    }

    var body: some View {
        let usage = usage
        ScrollView {
            LazyVGrid(columns: LibraryGridLayout.columns(for: sizeClass), spacing: 16) {
                ForEach(filtered) { template in
                    NavigationLink(value: template) {
                        TemplateCard(template: template, characterCount: usage[template.uid] ?? 0)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { menu(for: template) }
                }
            }
            .padding()
        }
        .background(Color.groupedBackground)
        .overlay { emptyState }
        .navigationTitle("Templates")
        .searchable(text: $search, prompt: "Rechercher un template")
        .toolbar {
            Button("Importer", systemImage: "square.and.arrow.down") { importing = true }
            Menu {
                Button("Nouveau template", systemImage: "plus") { showingNew = true }
                ExampleButton()
            } label: {
                Label("Nouveau template", systemImage: "plus")
            } primaryAction: {
                showingNew = true
            }
        }
        .sheetImporter(isPresented: $importing) { item in
            switch item {
            case .template(let template): path.append(template)
            case .character(let character): path.append(character)
            }
        }
        .sheet(isPresented: $showingNew) {
            NewTemplateView { template in
                path.append(template)
            }
        }
        .alert("Renommer le template", isPresented: isPresented($renaming)) {
            TextField("Nom", text: $newName)
            Button("Renommer") {
                do {
                    try renaming?.rename(to: newName, in: context)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            Button("Annuler", role: .cancel) {}
        }
        .confirmationDialog(
            "Supprimer « \(deleting?.name ?? "") » ?",
            isPresented: isPresented($deleting),
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let deleting { context.delete(deleting) }
            }
        } message: {
            Text("Les personnages déjà créés à partir de ce template sont conservés. Cette action est définitive.")
        }
        .alert("Une erreur est survenue", isPresented: isPresented($errorMessage)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func menu(for template: SheetTemplate) -> some View {
        Button("Nouveau personnage", systemImage: "person.badge.plus") {
            let character = template.makeCharacter(named: "Nouveau personnage", in: context)
            path.append(character)
        }
        Button("Renommer", systemImage: "pencil") {
            newName = template.name
            renaming = template
        }
        Button("Dupliquer", systemImage: "plus.square.on.square") {
            template.duplicate(in: context)
        }
        ExportButton(file: SheetExportFile(template: template))
        Divider()
        Button("Supprimer", systemImage: "trash", role: .destructive) {
            deleting = template
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if templates.isEmpty {
            ContentUnavailableView {
                Label("Aucun template", systemImage: "doc.on.doc")
            } description: {
                Text("Un template décrit la fiche d'un système de jeu. Il sert ensuite à créer des personnages.")
            } actions: {
                Button("Nouveau template") { showingNew = true }
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
