import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<CharacterLayout> { $0.isTemplate == true }, sort: \CharacterLayout.name) private var templates: [CharacterLayout]

    var body: some View {
        NavigationStack {
            List {
                ForEach(templates) { template in
                    NavigationLink {
                        TemplateEditorView(layout: template)
                            .navigationTitle(template.name)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(template.name)
                            HStack(spacing: 8) {
                                if let system = template.gameSystem, !system.isEmpty {
                                    Text(system)
                                }
                                Text("\(template.characters.count) character\(template.characters.count == 1 ? "" : "s")")
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteTemplates)
            }
            .overlay {
                if templates.isEmpty {
                    ContentUnavailableView("No Templates", systemImage: "doc.text", description: Text("Tap + to create a template."))
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { createTemplate() } label: {
                        Label("New", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func createTemplate() {
        let template = CharacterLayout(name: "New Template", isTemplate: true, gridColumns: 3)
        modelContext.insert(template)
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
    }
}
