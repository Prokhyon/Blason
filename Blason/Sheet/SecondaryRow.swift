import SwiftUI

/// Rangée sous les onglets (SPEC §5.17) : des titres côte à côte, l'élément courant souligné.
/// Elle défile en largeur et garde l'élément courant visible. Pages de la fiche, emplacements de
/// la Besace, sessions du journal.
struct SecondaryRow<ID: Hashable>: View {
    struct Item: Identifiable {
        let id: ID
        let title: String
    }

    let items: [Item]
    let selection: ID?
    /// Repliée, la rangée ne montre que l'élément courant, `collapsedBefore` éléments avant lui et
    /// un après ; elle s'ouvre sur toute la largeur dès qu'on la fait défiler (sessions du journal).
    var collapsedBefore: Int?
    let select: (ID) -> Void

    @State private var widths: [ID: CGFloat] = [:]
    @State private var isExpanded = false

    private let spacing: CGFloat = 22

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: spacing) {
                    ForEach(items) { item in
                        label(item)
                            .id(item.id)
                            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { widths[item.id] = $0 }
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: collapsedWidth ?? .infinity, alignment: .leading)
            .mask(alignment: .leading) { leadingFade }
            .onScrollPhaseChange { _, phase in
                if phase == .interacting, collapsedBefore != nil, !isExpanded {
                    withAnimation(.snappy) { isExpanded = true }
                }
            }
            .onAppear { reveal(proxy, animated: false) }
            .onChange(of: selection) {
                withAnimation(.snappy) { isExpanded = false }
                reveal(proxy, animated: true)
            }
            .onChange(of: widths.count) { reveal(proxy, animated: false) }
        }
    }

    private func label(_ item: Item) -> some View {
        let selected = item.id == selection
        return Button {
            select(item.id)
        } label: {
            Text(item.title)
                .font(.body.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(selected ? .primary : .secondary)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    if selected {
                        Capsule()
                            .fill(.tint)
                            .frame(height: 3)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Éléments visibles quand la rangée est repliée.
    private var window: ArraySlice<Item>? {
        guard let collapsedBefore, !isExpanded,
              let index = items.firstIndex(where: { $0.id == selection }) else { return nil }
        return items[max(0, index - collapsedBefore)...min(items.count - 1, index + 1)]
    }

    /// Largeur de la rangée repliée (nil : toute la largeur).
    private var collapsedWidth: CGFloat? {
        guard let window, window.count < items.count else { return nil }
        let measured = window.compactMap { widths[$0.id] }
        guard measured.count == window.count else { return nil }
        return measured.reduce(0, +) + spacing * CGFloat(window.count - 1) + 32
    }

    /// Les éléments plus anciens, cachés à gauche, s'estompent.
    private var leadingFade: some View {
        let hidesEarlier = window.map { $0.startIndex > 0 } ?? false
        return HStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(hidesEarlier ? 0 : 1), .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: 24)
            Color.black
        }
    }

    private func reveal(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let selection else { return }
        // Repliée : le dernier élément de la fenêtre au bord droit ; sinon, l'élément courant visible.
        let target = window?.last?.id ?? selection
        let anchor: UnitPoint? = window != nil ? .trailing : nil
        if animated {
            withAnimation { proxy.scrollTo(target, anchor: anchor) }
        } else {
            proxy.scrollTo(target, anchor: anchor)
        }
    }
}
