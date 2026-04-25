//
//  SectionView.swift
//  Character Sheet
//
//  Created by Loris Thomas on 14.04.2026.
//

import SwiftUI

private struct SectionView: View {
    var section: Section
    @Binding var values: [CharacterFieldValue]
    @Binding var editValues: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 30)
            .overlay {
                switch section.layout {
                case .list:
                    VStack(spacing: 12) {
                        ForEach(section.fields.sorted { $0.order < $1.order }) { field in
                            FieldView(field: field, value: values.first(where: { $0.field.id == field.id }), editValues: $editValues)
                        }
                    }
                case .grid:
                    LazyVGrid(columns: [
                        .init(.adaptive(
                                  minimum: 50
                              ))
                    ] ,spacing: 12) {
                        ForEach(section.fields.sorted { $0.order < $1.order }) { field in
                            FieldView(field: field, value: values.first(where: { $0.field.id == field.id }), editValues: $editValues)
                        }
                    }
                }
        }
    }
}

struct FieldView: View {
    var field: Field
    @State var value: CharacterFieldValue?
    @Binding var editValues: Bool

    var body: some View {
        if field.fieldLayout == .vertical {
            VStack(alignment: .leading, spacing: 6) {
                Text(field.label)
                    .font(.subheadline)
                fieldValue.disabled(!(field.liveValue || editValues))
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
            TextView(field: field, value: $value, editValues: $editValues)
            
        case .integer:
            IntView(field: field, value: $value, editValues: $editValues)
            
        case .decimal:
            Rectangle()
//            TextField(field.hint ?? "", text: Binding(
//                get: { value?.value ?? field.defaultValue ?? "" },
//                set: { value?.value = $0 }
//            ))
//            .keyboardType(.numbersAndPunctuation)
//            .textFieldStyle(.roundedBorder)
            
        case .modifier:
            ModifierView(field: field, value: $value, editValues: $editValues)
            
        case .boolean:
            BooleanView(field: field, value: $value, editValues: $editValues)
            
        case .date:
            Rectangle()
//            DatePicker("", selection: Binding(
//                get: { dateValue },
//                set: { value.value = isoFormatter.string(from: $0) }
//            ), displayedComponents: .date)
//            .labelsHidden()
            
//        case .option:
            
            
//        case .multiOption:
//            VStack(alignment: .leading) {
//                ForEach(field.options ?? [], id: \.self) { option in
//                    Toggle(option, isOn: Binding(
//                        get: { value.selectedOptions.contains(option) },
//                        set: { toggleOption(option, $0) }
//                    ))
//                }
//            }
        }
    }
}

struct TextView: View {
    var field: Field
    @Binding var value: CharacterFieldValue?
    @Binding var editValues: Bool
    
    var body: some View {
        if field.liveValue || editValues {
            TextField(field.hint ?? "", text: Binding(
                get: { value?.value ?? "" },
                set: { value?.value = $0 }
            ))
            .textFieldStyle(.roundedBorder)
//                .frame(maxWidth: .infinity)
//                .frame(minHeight: field.kind == .note ? 120 : nil, alignment: .topLeading)
        } else {
            Text("\(value?.value ?? "")")
        }
    }
}

struct IntView: View {
    var field: Field
    @Binding var value: CharacterFieldValue?
    @Binding var editValues: Bool
    
    var body: some View {
        if field.liveValue || editValues {
            StepperWithText(
                value: Binding(
                    get: { Int(value?.value ?? field.defaultValue ?? "0") ?? 0 },
                    set: { value?.value = String($0) }
                ),
                range: (field.minValue ?? 0)...(field.maxValue ?? 100),
                step: field.step ?? 1
            )
        } else {
            Text("\(value?.value ?? field.defaultValue ?? "0")")
        }
    }
}

struct ModifierView: View {
    var field: Field
    @Binding var value: CharacterFieldValue?
    @Binding var editValues: Bool
    
    var body: some View {
        StepperWithText(
            value: Binding(
                get: { Int(value?.value ?? field.defaultValue ?? "0") ?? 0 },
                set: { value?.value = String($0) }
            ),
            range: (field.minValue ?? 0)...(field.maxValue ?? 100),
            step: field.step ?? 1
        )
    }
}

struct BooleanView: View {
    var field: Field
    @Binding var value: CharacterFieldValue?
    @Binding var editValues: Bool
    
    var body: some View {
        Toggle(isOn: Binding(
            get: { (value?.value ?? field.defaultValue ?? "false").lowercased() == "true" },
            set: { value?.value = $0 ? "true" : "false" }
        )) {
            EmptyView()
        }
    }
}

//struct OptionView: View {
//    var field: Field
//    @Binding var value: CharacterFieldValue?
//    @Binding var isFieldEditable: Bool
//    
//    var body: some View {
//        if isFieldEditable {
//            Picker(""
////                get: { value.value ?? field.defaultValue ?? (field.options?.first ?? "") },
////                set: { value.value = $0 }
//            )
//            {
//                ForEach(field.options ?? [], id: \.self) { option in
//                    Text(option).tag(option)
//                }
//            }
//            .pickerStyle(.menu)
//        } else {
//            Text(value?.value ?? field.defaultValue ?? (field.options?.first ?? ""))
//        }
//    }
//}

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

#Preview {
//    SectionView()
}
