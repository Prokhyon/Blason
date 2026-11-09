import SwiftUI
import SheetKit

/// Ressource (PV, PM, SAN…) : valeur actuelle / maximum.
/// - Jouer : boutons −/+ et, en style « piste », une case par valeur à toucher.
/// - Remplir : saisie de la valeur actuelle et du maximum.
struct ResourceView: View {
    @Bindable var field: SheetField
    let editable: Bool

    @Environment(\.sheetMode) private var mode
    @ScaledMetric(relativeTo: .body) private var buttonSize: CGFloat = 32

    /// Maximum saisi, sinon calculé par la formule.
    private var maximumResult: FormulaResult { FormulaEngine(sheet: field.sheet).maximum(of: field) }
    private var maximum: Int? { (try? maximumResult.get())?.flatMap { Int($0) } }
    private var current: Int { Int(field.numberValue ?? maximum.map(Double.init) ?? 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if mode == .fill {
                HStack(spacing: 8) {
                    NumberField(value: $field.numberValue, prompt: maximum.map(String.init) ?? "actuel",
                                accessibilityName: "\(field.label), valeur actuelle")
                    Text("/").foregroundStyle(.secondary)
                    NumberField(value: $field.resourceMax, prompt: maximumResult.promptText ?? "max",
                                accessibilityName: "\(field.label), maximum")
                    if field.resourceMax == nil, case .failure(let error) = maximumResult {
                        FormulaErrorBadge(error: error)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    if editable {
                        stepButton("minus", delta: -1)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(current)")
                            .font(.title2.weight(.semibold))
                        if let maximum {
                            Text("/ \(maximum)").foregroundStyle(.secondary)
                        }
                    }
                    .monospacedDigit()
                    // VoiceOver : « Points de vie, 12 sur 14 », balayer vers le haut ou le bas pour changer.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(field.label)
                    .accessibilityValue(maximum.map { "\(current) sur \($0)" } ?? "\(current)")
                    .accessibilityAdjustableAction { direction in
                        guard editable else { return }
                        switch direction {
                        case .increment: step(1)
                        case .decrement: step(-1)
                        @unknown default: break
                        }
                    }
                    if editable {
                        stepButton("plus", delta: 1)
                    }
                }
            }

            if field.resourceStyle == .track, let maximum, maximum > 0, maximum <= 200 {
                ResourceTrack(current: current, maximum: maximum) { value in
                    field.numberValue = Double(value)
                }
                .allowsHitTesting(editable)
            }
        }
    }

    private func stepButton(_ symbol: String, delta: Int) -> some View {
        Button {
            step(delta)
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .accessibilityLabel(delta < 0 ? "Diminuer \(field.label)" : "Augmenter \(field.label)")
    }

    /// Ajoute `delta` à la valeur actuelle, entre 0 et le maximum.
    private func step(_ delta: Int) {
        let upper = maximum ?? Int.max
        field.numberValue = Double(min(max(current + delta, 0), upper))
    }
}

/// Piste numérotée de 0 au maximum, comme sur la fiche papier.
/// La valeur actuelle est mise en avant ; les valeurs au-dessus sont estompées.
struct ResourceTrack: View {
    let current: Int
    let maximum: Int
    let onSelect: (Int) -> Void

    @Environment(\.sheetTheme) private var theme
    /// Les cases grandissent avec la taille du texte choisie dans les réglages.
    @ScaledMetric(relativeTo: .caption2) private var cellWidth: CGFloat = 28
    @ScaledMetric(relativeTo: .caption2) private var cellHeight: CGFloat = 24

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: cellWidth, maximum: cellWidth * 1.2), spacing: 3)], spacing: 3) {
            ForEach(0...maximum, id: \.self) { value in
                Button {
                    onSelect(value)
                } label: {
                    Text("\(value)")
                        .font(.caption2.monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: cellHeight)
                        .foregroundStyle(value == current ? Color.white : (value > current ? Color.secondary.opacity(0.5) : Color.primary))
                        .background(
                            value == current ? theme.accent : theme.inputFill,
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(value)")
                .accessibilityAddTraits(value == current ? .isSelected : [])
            }
        }
    }
}
