import SwiftUI

struct SectionCardView: View {
    var section: LayoutSection
    var character: Character
    var editValues: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color(.systemGray6))
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(section.title)
                        .font(.headline)

                    if section.fields.isEmpty {
                        Text("No fields")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else {
                        switch section.sectionLayout {
                        case .list:
                            // Use a Grid to allow items to expand horizontally with equal spacing
                            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                                ForEach(section.sortedFields) { field in
                                    GridRow {
                                        FieldValueRow(field: field, character: character, editValues: editValues)
                                            .gridCellColumns(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                        case .grid:
                            let columnCount = max(1, section.columnCount ?? 2)
                            let columns = Array(repeating: GridItem(.flexible(minimum: 80), spacing: 8, alignment: .topLeading), count: columnCount)

                            VStack(spacing: 12) {
                                if editValues {
                                    HStack(spacing: 8) {
                                        Text("Columns")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Stepper(value: Binding(
                                            get: { section.columnCount ?? 2 },
                                            set: { newValue in
                                                let clamped = min(max(newValue, 1), 6)
                                                section.columnCount = clamped
                                            }
                                        ), in: 1...6) {
                                            Text("\(section.columnCount ?? 2)")
                                                .monospacedDigit()
                                        }
                                    }
                                }

                                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                                    ForEach(section.sortedFields) { field in
                                        FieldValueRow(field: field, character: character, editValues: editValues)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                        case .multiList:
                            let listCount = max(1, section.columnCount ?? 2)
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(0..<listCount, id: \.self) { col in
                                    if col > 0 {
                                        Divider()
                                            .padding(.horizontal, 6)
                                    }
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(section.sortedFields.filter { $0.multilistColumn == col }) { field in
                                            FieldValueRow(field: field, character: character, editValues: editValues)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .padding()
            }
            .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

struct FieldValueRow: View {
    var field: Field
    var character: Character
    var editValues: Bool

    var body: some View {
        if let value = character.value(for: field) {
            FieldDisplayView(field: field, value: value, editValues: editValues)
        } else {
            Text(field.defaultValue ?? "")
                .onAppear {
                    character.fieldValues.append(
                        CharacterFieldValue(fieldID: field.id, value: field.defaultValue)
                    )
                }
        }
    }
}

struct FieldDisplayView: View {
    var field: Field
    @Bindable var value: CharacterFieldValue
    var editValues: Bool

    private var isEditable: Bool { editValues || field.liveValue }

    var body: some View {
        Group {
            if field.fieldLayout == .vertical {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                    fieldContent
                    Text(field.unit ?? "")
                    }
                    Text(field.label).font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Text(field.label).font(.subheadline)
                    Spacer()
                    fieldContent
                    Text(field.unit ?? "")
                }
            }
        }
    }

    @ViewBuilder
    private var fieldContent: some View {
        switch field.kind {
        case .text, .note:
            if isEditable {
                TextField(field.hint ?? "", text: stringBinding)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(value.value ?? field.defaultValue ?? "")
            }

        case .integer:
            if isEditable {
                HStack {
                    StepperWithText(
                        value: intBinding,
                        range: (field.minValue ?? 0)...(field.maxValue ?? 100),
                        step: field.step ?? 1
                    )
                    if field.displayMaxValue {
                        Text("/ \(field.maxValue.map(\.description) ?? "?")")
                    }
                }
            } else {
                HStack {
                Text(value.value ?? field.defaultValue ?? "0")
                if field.displayMaxValue {
                    Text("/ \(field.maxValue.map(\.description) ?? "?")")
                }
            }
            }

        case .decimal:
            if isEditable {
                TextField(field.hint ?? "", text: stringBinding)
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(value.value ?? field.defaultValue ?? "")
            }

        case .modifier:
            StepperWithText(
                value: intBinding,
                range: (field.minValue ?? -100)...(field.maxValue ?? 100),
                step: field.step ?? 1
            )

        case .boolean:
            Toggle(isOn: Binding(
                get: { (value.value ?? field.defaultValue ?? "false").lowercased() == "true" },
                set: { value.value = $0 ? "true" : "false" }
            )) { EmptyView() }

        case .date:
            if isEditable {
                DatePicker("", selection: dateBinding, displayedComponents: .date)
                    .labelsHidden()
            } else {
                Text(value.value ?? "")
            }
        }
    }

    private var stringBinding: Binding<String> {
        Binding(
            get: { value.value ?? field.defaultValue ?? "" },
            set: { value.value = $0 }
        )
    }

    private var intBinding: Binding<Int> {
        Binding(
            get: { Int(value.value ?? field.defaultValue ?? "0") ?? 0 },
            set: { value.value = String($0) }
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                let formatter = ISO8601DateFormatter()
                if let raw = value.value, let date = formatter.date(from: raw) { return date }
                return Date()
            },
            set: {
                let formatter = ISO8601DateFormatter()
                value.value = formatter.string(from: $0)
            }
        )
    }
}

struct StepperWithText: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack {
            Stepper(value: $value, in: range, step: step) {
                EmptyView()
            }
            TextField("", value: $value, formatter: NumberFormatter())
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
        }
    }
}
