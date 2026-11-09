import SwiftUI
import SheetKit

/// Ressource (PV, PM, SAN…) : valeur actuelle / maximum.
/// - Jouer : boutons −/+ et, en style « piste », une case par valeur à toucher.
/// - Remplir : saisie de la valeur actuelle et du maximum.
struct ResourceView: View {
    @Bindable var field: SheetField
    let editable: Bool

    @Environment(\.sheetMode) private var mode

    /// Maximum saisi, sinon calculé par la formule.
    private var maximumResult: FormulaResult { FormulaEngine(sheet: field.sheet).maximum(of: field) }
    private var maximum: Int? { (try? maximumResult.get())?.flatMap { Int($0) } }
    private var current: Int { Int(field.numberValue ?? maximum.map(Double.init) ?? 0) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if mode == .fill {
                HStack(spacing: 8) {
                    NumberField(value: $field.numberValue, prompt: maximum.map(String.init) ?? "actuel")
                    Text("/").foregroundStyle(.secondary)
                    NumberField(value: $field.resourceMax, prompt: maximumResult.promptText ?? "max")
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
            let upper = maximum ?? Int.max
            field.numberValue = Double(min(max(current + delta, 0), upper))
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .accessibilityLabel(delta < 0 ? "Diminuer" : "Augmenter")
    }
}

/// Piste numérotée de 0 au maximum, comme sur la fiche papier.
/// La valeur actuelle est mise en avant ; les valeurs au-dessus sont estompées.
struct ResourceTrack: View {
    let current: Int
    let maximum: Int
    let onSelect: (Int) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 28, maximum: 34), spacing: 3)], spacing: 3) {
            ForEach(0...maximum, id: \.self) { value in
                Button {
                    onSelect(value)
                } label: {
                    Text("\(value)")
                        .font(.caption2.monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .foregroundStyle(value == current ? Color.white : (value > current ? Color.secondary.opacity(0.5) : Color.primary))
                        .background(
                            value == current ? Color.accentColor : Color(.tertiarySystemFill),
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
