import SwiftUI

/// Mise en page d'un tableau de la fiche : des lignes de cellules alignées en colonnes, et des
/// lignes pleine largeur (titres de groupe, boutons d'ajout).
///
/// Remplace `Grid` (SPEC §5.17, fluidité) : la grille mesurait chaque cellule plusieurs fois par
/// passe et interrogeait l'alignement de chacune (`gridColumnAlignment`), ce qui figeait la page
/// des Compétences une seconde au changement de mode. Ici, chaque cellule est mesurée une fois à
/// sa taille idéale (largeurs des colonnes), puis une fois à la largeur de sa colonne (hauteur
/// de la ligne).
///
/// Les vues filles se suivent ligne après ligne : une ligne de cellules en compte
/// `columns.count + 1` (le libellé, puis une par colonne) ; une vue marquée `tableSpan()` occupe
/// une ligne entière.
struct TableLayout: Layout {
    /// Colonnes de valeurs, après celle des libellés.
    let columns: [Column]
    var horizontalSpacing: CGFloat = 10
    var verticalSpacing: CGFloat = 6

    struct Column {
        /// Colonne de texte : elle partage la place restante avec les libellés.
        var flexible: Bool
        /// Valeurs alignées à droite (nombres, cases).
        var trailing: Bool
        /// Largeur au moins égale à celle d'une saisie : les colonnes restent en place d'un mode à l'autre.
        var minimumWidth: CGFloat = 0
    }

    struct Cache {
        var rows: [Row] = []
        /// Largeur idéale de chaque colonne (0 : libellés).
        var ideal: [CGFloat] = []
        /// Hauteurs des lignes pour une largeur donnée (une passe interroge plusieurs largeurs).
        var heights: [CGFloat: [CGFloat]] = [:]
    }

    enum Row {
        case cells(Range<Int>)
        case span(Int)
    }

    private var count: Int { columns.count + 1 }

    func makeCache(subviews: Subviews) -> Cache {
        var cache = Cache()
        cache.ideal = [0] + columns.map(\.minimumWidth)
        var index = 0
        while index < subviews.count {
            if subviews[index][TableSpanKey.self] {
                cache.rows.append(.span(index))
                index += 1
            } else {
                let end = min(index + count, subviews.count)
                cache.rows.append(.cells(index..<end))
                for (column, subview) in subviews[index..<end].enumerated() {
                    cache.ideal[column] = max(cache.ideal[column], subview.sizeThatFits(.unspecified).width)
                }
                index = end
            }
        }
        return cache
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache = makeCache(subviews: subviews)
    }

    /// Largeur de chaque colonne : les nombres et les cases à leur largeur idéale, la place
    /// restante partagée entre les libellés et les colonnes de texte.
    private func widths(total: CGFloat, cache: Cache) -> [CGFloat] {
        var widths = cache.ideal
        let flexible = (0..<count).filter { $0 == 0 || columns[$0 - 1].flexible }
        let fixed = (0..<count).filter { !flexible.contains($0) }.reduce(0) { $0 + widths[$1] }
        let available = max(0, total - fixed - horizontalSpacing * CGFloat(count - 1))
        let wanted = flexible.reduce(0) { $0 + widths[$1] }
        if available >= wanted {
            let extra = (available - wanted) / CGFloat(flexible.count)
            for column in flexible { widths[column] += extra }
        } else if wanted > 0 {
            for column in flexible { widths[column] = available * widths[column] / wanted }
        }
        return widths
    }

    private func idealWidth(_ cache: Cache) -> CGFloat {
        cache.ideal.reduce(0, +) + horizontalSpacing * CGFloat(count - 1)
    }

    private func rowHeights(width: CGFloat, subviews: Subviews, cache: inout Cache) -> [CGFloat] {
        if let heights = cache.heights[width] { return heights }
        let columnWidths = widths(total: width, cache: cache)
        let heights = cache.rows.map { row -> CGFloat in
            switch row {
            case .span(let index):
                return subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            case .cells(let range):
                return zip(subviews[range], columnWidths)
                    .map { $0.sizeThatFits(ProposedViewSize(width: $1, height: nil)).height }
                    .max() ?? 0
            }
        }
        cache.heights[width] = heights
        return heights
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? idealWidth(cache)
        let heights = rowHeights(width: width, subviews: subviews, cache: &cache)
        let height = heights.reduce(0, +) + verticalSpacing * CGFloat(max(0, heights.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let heights = rowHeights(width: bounds.width, subviews: subviews, cache: &cache)
        let columnWidths = widths(total: bounds.width, cache: cache)
        var y = bounds.minY
        for (row, height) in zip(cache.rows, heights) {
            switch row {
            case .span(let index):
                subviews[index].place(at: CGPoint(x: bounds.minX, y: y + height / 2), anchor: .leading,
                                      proposal: ProposedViewSize(width: bounds.width, height: nil))
            case .cells(let range):
                var x = bounds.minX
                for (column, (subview, width)) in zip(subviews[range], columnWidths).enumerated() {
                    let trailing = column > 0 && columns[column - 1].trailing
                    subview.place(at: CGPoint(x: trailing ? x + width : x, y: y + height / 2),
                                  anchor: trailing ? .trailing : .leading,
                                  proposal: ProposedViewSize(width: width, height: nil))
                    x += width + horizontalSpacing
                }
            }
            y += height + verticalSpacing
        }
    }
}

nonisolated private struct TableSpanKey: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    /// Dans un `TableLayout` : la vue occupe toute une ligne.
    func tableSpan() -> some View {
        layoutValue(key: TableSpanKey.self, value: true)
    }
}
