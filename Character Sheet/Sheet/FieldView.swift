import SwiftUI
import SheetKit

/// Un champ : libellé et valeur, modifiable selon le mode et le caractère vivant du champ.
struct FieldView: View {
    @Bindable var field: SheetField
    var hideLabel = false

    @Environment(\.sheetMode) private var mode

    private var editable: Bool {
        field.kind != .formula && mode.canEdit(live: field.isLive)
    }

    /// Les valeurs volumineuses passent sous leur libellé.
    private var stacksVertically: Bool {
        field.labelPlacement == .top
            || field.kind == .longText
            || field.kind == .image
            || (field.kind == .resource && field.resourceStyle == .track)
    }

    var body: some View {
        if stacksVertically {
            VStack(alignment: .leading, spacing: 4) {
                if !hideLabel { label }
                value
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if !hideLabel { label }
                Spacer(minLength: 4)
                value
            }
        }
    }

    @ViewBuilder
    private var label: some View {
        if field.label.isEmpty && mode == .structure {
            Text("Sans libellé")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        } else {
            Text(field.label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var value: some View {
        switch field.kind {
        case .text:
            if editable {
                TextField("", text: text, prompt: field.hint.map(Text.init))
                    .multilineTextAlignment(stacksVertically ? .leading : .trailing)
                    .inputBackground()
            } else {
                Text(field.textValue ?? "")
            }

        case .longText:
            if editable {
                TextField("", text: text, prompt: field.hint.map(Text.init), axis: .vertical)
                    .lineLimit(3...20)
                    .inputBackground()
            } else {
                Text(field.textValue?.isEmpty == false ? field.textValue! : "—")
                    .foregroundStyle(field.textValue?.isEmpty == false ? .primary : .tertiary)
            }

        case .integer, .decimal, .percentage:
            HStack(spacing: 4) {
                if editable {
                    // Une formule donne la valeur par défaut, affichée en gris tant que rien n'est saisi.
                    let computed = engine.computed(field)
                    NumberField(value: $field.numberValue, integer: field.kind != .decimal, prompt: computed?.promptText)
                    if field.numberValue == nil, case .failure(let error)? = computed {
                        FormulaErrorBadge(error: error)
                    }
                } else {
                    ComputedValueText(result: engine.value(of: field))
                }
                if field.kind == .percentage {
                    Text("%").foregroundStyle(.secondary)
                } else if let unit = field.unit, !unit.isEmpty {
                    Text(unit).foregroundStyle(.secondary)
                }
            }

        case .modifier:
            if editable {
                TextField("", text: modifierText, prompt: Text("+0"))
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .inputBackground()
            } else {
                Text(field.displayValue.isEmpty ? "—" : field.displayValue)
                    .monospacedDigit()
            }

        case .resource:
            ResourceView(field: field, editable: editable)

        case .checkbox:
            CheckboxButton(isOn: Binding(
                get: { field.boolValue == true },
                set: { field.boolValue = $0 }
            ), enabled: editable)

        case .choice:
            if editable {
                Picker(field.label, selection: Binding(
                    get: { field.textValue ?? "" },
                    set: { field.textValue = $0.isEmpty ? nil : $0 }
                )) {
                    Text("—").tag("")
                    ForEach(field.options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .labelsHidden()
            } else {
                Text(field.textValue ?? "—")
            }

        case .date:
            if editable {
                if field.dateValue == nil {
                    Button("Ajouter une date") { field.dateValue = Date() }
                } else {
                    DatePicker("", selection: Binding(
                        get: { field.dateValue ?? Date() },
                        set: { field.dateValue = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                }
            } else {
                Text(field.displayValue.isEmpty ? "—" : field.displayValue)
            }

        case .image:
            ImageFieldView(field: field, editable: editable)

        case .formula:
            let result = engine.value(of: field)
            HStack(spacing: 4) {
                ComputedValueText(result: result)
                if case .success(_?) = result, let unit = field.unit, !unit.isEmpty {
                    Text(unit).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Moteur de calcul neuf à chaque affichage : les valeurs lues pendant le calcul sont observées,
    /// la vue se met à jour quand une valeur dont dépend la formule change.
    private var engine: FormulaEngine { FormulaEngine(sheet: field.sheet) }

    private var text: Binding<String> {
        Binding(
            get: { field.textValue ?? "" },
            set: { field.textValue = $0.isEmpty ? nil : $0 }
        )
    }

    /// Modificateur : un nombre signé si possible, sinon du texte libre (« +1d4 »).
    private var modifierText: Binding<String> {
        Binding(
            get: { field.displayValue },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                let normalized = trimmed.replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: ",", with: ".")
                if let number = Double(normalized) {
                    field.numberValue = number
                    field.textValue = nil
                } else {
                    field.numberValue = nil
                    field.textValue = trimmed.isEmpty ? nil : trimmed
                }
            }
        )
    }
}

/// Valeur calculée : nombre, « — » si une valeur dont elle dépend manque, ou l'erreur.
struct ComputedValueText: View {
    let result: FormulaResult

    var body: some View {
        switch result {
        case .success(let value?):
            Text(SheetFormat.number(value)).monospacedDigit()
        case .success(nil):
            Text("—").foregroundStyle(.tertiary)
        case .failure(let error):
            FormulaErrorBadge(error: error, showsMessage: true)
        }
    }
}

/// Erreur de formule : icône (et message), sans bloquer la fiche.
struct FormulaErrorBadge: View {
    let error: FormulaError
    var showsMessage = false

    var body: some View {
        Label {
            if showsMessage { Text(error.message) }
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
        }
        .labelStyle(.titleAndIcon)
        .font(.caption)
        .foregroundStyle(.red)
        .lineLimit(2)
        .help(error.message)
        .accessibilityLabel(error.message)
    }
}

extension Result where Success == Double?, Failure == FormulaError {
    /// Texte d'invite d'une saisie : la valeur calculée, s'il y en a une.
    var promptText: String? {
        guard case .success(let value?) = self else { return nil }
        return SheetFormat.number(value)
    }
}

/// Mise en forme partagée par les vues de la fiche.
enum SheetFormat {
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

/// Saisie numérique compacte (validée à la fin de l'édition).
struct NumberField: View {
    @Binding var value: Double?
    var integer = true
    var prompt: String?
    var width: CGFloat = 56

    var body: some View {
        TextField(
            "",
            value: $value,
            format: .number.precision(.fractionLength(0...(integer ? 0 : 2))),
            prompt: prompt.map(Text.init)
        )
        .keyboardType(integer ? .numberPad : .decimalPad)
        .multilineTextAlignment(.trailing)
        .monospacedDigit()
        .frame(width: width)
        .inputBackground()
    }
}

/// Case à cocher.
struct CheckboxButton: View {
    @Binding var isOn: Bool
    let enabled: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(enabled)
        .accessibilityLabel(isOn ? "Coché" : "Non coché")
    }
}
