import SwiftUI
import SwiftData

struct CharacterSheetView: View {
    @Bindable var character: Character
    @State var isEditing: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let template = character.template {

                    // Other sections
                    ForEach(template.sections.sorted { $0.order < $1.order }) { section in
                        SectionHeaderView(title: section.title)
                        SectionView(section: section, values: $character.fieldValues, isEditing: $isEditing)
                    }
                } else {
                    Text("No template assigned").foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(character.fullName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
            }
        }
    }
}

private struct SectionHeaderView: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SectionView: View {
    let section: Section
    @Binding var values: [CharacterFieldValue]
    @Binding var isEditing: Bool

    var body: some View {
        switch section.layout {
        case .list:
            VStack(spacing: 12) {
                ForEach(section.fields.sorted { $0.order < $1.order }) { field in
                    FieldValueEditor(field: field, isEditing: $isEditing, value: binding(for: field))
                }
            }
        case .grid:
            LazyVGrid(columns: gridColumns(for: section), spacing: 12) {
                ForEach(section.fields.sorted { $0.order < $1.order }) { field in
                    FieldValueEditor(field: field, isEditing: $isEditing, value: binding(for: field))
                }
            }
        }
    }

    private func gridColumns(for section: Section) -> [GridItem] {
        // Simple heuristic: weight >= 1 means double width; default single.
        // We compute up to 2 columns for now.
        return [GridItem(.flexible()), GridItem(.flexible())]
    }

    private func binding(for field: Field) -> Binding<CharacterFieldValue> {
        if let idx = values.firstIndex(where: { $0.field?.id == field.id }) {
            return $values[idx]
        }
        // If missing, append a new one
        let new = CharacterFieldValue(field: field, value: field.defaultValue)
        values.append(new)
        return $values[values.count - 1]
    }
}

private struct FieldValueEditor: View {
    let field: Field
    @Binding var isEditing: Bool
    @Binding var value: CharacterFieldValue
    var layout: FieldLayout = .horizontal
    @State private var editing: Bool = false

    private var isFieldEditable: Bool {
        isEditing || field.liveValue
    }

    var body: some View {
        if layout == .vertical {
            VStack(alignment: .leading, spacing: 6) {
                Text(field.label)
                    .font(.subheadline)
                fieldValue.disabled(!isFieldEditable)
            }
        } else {
            HStack {
                Text(field.label)
                    .font(.subheadline)
                fieldValue
            }
            .frame(height: 25)
        }
    }

    @ViewBuilder
    private var fieldValue: some View {
        switch field.kind {
        case .text, .note:
            if isEditing {
                TextField(field.hint ?? "", text: Binding(
                    get: { value.value ?? "" },
                    set: { value.value = $0 }
                ))
                .textFieldStyle(.roundedBorder)
//                .frame(maxWidth: .infinity)
//                .frame(minHeight: field.kind == .note ? 120 : nil, alignment: .topLeading)
            } else {
                Text("\(value.value ?? "")")
            }
            
        case .integer:
            if isEditing {
                StepperWithText(
                    value: Binding(
                        get: { Int(value.value ?? field.defaultValue ?? "0") ?? 0 },
                        set: { value.value = String($0) }
                    ),
                    range: intRange,
                    step: intStep
                )
            } else {
                Text("\(value.value ?? field.defaultValue ?? "0")")
            }
            
        case .decimal:
            TextField(field.hint ?? "", text: Binding(
                get: { value.value ?? field.defaultValue ?? "" },
                set: { value.value = $0 }
            ))
            .keyboardType(.numbersAndPunctuation)
            .textFieldStyle(.roundedBorder)
            
        case .modifier:
            StepperWithText(
                value: Binding(
                    get: { Int(value.value ?? field.defaultValue ?? "0") ?? 0 },
                    set: { value.value = String($0) }
                ),
                range: intRange,
                step: intStep
            )
            
        case .boolean:
            Toggle(isOn: Binding(
                get: { (value.value ?? field.defaultValue ?? "false").lowercased() == "true" },
                set: { value.value = $0 ? "true" : "false" }
            )) {
                EmptyView()
            }
            
        case .date:
            DatePicker("", selection: Binding(
                get: { dateValue },
                set: { value.value = isoFormatter.string(from: $0) }
            ), displayedComponents: .date)
            .labelsHidden()
            
        case .option:
            if isEditing {
                Picker("", selection: Binding(
                    get: { value.value ?? field.defaultValue ?? (field.options?.first ?? "") },
                    set: { value.value = $0 }
                )) {
                    ForEach(field.options ?? [], id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
            } else {
                Text(value.value ?? field.defaultValue ?? (field.options?.first ?? ""))
            }
            
        case .multiOption:
            VStack(alignment: .leading) {
                ForEach(field.options ?? [], id: \.self) { option in
                    Toggle(option, isOn: Binding(
                        get: { selectedOptions.contains(option) },
                        set: { toggleOption(option, $0) }
                    ))
                }
            }
        }
    }

    private var intRange: ClosedRange<Int> {
        let min = Int(field.minValue ?? 0)
        let max = Int(field.maxValue ?? 100)
        return min...max
    }

    private var intStep: Int {
        Int(field.step ?? 1)
    }

    private var selectedOptions: Set<String> {
        let raw = value.value ?? field.defaultValue ?? ""
        return Set(raw.split(separator: ",").map { String($0) })
    }

    private func toggleOption(_ option: String, _ isOn: Bool) {
        var set = selectedOptions
        if isOn { set.insert(option) } else { set.remove(option) }
        value.value = set.sorted().joined(separator: ",")
    }

    private var dateValue: Date {
        if let raw = value.value, let date = isoFormatter.date(from: raw) { return date }
        if let def = field.defaultValue, let date = isoFormatter.date(from: def) { return date }
        return Date()
    }
}

private let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withFullDate]
    return f
}()

private struct StepperWithText: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack {
                Stepper(value: $value, in: range, step: step) {
                    EmptyView()
                }
                
                TextField("", value: $value, formatter: NumberFormatter())
//                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
        }
    }
}

#Preview("Character Sheet") {
    let header = Section(title: "Header", order: 0, layout: .list, fields: [
        Field(label: "Name", kind: .text, order: 0),
        Field(label: "Age", kind: .integer, order: 1, minValue: 0, maxValue: 120, step: 1, defaultValue: "25"),
        Field(label: "Class and Race", kind: .text, order: 1, defaultValue: "Longer text test")
    ])
    let attributes = Section(title: "Attributes", order: 0, layout: .grid, fields: [
        Field(label: "Strength", kind: .integer, order: 0, minValue: 1, maxValue: 20, step: 1, defaultValue: "10"),
        Field(label: "Dexterity", kind: .integer, order: 1, minValue: 1, maxValue: 20, step: 1, defaultValue: "10"),
        Field(label: "Option", kind: .option, order: 2, options: ["A", "B", "C"])
    ])
    let template = CharacterTemplate(name: "Fantasy", sections: [header, attributes])
    let character = Character(template: template)
    return NavigationStack { CharacterSheetView(character: character) }
        .modelContainer(for: [Character.self, CharacterTemplate.self, Section.self, Field.self, CharacterFieldValue.self], inMemory: true)
}
