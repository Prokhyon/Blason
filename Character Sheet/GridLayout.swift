//
//  Layout.swift
//  Character Sheet
//
//  Created by Loris Thomas on 10.04.2026.
//
import SwiftUI

struct GridItemKey: LayoutValueKey {
    static let defaultValue: Section? = nil
}

struct SpanningGridLayout: Layout {

    let columns: Int
    let cellSize: CGFloat
    let spacing: CGFloat

    struct CacheData {
        var frames: [CGRect] = []
    }

    func makeCache(subviews: Subviews) -> CacheData {
        CacheData()
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) -> CGSize {

        let maxY = subviews
            .compactMap { ($0[GridItemKey.self]?.gridOrigin.y ?? 0) + $0[GridItemKey.self]!.height }
            .max() ?? 0

        let width = CGFloat(columns) * cellSize + CGFloat(columns - 1) * spacing
        let height = CGFloat(maxY) * cellSize + CGFloat(maxY - 1) * spacing

        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout CacheData
    ) {

        for subview in subviews {
            guard let item = subview[GridItemKey.self] else { continue }

            let x = CGFloat(item.gridOrigin.x) * (cellSize + spacing)
            let y = CGFloat(item.gridOrigin.y) * (cellSize + spacing)

            let width = CGFloat(item.width) * cellSize + CGFloat(item.width - 1) * spacing
            let height = CGFloat(item.height) * cellSize + CGFloat(item.height - 1) * spacing

            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(width: width, height: height)
            )
        }
    }
    
    
}
