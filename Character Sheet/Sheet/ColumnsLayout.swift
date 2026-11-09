import SwiftUI

/// Colonnes côte à côte de largeurs relatives (`weights`), alignées en haut.
/// Quand une colonne descendrait sous `minColumnWidth`, elles passent les unes sous les autres.
struct ColumnsLayout: Layout {
    var weights: [Double]
    var spacing: CGFloat
    var minColumnWidth: CGFloat

    private func isStacked(width: CGFloat, count: Int) -> Bool {
        guard count > 1 else { return false }
        return (width - spacing * CGFloat(count - 1)) / CGFloat(count) < minColumnWidth
    }

    private func columnWidths(total: CGFloat, count: Int) -> [CGFloat] {
        let factors = (0..<count).map { index in
            index < weights.count ? max(weights[index], 0.1) : 1
        }
        let sum = factors.reduce(0, +)
        let available = max(0, total - spacing * CGFloat(count - 1))
        return factors.map { available * CGFloat($0 / sum) }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 800
        if isStacked(width: width, count: subviews.count) {
            let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
            let visible = heights.filter { $0 > 0 }
            return CGSize(width: width, height: visible.reduce(0, +) + spacing * CGFloat(max(0, visible.count - 1)))
        }
        let widths = columnWidths(total: width, count: subviews.count)
        let height = zip(subviews, widths)
            .map { subview, columnWidth in
                subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
            }
            .max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        if isStacked(width: bounds.width, count: subviews.count) {
            var y = bounds.minY
            for subview in subviews {
                let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: size.height))
                if size.height > 0 { y += size.height + spacing }
            }
            return
        }
        var x = bounds.minX
        for (subview, width) in zip(subviews, columnWidths(total: bounds.width, count: subviews.count)) {
            subview.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: width, height: nil))
            x += width + spacing
        }
    }
}
