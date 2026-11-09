import SwiftUI
import SwiftData
import SheetKit

/// Fiche complète : onglets de pages, sélecteur de mode, contenu de la page.
struct SheetView: View {
    let title: String
    let sheet: Sheet?

    @State private var mode: SheetMode
    @State private var pageIndex: Int

    init(title: String, sheet: Sheet?, initialMode: SheetMode) {
        self.title = title
        self.sheet = sheet
        var mode = initialMode
        var page = 0
        #if DEBUG
        // Arguments de lancement pour les captures : -demoMode fill -demoPage 1
        if let raw = UserDefaults.standard.string(forKey: "demoMode"), let value = SheetMode(rawValue: raw) {
            mode = value
        }
        page = UserDefaults.standard.integer(forKey: "demoPage")
        #endif
        _mode = State(initialValue: mode)
        _pageIndex = State(initialValue: page)
    }

    var body: some View {
        let pages = sheet?.sortedPages ?? []
        Group {
            if pages.isEmpty {
                ContentUnavailableView(
                    "Fiche vide",
                    systemImage: "doc",
                    description: Text("Cette fiche n'a encore aucune page. La construction de la structure arrive avec l'éditeur.")
                )
            } else {
                let page = pages[min(max(pageIndex, 0), pages.count - 1)]
                PageView(page: page)
                    .id(page.persistentModelID)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if pages.count > 1 {
                Picker("Page", selection: $pageIndex) {
                    ForEach(pages.indices, id: \.self) { index in
                        Text(pages[index].title).tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Mode", selection: $mode) {
                    ForEach(SheetMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .environment(\.sheetMode, mode)
    }
}

/// Une page : ses rangées, de haut en bas.
struct PageView: View {
    let page: Page

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(page.sortedRows) { row in
                    RowView(row: row)
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
    }
}

/// Une rangée : ses colonnes côte à côte, chacune empilant ses sections.
struct RowView: View {
    let row: SheetRow

    var body: some View {
        ColumnsLayout(weights: row.columnWeights, spacing: 16, minColumnWidth: 300) {
            ForEach(0..<row.columnCount, id: \.self) { column in
                VStack(spacing: 16) {
                    ForEach(row.sections(inColumn: column)) { section in
                        SectionCard(section: section)
                    }
                }
            }
        }
    }
}

#Preview("Leo — Jouer") {
    NavigationStack {
        SheetView(title: "Leo", sheet: PreviewData.leo?.sheet, initialMode: .play)
    }
    .modelContainer(PreviewData.container)
}

#Preview("Leo — Remplir") {
    NavigationStack {
        SheetView(title: "Leo", sheet: PreviewData.leo?.sheet, initialMode: .fill)
    }
    .modelContainer(PreviewData.container)
}
