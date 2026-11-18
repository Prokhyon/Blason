import SwiftUI
import SwiftData
import SheetKit

/// Retouche en Jouer (SPEC §5.17) : un appui long sur une valeur ouvre une bulle pour la corriger
/// (Statut qui monte de 5, un trait noté en cours de partie) sans passer en Remplir. Option de
/// l'appareil, active par défaut, dans le menu « … » en Jouer.
enum PlayRetouch {
    static let storageKey = "playRetouch"
}

/// Valeur retouchable : un champ, ou une cellule de tableau.
enum RetouchTarget {
    case field(SheetField)
    case cell(SheetTableCell, SheetTableColumn)

    /// Valeur qu'on peut retoucher : pas les calculs purs, les images ni les espaces.
    static func field(_ field: SheetField, editable: Bool) -> RetouchTarget? {
        guard !editable else { return nil }
        switch field.kind {
        case .formula, .spacer, .image: return nil
        default: return .field(field)
        }
    }

    static func cell(_ cell: SheetTableCell, column: SheetTableColumn, editable: Bool) -> RetouchTarget? {
        guard !editable, column.kind != .formula else { return nil }
        return .cell(cell, column)
    }
}

extension View {
    /// En Jouer, appui long → bulle de retouche de `target` (nil : rien). Les modificateurs restent
    /// posés dans tous les modes (identité stable au changement de mode).
    func playRetouch(_ target: RetouchTarget?) -> some View {
        modifier(PlayRetouchModifier(target: target))
    }
}

private struct PlayRetouchModifier: ViewModifier {
    let target: RetouchTarget?

    @Environment(\.sheetMode) private var mode
    @AppStorage(PlayRetouch.storageKey) private var enabled = true
    @State private var isPresented = false

    func body(content: Content) -> some View {
        let active = mode == .play && enabled && target != nil
        content
            .gesture(LongPressGesture(minimumDuration: 0.4).onEnded { _ in isPresented = true },
                     including: active ? .all : .subviews)
            .sensoryFeedback(.impact(weight: .light), trigger: isPresented) { _, shown in shown }
            .popover(isPresented: $isPresented) {
                if let target {
                    RetouchBubble(target: target)
                        .presentationCompactAdaptation(.popover)
                }
            }
            .accessibilityAction(named: "Retoucher") {
                if active { isPresented = true }
            }
            #if DEBUG
            // -demoRetouch CON (code d'un champ) ou -demoRetouch "Statut|valeur" (ligne|code de colonne).
            .task {
                guard active, let key = UserDefaults.standard.string(forKey: "demoRetouch"),
                      target.map({ Self.matches($0, key) }) == true else { return }
                try? await Task.sleep(for: .seconds(1.5))
                isPresented = true
            }
            #endif
    }

    #if DEBUG
    private static func matches(_ target: RetouchTarget, _ key: String) -> Bool {
        switch target {
        case .field(let field): return field.code == key
        case .cell(let cell, let column): return "\(cell.row?.label ?? "")|\(column.code)" == key
        }
    }
    #endif
}

/// Contenu de la bulle : le nom de la valeur, puis la saisie de Remplir ; pour un nombre, − / +
/// autour de la valeur, et « Revenir au calcul » quand une formule donne la valeur par défaut.
private struct RetouchBubble: View {
    let target: RetouchTarget

    var body: some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            editor
        }
        .padding(20)
        .frame(minWidth: 240, maxWidth: 340)
        // La saisie de Remplir, dans la bulle seulement.
        .environment(\.sheetMode, .fill)
    }

    private var title: String {
        switch target {
        case .field(let field):
            return [field.label, field.section?.title ?? ""].filter { !$0.isEmpty }.joined(separator: " · ")
        case .cell(let cell, let column):
            return [cell.row?.displayLabel ?? "", column.title].filter { !$0.isEmpty }.joined(separator: " · ")
        }
    }

    @ViewBuilder
    private var editor: some View {
        switch target {
        case .field(let field):
            switch field.kind {
            case .integer, .decimal, .percentage:
                NumberRetouch(value: Binding(get: { field.numberValue }, set: { field.numberValue = $0 }),
                              computed: number(FormulaEngine(sheet: field.sheet).computed(field)),
                              integer: field.kind != .decimal,
                              percentage: field.kind == .percentage,
                              bounds: (field.minimum, field.maximum),
                              accessibilityName: field.label)
            case .longText:
                FieldView(field: field, hideLabel: true)
                    .frame(width: 300)
            default:
                FieldView(field: field, hideLabel: true)
                    .frame(minWidth: 200)
            }
        case .cell(let cell, let column):
            switch column.kind {
            case .number, .percentage:
                NumberRetouch(value: Binding(get: { cell.numberValue }, set: { cell.numberValue = $0 }),
                              computed: number(FormulaEngine(sheet: cell.sheet).computed(cell)),
                              integer: true,
                              percentage: column.kind == .percentage,
                              bounds: (nil, nil),
                              accessibilityName: title)
                // Valeur calculée (% = base + groupe) : les nombres saisis de la ligne, juste dessous.
                // Monter la base garde le lien avec la formule ; retoucher le % le remplace.
                let sources = sourceCells(of: cell, column: column)
                if !sources.isEmpty {
                    Divider()
                    ForEach(sources, id: \.cell.persistentModelID) { source in
                        SourceNumberRow(cell: source.cell, column: source.column)
                    }
                }
            case .text:
                TextField("", text: Binding(
                    get: { cell.textValue ?? "" },
                    set: { cell.textValue = $0.isEmpty ? nil : $0 }
                ))
                .frame(minWidth: 200)
                .inputBackground()
                .accessibilityLabel(title)
            case .checkbox:
                Toggle(title, isOn: Binding(
                    get: { cell.boolValue == true },
                    set: { cell.boolValue = $0 }
                ))
                .frame(minWidth: 200)
            case .formula:
                EmptyView()
            }
        }
    }

    /// Cellules numériques saisies (sans formule, non vivantes) de la même ligne, quand la cellule
    /// retouchée est calculée.
    private func sourceCells(of cell: SheetTableCell, column: SheetTableColumn)
        -> [(cell: SheetTableCell, column: SheetTableColumn)] {
        guard column.formula?.isEmpty == false, let row = cell.row,
              let columns = column.section?.sortedColumns else { return [] }
        return columns.compactMap { other in
            guard other !== column, other.kind == .number || other.kind == .percentage,
                  other.formula?.isEmpty != false, !other.isLive,
                  let source = row.cell(for: other) else { return nil }
            return (source, other)
        }
    }

    private func number(_ result: FormulaResult?) -> Double? {
        guard case .success(let value?)? = result else { return nil }
        return value
    }
}

/// Nombre : la valeur en grand, saisissable, entre − et + ; les pourcentages vont aussi de 5 en 5.
private struct NumberRetouch: View {
    @Binding var value: Double?
    /// Valeur donnée par la formule, quand rien n'est saisi.
    let computed: Double?
    let integer: Bool
    let percentage: Bool
    let bounds: (minimum: Double?, maximum: Double?)
    let accessibilityName: String

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                NumberField(value: $value, integer: integer, prompt: computed.map(SheetFormat.number),
                            width: 84, accessibilityName: accessibilityName)
                    .font(.title.weight(.semibold))
                if percentage {
                    Text("%").font(.title3).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                if percentage { step(-5) }
                step(-1)
                step(1)
                if percentage { step(5) }
            }
            if computed != nil, value != nil {
                Button("Revenir au calcul (\(SheetFormat.number(computed ?? 0)))") { value = nil }
                    .font(.footnote)
            }
        }
    }

    /// Part de la valeur affichée (saisie, sinon calculée), bornée par le minimum et le maximum.
    private func step(_ delta: Double) -> some View {
        Button {
            var next = (value ?? computed ?? 0) + delta
            if let minimum = bounds.minimum { next = max(minimum, next) }
            if let maximum = bounds.maximum { next = min(maximum, next) }
            value = next
        } label: {
            Text(delta > 0 ? "+\(SheetFormat.number(delta))" : "−\(SheetFormat.number(-delta))")
                .monospacedDigit()
                .frame(minWidth: 36)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .accessibilityLabel(delta > 0 ? "Ajouter \(SheetFormat.number(delta))" : "Retirer \(SheetFormat.number(-delta))")
    }
}

/// Nombre saisi de la ligne, en petit : libellé de la colonne, valeur, − / +.
private struct SourceNumberRow: View {
    @Bindable var cell: SheetTableCell
    let column: SheetTableColumn

    var body: some View {
        HStack(spacing: 8) {
            Text(column.title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Retirer 1", systemImage: "minus") { cell.numberValue = (cell.numberValue ?? 0) - 1 }
            NumberField(value: $cell.numberValue, width: 52, accessibilityName: column.title)
            Button("Ajouter 1", systemImage: "plus") { cell.numberValue = (cell.numberValue ?? 0) + 1 }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
    }
}
