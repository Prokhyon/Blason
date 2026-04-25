import SwiftUI
import SwiftData

struct TemplateListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CharacterTemplate.name) private var templates: [CharacterTemplate]

    @State private var isPresentingNew = false
    @State private var draftTemplate: CharacterTemplate? = nil

    var body: some View {
        NavigationStack {
            List {
                ForEach(templates) { template in
                    NavigationLink {
                        TemplateEditorView(template: template)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(template.name)
                            if let system = template.gameSystem, !system.isEmpty {
                                Text(system).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            context.delete(template)
                            try? context.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { presentNewTemplate() } label: { Label("New", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $isPresentingNew) {
                if let draft = draftTemplate {
                    NavigationStack {
                        TemplateEditorView(template: draft)
                            .navigationTitle("New Template")
                            .toolbar {
                                ToolbarItem(placement: .cancellationAction) {
                                    Button("Cancel") { dismissNewTemplate() }
                                }
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Save") { saveNewTemplate() }
                                }
                            }
                    }
                }
            }
        }
    }

    private func presentNewTemplate() {
        let header = Section(title: "Header", order: 0, layout: .list, fields: [
            Field(label: "Name", kind: .text, order: 0),
            Field(label: "Age", kind: .integer, order: 1, minValue: 0, maxValue: 500, step: 1)
        ])
        draftTemplate = CharacterTemplate(name: "New Template", header: header)
        isPresentingNew = true
    }

    private func dismissNewTemplate() {
        draftTemplate = nil
        isPresentingNew = false
    }

    private func saveNewTemplate() {
        guard let draft = draftTemplate else { return }
        context.insert(draft)
        try? context.save()
        dismissNewTemplate()
    }
}

#Preview("Template List") {
    TemplateListView()
        .modelContainer(for: [Character.self, CharacterTemplate.self, Section.self, Field.self, CharacterFieldValue.self], inMemory: true)
}
