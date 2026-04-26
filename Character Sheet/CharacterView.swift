import SwiftUI
import SwiftData

struct CharacterView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var character: Character

    @State private var editValues = false
    @State private var editLayout = false
    @State private var showTemplateWarning = false
    @State private var showTemplatePicker = false

    var body: some View {
        Group {
            if let layout = character.layout {
                characterSheet(layout: layout)
            } else {
                noLayoutView
            }
        }
        .navigationTitle(character.fullName)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if character.layout != nil {
                    Menu {
                        if editValues {
                            Button("Edit Layout") {
                                openLayoutEditor()
                            }
                        }
                        if let layout = character.layout, !layout.isTemplate {
                            Button("Save as Template") {
                                layout.isTemplate = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }

                    Button {
                        withAnimation { editValues.toggle() }
                    } label: {
                        Image(systemName: editValues ? "pencil.slash" : "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $editLayout) {
            layoutEditorSheet
        }
        .sheet(isPresented: $showTemplatePicker) {
            TemplatePicker(character: character)
        }
        .alert("Shared Template", isPresented: $showTemplateWarning) {
            Button("Edit Template") { editLayout = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            let count = max((character.layout?.characters.count ?? 1) - 1, 0)
            Text("This layout is a shared template used by \(count) other character\(count == 1 ? "" : "s"). Changes will affect all of them.")
        }
        .task {
            character.ensureFieldValues()
            character.layout?.recalculateGrid()
        }
    }

    private func openLayoutEditor() {
        if let layout = character.layout, layout.isTemplate, layout.characters.count > 1 {
            showTemplateWarning = true
        } else {
            editLayout = true
        }
    }

    @ViewBuilder
    private func characterSheet(layout: CharacterLayout) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    if editValues {
                        characterInfoSection
                    }

                    let cellSize = (geometry.size.width - CGFloat(layout.gridColumns - 1) * gridSpacing) / CGFloat(layout.gridColumns)

                    SpanningGridLayout(columns: layout.gridColumns, cellSize: cellSize, spacing: gridSpacing) {
                        ForEach(layout.sortedSections) { section in
                            SectionCardView(section: section, character: character, editValues: editValues)
                                .layoutValue(key: GridItemKey.self, value: section)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var characterInfoSection: some View {
        VStack(spacing: 8) {
            TextField("First Name", text: Binding(
                get: { character.firstName ?? "" },
                set: { character.firstName = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)

            TextField("Last Name", text: Binding(
                get: { character.lastName ?? "" },
                set: { character.lastName = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var layoutEditorSheet: some View {
        if let layout = character.layout {
            NavigationStack {
                TemplateEditorView(layout: layout)
                    .navigationTitle("Edit Layout")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                layout.recalculateGrid()
                                character.ensureFieldValues()
                                editLayout = false
                            }
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var noLayoutView: some View {
        ContentUnavailableView {
            Label("No Layout", systemImage: "rectangle.grid.3x2")
        } description: {
            Text("This character has no layout assigned.")
        } actions: {
            Button("Create New Layout") {
                let layout = CharacterLayout(name: "\(character.fullName)'s Layout", gridColumns: 3)
                modelContext.insert(layout)
                character.layout = layout
                editLayout = true
            }

            Button("Choose Template") {
                showTemplatePicker = true
            }
        }
    }
}

struct TemplatePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<CharacterLayout> { $0.isTemplate == true }, sort: \CharacterLayout.name) private var templates: [CharacterLayout]
    var character: Character

    var body: some View {
        NavigationStack {
            List {
                if templates.isEmpty {
                    Text("No templates available. Create one in the Templates tab.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(templates) { template in
                        Button {
                            character.layout = template
                            character.ensureFieldValues()
                            dismiss()
                        } label: {
                            VStack(alignment: .leading) {
                                Text(template.name)
                                if let system = template.gameSystem, !system.isEmpty {
                                    Text(system).font(.footnote).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CharacterView(character: Character(firstName: "Preview", lastName: "Character"))
    }
    .modelContainer(for: [Character.self, CharacterLayout.self, LayoutSection.self, Field.self, CharacterFieldValue.self], inMemory: true)
}
