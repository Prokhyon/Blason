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
        Group {
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
        // En lecture, libellé et valeur forment un seul élément pour VoiceOver (« Force, 11 »).
        .accessibilityElement(children: readsAsOneElement ? .combine : .contain)
    }

    private var readsAsOneElement: Bool {
        !editable && field.kind != .image && field.kind != .resource
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
                    .accessibilityLabel(field.label)
            } else {
                ValueText(field.textValue)
            }

        case .longText:
            if editable {
                TextField("", text: text, prompt: field.hint.map(Text.init), axis: .vertical)
                    .lineLimit(3...20)
                    .inputBackground()
                    .accessibilityLabel(field.label)
            } else {
                ValueText(field.textValue)
            }

        case .integer, .decimal, .percentage:
            HStack(spacing: 4) {
                if editable {
                    // Une formule donne la valeur par défaut, affichée en gris tant que rien n'est saisi.
                    let computed = engine.computed(field)
                    NumberField(value: $field.numberValue, integer: field.kind != .decimal, prompt: computed?.promptText,
                                accessibilityName: field.label)
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
                // Une formule (table de correspondance) donne la valeur par défaut, en gris.
                TextField("", text: modifierText, prompt: Text(engine.computedContent(field)?.promptText ?? "+0"))
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 70)
                    .fixedSize()
                    .inputBackground()
                    .accessibilityLabel(field.label)
            } else {
                ComputedValueText(result: engine.content(of: field), signed: true)
            }

        case .resource:
            ResourceView(field: field, editable: editable)

        case .checkbox:
            CheckboxButton(isOn: Binding(
                get: { field.boolValue == true },
                set: { field.boolValue = $0 }
            ), enabled: editable, accessibilityName: field.label)

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
                ValueText(field.textValue)
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
                ValueText(field.displayValue)
            }

        case .image:
            ImageFieldView(field: field, editable: editable)

        case .formula:
            let result = engine.content(of: field)
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

/// Valeur en lecture ; « — » estompé quand elle est vide (lu « vide » par VoiceOver).
struct ValueText: View {
    let text: String?

    init(_ text: String?) {
        self.text = text
    }

    var body: some View {
        if let text, !text.isEmpty {
            Text(text)
        } else {
            Text("—")
                .foregroundStyle(.tertiary)
                .accessibilityLabel("vide")
        }
    }
}

/// Valeur calculée : nombre, texte (table de correspondance), « — » si une valeur dont elle
/// dépend manque, ou l'erreur.
struct ComputedValueText: View {
    let result: FormulaValueResult
    /// Nombre affiché avec son signe (modificateur : « +2 »).
    var signed = false

    init(result: FormulaValueResult, signed: Bool = false) {
        self.result = result
        self.signed = signed
    }

    init(result: FormulaResult) {
        self.init(result: result.asValue)
    }

    var body: some View {
        switch result {
        case .success(let value?):
            Text(value.displayText(signed: signed)).monospacedDigit()
        case .success(nil):
            ValueText(nil)
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

extension FormulaValue {
    /// Texte affiché : nombre mis en forme (avec son signe si demandé), ou texte tel quel.
    func displayText(signed: Bool = false) -> String {
        switch self {
        case .number(let value):
            signed && value > 0 ? "+" + SheetFormat.number(value) : SheetFormat.number(value)
        case .text(let text):
            text
        }
    }
}

extension Result where Success == FormulaValue?, Failure == FormulaError {
    /// Texte d'invite d'une saisie : la valeur calculée, s'il y en a une.
    var promptText: String? {
        guard case .success(let value?) = self else { return nil }
        return value.displayText(signed: true)
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

/// Saisie numérique compacte. La valeur suit la frappe : les calculs qui en dépendent se mettent
/// à jour aussitôt. Un texte qui n'est pas (encore) un nombre, comme « - », laisse la valeur telle quelle ;
/// le texte est remis en forme en quittant le champ.
struct NumberField: View {
    @Binding var value: Double?
    var integer = true
    var prompt: String?
    var width: CGFloat = 56
    /// Nom lu par VoiceOver (le libellé du champ, de la colonne…).
    var accessibilityName: String = ""

    @State private var text = ""
    @FocusState private var isFocused: Bool
    /// La largeur suit la taille du texte choisie dans les réglages.
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        TextField("", text: $text, prompt: prompt.map(Text.init))
            .focused($isFocused)
            .numericKeyboard(integer: integer)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
            .frame(width: width * scale)
            .inputBackground()
            .accessibilityLabel(accessibilityName)
            .onAppear { text = format(value) }
            .onChange(of: value) { _, newValue in
                // Changement venu d'ailleurs (annuler, boutons −/+, inspecteur).
                if !isFocused { text = format(newValue) }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused { text = format(value) }
            }
            .onChange(of: text) { _, newText in
                guard isFocused else { return }
                let parsed: Double?
                if newText.trimmingCharacters(in: .whitespaces).isEmpty {
                    parsed = nil
                } else if let number = ListImport.number(from: newText) {
                    parsed = integer ? number.rounded() : number
                } else {
                    return
                }
                if parsed != value { value = parsed }
            }
    }

    private func format(_ value: Double?) -> String {
        value.map { $0.formatted(.number.precision(.fractionLength(0...(integer ? 0 : 2)))) } ?? ""
    }
}

/// Case à cocher.
struct CheckboxButton: View {
    @Binding var isOn: Bool
    let enabled: Bool
    /// Nom lu par VoiceOver (« Esquive, Exp. »).
    var accessibilityName: String = ""

    @Environment(\.sheetTheme) private var theme

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            theme.checkbox(isOn)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(enabled)
        .accessibilityLabel(accessibilityName)
        .accessibilityValue(isOn ? "coché" : "non coché")
        .accessibilityAddTraits(.isToggle)
        .disabled(!enabled)
    }
}
