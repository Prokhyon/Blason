import SwiftUI
import SwiftData

struct TemplateEditorView: View {
    @Bindable var layout: CharacterLayout

    @State private var showingAddSection = false

    var body: some View {
        Form {
            Section("Info") {
                TextField("Name", text: $layout.name)
                TextField("Game System", text: Binding(
                    get: { layout.gameSystem ?? "" },
                    set: { layout.gameSystem = $0.isEmpty ? nil : $0 }
                ))
                Stepper("Columns: \(layout.gridColumns)", value: $layout.gridColumns, in: 1...6)
                    .onChange(of: layout.gridColumns) {
                        for section in layout.sections where section.width > layout.gridColumns {
                            section.width = layout.gridColumns
                        }
                        layout.recalculateGrid()
                    }
            }

            Section(header: HStack {
                Text("Sections")
                Spacer()
                Button { showingAddSection = true } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }) {
                if layout.sections.isEmpty {
                    Text("No sections yet").foregroundStyle(.secondary)
                } else {
                    ForEach(layout.sortedSections) { section in
                        NavigationLink {
                            SectionEditorView(section: section, layout: layout)
                        } label: {
                            HStack {
                                Text(section.title)
                                Spacer()
                                Text("\(section.width)x\(section.height)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onMove(perform: moveSections)
                    .onDelete(perform: deleteSections)
                }
            }

            Section("Preview") {
                GridPreview(layout: layout)
                    .frame(minHeight: 200)
            }
        }
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showingAddSection) {
            AddSectionView(layout: layout)
        }
    }

    private func moveSections(from source: IndexSet, to destination: Int) {
        var sorted = layout.sortedSections
        sorted.move(fromOffsets: source, toOffset: destination)
        for (idx, section) in sorted.enumerated() {
            section.order = idx
        }
        layout.recalculateGrid()
    }

    private func deleteSections(at offsets: IndexSet) {
        let sorted = layout.sortedSections
        for index in offsets {
            let sectionToDelete = sorted[index]
            layout.sections.removeAll { $0.id == sectionToDelete.id }
        }
        layout.renumberSections()
        layout.recalculateGrid()
    }
}

struct GridPreview: View {
    var layout: CharacterLayout

    var body: some View {
        GeometryReader { geometry in
            let cols = max(layout.gridColumns, 1)
            let cellSize = (geometry.size.width - CGFloat(cols - 1) * gridSpacing) / CGFloat(cols)

            SpanningGridLayout(columns: cols, cellSize: cellSize, spacing: gridSpacing) {
                ForEach(layout.sortedSections) { section in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Text(section.title)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .layoutValue(key: GridItemKey.self, value: section.gridPlacement)
                }
            }
        }
    }
}

struct AddSectionView: View {
    @Environment(\.dismiss) private var dismiss
    var layout: CharacterLayout

    @State private var title = ""
    @State private var width = 1
    @State private var height = 1
    @State private var sectionLayout: SectionLayout = .list
    @State private var columnCount = 2

    var body: some View {
        NavigationStack {
            Form {
                TextField("Section Title", text: $title)
                Stepper("Width: \(width)", value: $width, in: 1...layout.gridColumns)
                Stepper("Height: \(height)", value: $height, in: 1...10)
                Picker("Layout", selection: $sectionLayout) {
                    ForEach(SectionLayout.allCases, id: \.self) { l in
                        Text(l.displayName).tag(l)
                    }
                }
                if sectionLayout == .multiList {
                    Stepper("Lists: \(columnCount)", value: $columnCount, in: 1...6)
                }
            }
            .navigationTitle("Add Section")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let section = LayoutSection(
                            title: title,
                            order: layout.sections.count,
                            width: width,
                            height: height,
                            sectionLayout: sectionLayout
                        )
                        if sectionLayout == .multiList || sectionLayout == .grid {
                            section.columnCount = columnCount
                        }
                        layout.sections.append(section)
                        layout.recalculateGrid()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct SectionEditorView: View {
    @Bindable var section: LayoutSection
    var layout: CharacterLayout

    @State private var showingAddField = false
    @State private var addFieldColumn = 0

    var body: some View {
        Form {
            Section("Section Info") {
                TextField("Title", text: $section.title)
                Stepper("Width: \(section.width)", value: $section.width, in: 1...layout.gridColumns)
                    .onChange(of: section.width) { layout.recalculateGrid() }
                Stepper("Height: \(section.height)", value: $section.height, in: 1...10)
                    .onChange(of: section.height) { layout.recalculateGrid() }
                Picker("Layout", selection: $section.sectionLayout) {
                    ForEach(SectionLayout.allCases, id: \.self) { l in
                        Text(l.displayName).tag(l)
                    }
                }
                if section.sectionLayout == .multiList || section.sectionLayout == .grid {
                    let label = section.sectionLayout == .multiList ? "Lists" : "Columns"
                    Stepper("\(label): \(section.columnCount ?? 2)", value: Binding(
                        get: { section.columnCount ?? 2 },
                        set: { newValue in
                            let clamped = min(max(newValue, 1), 6)
                            section.columnCount = clamped
                            if section.sectionLayout == .multiList {
                                for field in section.fields where field.multilistColumn >= clamped {
                                    field.multilistColumn = clamped - 1
                                }
                            }
                        }
                    ), in: 1...6)
                }
            }

            if section.sectionLayout == .multiList {
                multiListFieldSections
            } else {
                flatFieldSection
            }
        }
        .navigationTitle(section.title)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showingAddField) {
            AddFieldView(section: section, targetColumn: addFieldColumn)
        }
    }

    @ViewBuilder
    private var multiListFieldSections: some View {
        let listCount = max(1, section.columnCount ?? 2)
        ForEach(0..<listCount, id: \.self) { col in
            Section(header: HStack {
                Text("List \(col + 1)")
                Spacer()
                Button {
                    addFieldColumn = col
                    showingAddField = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderless)
            }) {
                let colFields = section.sortedFields.filter { $0.multilistColumn == col }
                if colFields.isEmpty {
                    Text("No fields yet").foregroundStyle(.secondary)
                } else {
                    ForEach(colFields) { field in
                        NavigationLink {
                            FieldEditorFormView(field: field, listCount: listCount)
                        } label: {
                            fieldRow(for: field)
                        }
                        .contextMenu {
                            ForEach(0..<listCount, id: \.self) { targetCol in
                                if targetCol != col {
                                    Button("Move to List \(targetCol + 1)") {
                                        field.multilistColumn = targetCol
                                        field.order = section.fields.filter { $0.multilistColumn == targetCol && $0.id != field.id }.count
                                        section.renumberFields()
                                    }
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        let colFields = section.sortedFields.filter { $0.multilistColumn == col }
                        for index in offsets {
                            section.fields.removeAll { $0.id == colFields[index].id }
                        }
                        section.renumberFields()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var flatFieldSection: some View {
        Section(header: HStack {
            Text("Fields")
            Spacer()
            Button {
                addFieldColumn = 0
                showingAddField = true
            } label: {
                Label("Add", systemImage: "plus")
            }
            .buttonStyle(.borderless)
        }) {
            if section.fields.isEmpty {
                Text("No fields yet").foregroundStyle(.secondary)
            } else {
                ForEach(section.sortedFields) { field in
                    NavigationLink {
                        FieldEditorFormView(field: field)
                    } label: {
                        fieldRow(for: field)
                    }
                }
                .onMove(perform: moveFields)
                .onDelete(perform: deleteFields)
            }
        }
    }

    private func fieldRow(for field: Field) -> some View {
        VStack(alignment: .leading) {
            Text(field.label)
            HStack(spacing: 4) {
                Text(field.kind.rawValue.capitalized)
                if field.liveValue {
                    Text("· Always editable")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func moveFields(from source: IndexSet, to destination: Int) {
        var sorted = section.sortedFields
        sorted.move(fromOffsets: source, toOffset: destination)
        for (idx, field) in sorted.enumerated() {
            field.order = idx
        }
    }

    private func deleteFields(at offsets: IndexSet) {
        let sorted = section.sortedFields
        for index in offsets {
            section.fields.removeAll { $0.id == sorted[index].id }
        }
        section.renumberFields()
    }
}

struct AddFieldView: View {
    @Environment(\.dismiss) private var dismiss
    var section: LayoutSection
    var targetColumn: Int = 0

    @State private var label = ""
    @State private var kind: FieldKind = .text
    @State private var fieldLayout: FieldLayout = .horizontal
    @State private var liveValue = false
    @State private var defaultValue = ""
    @State private var hint = ""
    @State private var minValue = ""
    @State private var maxValue = ""
    @State private var displayMaxValue = false
    @State private var step = ""
    @State private var unit = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Basics") {
                    TextField("Label", text: $label)
                    TextField("Hint", text: $hint)
                    Picker("Kind", selection: $kind) {
                        ForEach(FieldKind.allCases, id: \.self) { k in
                            Text(k.rawValue.capitalized).tag(k)
                        }
                    }
                    TextField("Unit", text: $unit)
                    Picker("Layout", selection: $fieldLayout) {
                        ForEach(FieldLayout.allCases, id: \.self) { l in
                            Text(l.rawValue.capitalized).tag(l)
                        }
                    }
                    Toggle("Always Editable", isOn: $liveValue)
                }

                if kind == .integer || kind == .decimal || kind == .modifier {
                    Section("Constraints") {
                        TextField("Min", text: $minValue).keyboardType(.numbersAndPunctuation)
                        TextField("Max", text: $maxValue).keyboardType(.numbersAndPunctuation)
                        Toggle("Display Max value", isOn: $displayMaxValue)
                        TextField("Step", text: $step).keyboardType(.numbersAndPunctuation)
                    }
                }

                Section("Default") {
                    TextField("Default Value", text: $defaultValue)
                }
            }
            .navigationTitle("Add Field")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let orderValue: Int
                        if section.sectionLayout == .multiList {
                            orderValue = section.fields.filter { $0.multilistColumn == targetColumn }.count
                        } else {
                            orderValue = section.fields.count
                        }
                        let field = Field(
                            label: label,
                            order: orderValue,
                            kind: kind,
                            unit: unit,
                            fieldLayout: fieldLayout,
                            minValue: Int(minValue),
                            maxValue: Int(maxValue),
                            displayMaxValue: displayMaxValue,
                            step: Int(step),
                            defaultValue: defaultValue.isEmpty ? nil : defaultValue,
                            hint: hint.isEmpty ? nil : hint,
                            liveValue: liveValue,
                            column: targetColumn
                        )
                        section.fields.append(field)
                        dismiss()
                    }
                    .disabled(label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct FieldEditorFormView: View {
    @Bindable var field: Field
    var listCount: Int = 0

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Label", text: $field.label)
                TextField("Hint", text: Binding(
                    get: { field.hint ?? "" },
                    set: { field.hint = $0.isEmpty ? nil : $0 }
                ))
                Picker("Kind", selection: $field.kind) {
                    ForEach(FieldKind.allCases, id: \.self) { k in
                        Text(k.rawValue.capitalized).tag(k)
                    }
                }
                TextField("unit", text: Binding(
                    get: { field.unit ?? "" },
                    set: { field.unit = $0.isEmpty ? nil : $0 }
                ))
                Picker("Layout", selection: $field.fieldLayout) {
                    ForEach(FieldLayout.allCases, id: \.self) { l in
                        Text(l.rawValue.capitalized).tag(l)
                    }
                }
                Toggle("Always Editable", isOn: $field.liveValue)
                if listCount > 1 {
                    Picker("List", selection: $field.multilistColumn) {
                        ForEach(0..<listCount, id: \.self) { col in
                            Text("List \(col + 1)").tag(col)
                        }
                    }
                }
            }

            if field.kind == .integer || field.kind == .decimal || field.kind == .modifier {
                Section("Constraints") {
                    HStack {
                        Text("Min")
                        TextField("", text: Binding(
                            get: { field.minValue.map(String.init) ?? "" },
                            set: { field.minValue = Int($0) }
                        ))
                        .keyboardType(.numbersAndPunctuation)
                    }
                    HStack {
                        Text("Max")
                        TextField("", text: Binding(
                            get: { field.maxValue.map(String.init) ?? "" },
                            set: { field.maxValue = Int($0) }
                        ))
                        .keyboardType(.numbersAndPunctuation)
                    }
                    Toggle("Display Max value", isOn: $field.displayMaxValue)
                    HStack {
                        Text("Step")
                        TextField("", text: Binding(
                            get: { field.step.map(String.init) ?? "" },
                            set: { field.step = Int($0) }
                        ))
                        .keyboardType(.numbersAndPunctuation)
                    }
                }
            }

            Section("Default") {
                TextField("Default Value", text: Binding(
                    get: { field.defaultValue ?? "" },
                    set: { field.defaultValue = $0.isEmpty ? nil : $0 }
                ))
            }
        }
        .navigationTitle(field.label)
    }
}
