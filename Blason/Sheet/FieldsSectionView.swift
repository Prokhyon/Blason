import SwiftUI
import SheetKit

/// Champs d'une section selon sa disposition (SPEC §5.17) : liste, grille (chaque champ à sa largeur,
/// libellé au-dessus), listes côte à côte, paires ou tuiles.
struct FieldsSectionView: View {
    let section: SheetSection

    @Environment(\.sheetMode) private var mode
    @Environment(\.sheetTheme) private var theme
    @State private var width: CGFloat = 0
    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    @ViewBuilder
    private var content: some View {
        let fields = section.sortedFields
        if fields.isEmpty {
            Text("Aucun champ").font(.callout).foregroundStyle(.secondary)
        } else {
            switch section.arrangement {
            case .list:
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(fields) { field in
                        FieldView(field: field, hideLabel: hidesLabel(field))
                            .structureItem(.field(field))
                    }
                }
            case .grid:
                FieldGridLayout(minimumWidth: (mode == .play ? 100 : 130) * scale) {
                    ForEach(fields) { field in
                        FieldView(field: field, labelOnTop: true)
                            .structureItem(.field(field))
                            .layoutValue(key: FieldSixths.self, value: field.gridSixths)
                    }
                }
            case .columns:
                let count = fittingListCount
                HStack(alignment: .top, spacing: 20) {
                    ForEach(0..<count, id: \.self) { list in
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(fields.filter { min($0.effectiveListIndex, count - 1) == list }) { field in
                                FieldView(field: field)
                                    .structureItem(.field(field))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            case .pairs:
                pairs(Self.pairs(fields))
            case .tiles:
                tiles(Self.pairs(fields))
            }
        }
    }

    // MARK: Listes côte à côte

    /// Nombre de listes qui tiennent dans la largeur : une section étroite (colonne de page étroite,
    /// inspecteur ouvert, grand texte) passe à moins de listes plutôt que de couper ses libellés.
    private var fittingListCount: Int {
        let wanted = max(1, section.columnCount)
        guard width > 0 else { return wanted }
        let minimum: CGFloat = (mode == .fill ? 240 : 190) * scale
        return min(wanted, max(1, Int((width + 20) / (minimum + 20))))
    }

    /// Un champ seul dont le libellé répète le titre de la section n'affiche pas son libellé.
    private func hidesLabel(_ field: SheetField) -> Bool {
        mode != .structure && section.fields?.count == 1 && field.label == section.title
    }

    // MARK: Paires et tuiles

    struct Pair: Identifiable {
        let id: Int
        let left: SheetField?
        let right: SheetField?
    }

    /// Les deux listes lues rang par rang : le n-ième champ de gauche avec le n-ième de droite.
    static func pairs(_ fields: [SheetField]) -> [Pair] {
        let left = fields.filter { $0.effectiveListIndex == 0 }
        let right = fields.filter { $0.effectiveListIndex == 1 }
        return (0..<max(left.count, right.count)).map { index in
            Pair(id: index, left: index < left.count ? left[index] : nil,
                 right: index < right.count ? right[index] : nil)
        }
    }

    private func pairs(_ pairs: [Pair]) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 0) {
            ForEach(pairs) { pair in
                if pair.id > 0 {
                    Divider().gridCellUnsizedAxes(.horizontal)
                }
                GridRow {
                    pairCell(pair.left)
                    pairCell(pair.right)
                }
            }
        }
    }

    @ViewBuilder
    private func pairCell(_ field: SheetField?) -> some View {
        if let field {
            FieldView(field: field)
                .padding(.vertical, 6)
                .structureItem(.field(field))
        } else {
            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
        }
    }

    private func tiles(_ pairs: [Pair]) -> some View {
        let minimum: CGFloat = (mode == .play ? 84 : 116) * scale
        let perLine = max(1, min(pairs.count, Int((width + 8) / (minimum + 8))))
        let lines = stride(from: 0, to: pairs.count, by: perLine).map { Array(pairs[$0..<min($0 + perLine, pairs.count)]) }
        return Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            ForEach(lines.indices, id: \.self) { index in
                GridRow {
                    ForEach(lines[index]) { pair in
                        FieldTile(pair: pair)
                    }
                    ForEach(0..<(perLine - lines[index].count), id: \.self) { _ in
                        Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                    }
                }
            }
        }
    }
}

/// Tuile : le champ de gauche en grand sous son libellé, celui de droite en petit dessous.
/// Un « Espace » à gauche laisse la place au champ de droite.
private struct FieldTile: View {
    let pair: FieldsSectionView.Pair

    @Environment(\.sheetMode) private var mode
    @Environment(\.sheetTheme) private var theme

    private var main: SheetField? {
        if let left = pair.left, left.kind != .spacer { return left }
        return pair.right
    }

    private var secondary: SheetField? {
        guard let right = pair.right, right !== main, right.kind != .spacer else { return nil }
        return right
    }

    var body: some View {
        VStack(spacing: 2) {
            if let main {
                VStack(spacing: 0) {
                    Text(main.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    FieldView(field: main, valueOnly: true)
                        .font(.title2.weight(.semibold))
                }
                .structureItem(.field(main))
            }
            if let secondary {
                HStack(spacing: 3) {
                    Text(secondary.label)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    FieldView(field: secondary, valueOnly: true)
                }
                .font(.caption)
                .minimumScaleFactor(0.8)
                .structureItem(.field(secondary))
            }
            // Espaces en Structure : sélectionnables.
            if mode == .structure {
                ForEach([pair.left, pair.right].compactMap { $0 }.filter { $0.kind == .spacer }) { spacer in
                    FieldView(field: spacer).structureItem(.field(spacer))
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.inputFill.opacity(mode == .play ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: mode == .play ? .combine : .contain)
    }
}

// MARK: - Grille

/// Largeur d'un champ dans la grille, en sixièmes.
nonisolated struct FieldSixths: LayoutValueKey {
    static let defaultValue = 6
}

/// Grille des champs : chacun à sa largeur (en sixièmes de la section), de gauche à droite, à la
/// ligne quand elle est pleine. Un champ qui descendrait sous `minimumWidth` s'élargit (⅓ → ½ →
/// pleine largeur) : sur iPhone, deux champs par ligne au plus.
struct FieldGridLayout: Layout {
    var minimumWidth: CGFloat
    var horizontalSpacing: CGFloat = 14
    var verticalSpacing: CGFloat = 12

    private struct Item {
        let index: Int
        let x: CGFloat
        let width: CGFloat
    }

    private func lines(width: CGFloat, subviews: Subviews) -> [[Item]] {
        let unit = max(0, (width - 5 * horizontalSpacing) / 6)
        func span(_ sixths: Int) -> CGFloat { CGFloat(sixths) * unit + CGFloat(sixths - 1) * horizontalSpacing }
        var result: [[Item]] = []
        var current: [Item] = []
        var used = 0
        for index in subviews.indices {
            var sixths = min(6, max(1, subviews[index][FieldSixths.self]))
            while sixths < 6 && span(sixths) < minimumWidth {
                sixths = switch sixths { case 1: 2; case 2: 3; default: 6 }
            }
            if used + sixths > 6 {
                result.append(current)
                current = []
                used = 0
            }
            current.append(Item(index: index, x: CGFloat(used) * (unit + horizontalSpacing), width: span(sixths)))
            used += sixths
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private func heights(_ lines: [[Item]], subviews: Subviews) -> [CGFloat] {
        lines.map { line in
            line.map { subviews[$0.index].sizeThatFits(ProposedViewSize(width: $0.width, height: nil)).height }.max() ?? 0
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 600
        let lines = lines(width: width, subviews: subviews)
        let visible = heights(lines, subviews: subviews).filter { $0 > 0 }
        return CGSize(width: width, height: visible.reduce(0, +) + verticalSpacing * CGFloat(max(0, visible.count - 1)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let lines = lines(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        for (line, height) in zip(lines, heights(lines, subviews: subviews)) {
            for item in line {
                subviews[item.index].place(at: CGPoint(x: bounds.minX + item.x, y: y), anchor: .topLeading,
                                           proposal: ProposedViewSize(width: item.width, height: nil))
            }
            if height > 0 { y += height + verticalSpacing }
        }
    }
}
