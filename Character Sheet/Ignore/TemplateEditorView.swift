import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    @Environment(\.modelContext) private var context

    @Bindable var template: CharacterTemplate

    @State private var isAddingSection = false
    @State private var newSectionTitle = ""
    @State private var selectedSectionID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("Template Info") {
                    TextField("Template name", text: $template.name)
                    TextField("Game system (optional)", text: Binding(
                        get: { template.gameSystem ?? "" },
                        set: { template.gameSystem = $0.isEmpty ? nil : $0 }
                    ))
                }

                TemplateSectionEditor(title: "Header", section: $template.header)

                Section(header: HStack {
                    Text("Sections")
                    Spacer()
                    Button(action: { isAddingSection = true }) {
                        Label("Add Section", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }) {
                    if template.sections.isEmpty {
                        Text("No sections yet").foregroundStyle(.secondary)
                    } else {
                        ForEach($template.sections) { $section in
                            NavigationLink(value: section.id) {
                                HStack {
                                    Text(section.title)
                                    Spacer()
                                    Text(section.layout.rawValue.capitalized)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteSection(section)
                                } label: {
                                    Label("Delete Section", systemImage: "trash")
                                }
                            }
                        }
                        .onMove(perform: moveSections)
                        .onDelete(perform: deleteSections)
                    }
                }
            }
            .navigationTitle("Edit Template")
            .toolbar { EditButton() }
            .sheet(isPresented: $isAddingSection) {
                NavigationStack {
                    Form {
                        TextField("Section title", text: $newSectionTitle)
                        Picker("Layout", selection: Binding(
                            get: { draftLayout },
                            set: { draftLayout = $0 }
                        )) {
                            ForEach(SectionLayout.allCases, id: \.self) { layout in
                                Text(layout.rawValue.capitalized).tag(layout)
                            }
                        }
                    }
                    .navigationTitle("New Section")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { isAddingSection = false; resetDraft() }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") { addSection() }
                                .disabled(newSectionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let index = template.sections.firstIndex(where: { $0.id == id }) {
                    TemplateSectionEditor(title: template.sections[index].title, section: $template.sections[index])
                        .navigationTitle(template.sections[index].title)
                } else {
                    Text("Section not found").foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Section Draft State
    @State private var draftLayout: SectionLayout = .list

    private func resetDraft() {
        newSectionTitle = ""
        draftLayout = .list
    }

    // MARK: - Actions
    private func addSection() {
        let order = template.sections.count
        let section = Section(title: newSectionTitle, order: order, layout: draftLayout, fields: [])
        template.sections.append(section)
        resetDraft()
        isAddingSection = false
    }

    private func deleteSection(_ section: Section) {
        if let idx = template.sections.firstIndex(where: { $0.id == section.id }) {
            template.sections.remove(at: idx)
            renumberSections()
        }
    }

    private func deleteSections(at offsets: IndexSet) {
        template.sections.remove(atOffsets: offsets)
        renumberSections()
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        template.sections.move(fromOffsets: source, toOffset: destination)
        renumberSections()
    }

    private func renumberSections() {
        for (idx, section) in template.sections.enumerated() {
            section.order = idx
        }
    }
}

// MARK: - Section Editor
struct TemplateSectionEditor: View {
    var title: String
    @Binding var section: Section

    @State private var isAddingField = false

    var body: some View {
        Section(title) {
            TextField("Section title", text: $section.title)
            Picker("Layout", selection: $section.layout) {
                ForEach(SectionLayout.allCases, id: \.self) { layout in
                    Text(layout.rawValue.capitalized).tag(layout)
                }
            }

            if section.fields.isEmpty {
                Text("No fields yet").foregroundStyle(.secondary)
            } else {
                ForEach($section.fields) { $field in
                    NavigationLink(destination: FieldEditor(field: $field)) {
                        VStack(alignment: .leading) {
                            Text(field.label)
                            Text(field.kind.rawValue.capitalized)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove(perform: moveFields)
                .onDelete(perform: deleteFields)
            }

            Button { isAddingField = true } label: {
                Label("Add Field", systemImage: "plus")
            }
        }
        .sheet(isPresented: $isAddingField) {
            NavigationStack {
                FieldEditor(field: .constant(Field(label: "", kind: .text, order: section.fields.count))) { newField in
                    section.fields.append(newField)
                    renumberFields()
                    isAddingField = false
                } onCancel: {
                    isAddingField = false
                }
            }
        }
    }

    private func deleteFields(at offsets: IndexSet) {
        section.fields.remove(atOffsets: offsets)
        renumberFields()
    }

    private func moveFields(from source: IndexSet, to destination: Int) {
        section.fields.move(fromOffsets: source, toOffset: destination)
        renumberFields()
    }

    private func renumberFields() {
        for (idx, field) in section.fields.enumerated() {
            field.order = idx
        }
    }
}

// MARK: - Field Editor
struct FieldEditor: View {
    @Binding var field: Field

    var onSave: ((Field) -> Void)?
    var onCancel: (() -> Void)?

    @State private var localField: Field

    init(field: Binding<Field>, onSave: ((Field) -> Void)? = nil, onCancel: (() -> Void)? = nil) {
        self._field = field
        self.onSave = onSave
        self.onCancel = onCancel
        _localField = State(initialValue: field.wrappedValue)
    }

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Label", text: $localField.label)
                TextField("Hint (optional)", text: Binding(
                    get: { localField.hint ?? "" },
                    set: { localField.hint = $0.isEmpty ? nil : $0 }
                ))
                Picker("Kind", selection: $localField.kind) {
                    ForEach(FieldKind.allCases, id: \.self) { kind in
                        Text(kind.rawValue.capitalized).tag(kind)
                    }
                }
            }

            Section("Constraints & Defaults") {
                switch localField.kind {
                case .integer, .decimal:
                    HStack {
                        Text("Min")
                        TextField("Min", text: Binding(
                            get: { localField.minValue.map { String($0) } ?? "" },
                            set: { localField.minValue = Double($0) }
                        )).keyboardType(.numbersAndPunctuation)
                        Text("Max")
                        TextField("Max", text: Binding(
                            get: { localField.maxValue.map { String($0) } ?? "" },
                            set: { localField.maxValue = Double($0) }
                        )).keyboardType(.numbersAndPunctuation)
                        Text("Step")
                        TextField("Step", text: Binding(
                            get: { localField.step.map { String($0) } ?? "" },
                            set: { localField.step = Double($0) }
                        )).keyboardType(.numbersAndPunctuation)
                    }
                default:
                    EmptyView()
                }

                if localField.kind == .option || localField.kind == .multiOption {
                    TextField("Options (comma separated)", text: Binding(
                        get: { (localField.options ?? []).joined(separator: ",") },
                        set: { localField.options = $0.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } }
                    ))
                }

                TextField("Default value", text: Binding(
                    get: { localField.defaultValue ?? "" },
                    set: { localField.defaultValue = $0.isEmpty ? nil : $0 }
                ))
            }

            Section("Layout") {
                HStack {
                    Text("Weight")
                    TextField("Weight", text: Binding(
                        get: { localField.layoutWeight.map { String($0) } ?? "" },
                        set: { localField.layoutWeight = Double($0) }
                    ))
                    .keyboardType(.numbersAndPunctuation)
                }
            }
        }
        .navigationTitle("Field")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel?() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(localField.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func save() {
        // Write local edits back to the binding
        field.label = localField.label
        field.hint = localField.hint
        field.kind = localField.kind
        field.minValue = localField.minValue
        field.maxValue = localField.maxValue
        field.step = localField.step
        field.defaultValue = localField.defaultValue
        field.options = localField.options
        field.layoutWeight = localField.layoutWeight
        onSave?(field)
    }
}

#Preview("Template Editor") {
    let header = Section(title: "Header", order: 0, layout: .list, fields: [
        Field(label: "Name", kind: .text, order: 0),
        Field(label: "Age", kind: .integer, order: 1, minValue: 0, maxValue: 500, step: 1, defaultValue: "25")
    ])

    let attributes = Section(title: "Attributes", order: 0, layout: .grid, fields: [
        Field(label: "Strength", kind: .integer, order: 0, minValue: 1, maxValue: 20, step: 1, defaultValue: "10"),
        Field(label: "Dexterity", kind: .integer, order: 1, minValue: 1, maxValue: 20, step: 1, defaultValue: "10")
    ])

    let template = CharacterTemplate(name: "Fantasy (Generic)", gameSystem: "Generic", header: header, sections: [attributes])

    return TemplateEditorView(template: template)
        .modelContainer(for: [Character.self, CharacterTemplate.self, Section.self, Field.self, CharacterFieldValue.self], inMemory: true)
}
