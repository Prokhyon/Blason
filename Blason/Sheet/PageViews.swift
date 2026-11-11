import SwiftUI
import SwiftData
import SheetKit

/// Disposition des pages : une à la fois (onglets) ou toutes à la suite, avec un sommaire.
/// Préférence de l'appareil, commune à toutes les fiches.
enum SheetLayout: String, CaseIterable, Identifiable {
    case tabs
    case scroll

    static let storageKey = "sheetLayout"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .tabs: "Une page à la fois"
        case .scroll: "Toutes les pages à la suite"
        }
    }

    var symbol: String {
        switch self {
        case .tabs: "rectangle.stack"
        case .scroll: "scroll"
        }
    }
}

/// Onglets : la page choisie dans la barre, seule.
struct TabbedPages: View {
    @Bindable var editor: StructureEditor

    @Environment(\.sheetMode) private var mode

    var body: some View {
        Group {
            if let page = editor.currentPage {
                ScrollViewReader { proxy in
                    ScrollView {
                        PageContent(page: page)
                            .padding()
                            .deselectsOnBackgroundTap()
                    }
                    .scrollsToSelection(editor, proxy: proxy)
                }
                .id(page.persistentModelID)
            }
        }
        .sheetScrollStyle()
        .safeAreaInset(edge: .top, spacing: 0) {
            if editor.pages.count > 1 || mode == .structure {
                PageBar(editor: editor)
            }
        }
    }
}

/// Défilement continu : toutes les pages l'une sous l'autre, chacune sous son titre.
/// La barre suit la page visible ; le sommaire mène à une page ou à une section.
struct ContinuousPages: View {
    @Bindable var editor: StructureEditor

    @Environment(\.sheetMode) private var mode
    @Environment(\.sheetTheme) private var theme
    /// Page en haut de l'écran, tenue à jour par le défilement ; la changer fait défiler.
    @State private var visiblePage: Int?

    var body: some View {
        let pages = editor.pages
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    ForEach(pages.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 16) {
                            PageTitle(page: pages[index])
                            PageContent(page: pages[index])
                        }
                    }
                }
                .scrollTargetLayout()
                .padding()
                .deselectsOnBackgroundTap()
            }
            .scrollPosition(id: $visiblePage, anchor: .top)
            .sheetScrollStyle()
            .safeAreaInset(edge: .top, spacing: 0) {
                PageBar(editor: editor) { section in
                    withAnimation { proxy.scrollTo(section.persistentModelID, anchor: .top) }
                }
            }
            .scrollsToSelection(editor, proxy: proxy)
            .onAppear { visiblePage = editor.pageIndex }
            // Défilement par l'utilisateur → page courante (les ajouts et le collage s'y font).
            .onChange(of: visiblePage) { _, page in
                if let page, page != editor.pageIndex { editor.pageIndex = page }
            }
            // Page choisie dans la barre ou ajoutée → défilement jusqu'à elle.
            .onChange(of: editor.pageIndex) { _, page in
                if page != visiblePage { withAnimation { visiblePage = page } }
            }
        }
    }
}

/// Titre d'une page dans le défilement continu ; en Structure, il sélectionne la page.
private struct PageTitle: View {
    let page: Page

    @Environment(\.sheetMode) private var mode
    @Environment(\.sheetTheme) private var theme

    var body: some View {
        Text(page.title.isEmpty ? "Sans titre" : page.title)
            .font(theme.pageTitleFont)
            .sheetHeading(theme)
            .opacity(page.title.isEmpty ? 0.5 : 1)
            .accessibilityAddTraits(.isHeader)
            .structureItem(.page(page))
    }
}

/// Barre des pages : choix de la page, sommaire (défilement continu),
/// et en Structure réglages de la page et ajout de page.
struct PageBar: View {
    @Bindable var editor: StructureEditor
    /// Défilement continu : mène à une section depuis le sommaire.
    var showSection: ((SheetSection) -> Void)? = nil

    @Environment(\.sheetMode) private var mode
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        let pages = editor.pages
        HStack(spacing: 16) {
            if pages.count > 1 && sizeClass == .compact {
                // iPhone : les titres ne tiennent pas dans un contrôle segmenté.
                PageChips(editor: editor)
            } else if pages.count > 1 {
                Picker("Page", selection: $editor.pageIndex) {
                    ForEach(pages.indices, id: \.self) { index in
                        Text(pages[index].title.isEmpty ? "Sans titre" : pages[index].title).tag(index)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                Spacer(minLength: 0)
            }
            if let showSection {
                Menu {
                    ForEach(pages) { page in
                        Section(page.title.isEmpty ? "Sans titre" : page.title) {
                            ForEach(page.sectionsInReadingOrder.filter { !$0.title.isEmpty }) { section in
                                Button(section.title) { showSection(section) }
                            }
                        }
                    }
                } label: {
                    Label("Sommaire", systemImage: "list.bullet")
                }
            }
            if mode == .structure {
                if let page = editor.currentPage {
                    Button {
                        editor.select(.page(page))
                    } label: {
                        Label("Réglages de la page", systemImage: "slider.horizontal.3")
                    }
                    .foregroundStyle(editor.isSelected(.page(page)) ? Color.accentColor : .secondary)
                }
                Button {
                    editor.addPage()
                } label: {
                    Label("Ajouter une page", systemImage: "plus")
                }
            }
        }
        .labelStyle(.iconOnly)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

/// Pages en pastilles qui défilent horizontalement (écran étroit) ; la page choisie reste visible.
private struct PageChips: View {
    @Bindable var editor: StructureEditor

    var body: some View {
        let pages = editor.pages
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(pages.indices, id: \.self) { index in
                        let selected = index == editor.pageIndex
                        Button {
                            editor.pageIndex = index
                        } label: {
                            Text(pages[index].title.isEmpty ? "Sans titre" : pages[index].title)
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selected ? Color.accentColor.opacity(0.15) : Color.tertiaryFill,
                                            in: Capsule())
                                .foregroundStyle(selected ? Color.accentColor : .primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .id(index)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo(editor.pageIndex, anchor: .center) }
            .onChange(of: editor.pageIndex) { _, index in
                withAnimation { proxy.scrollTo(index, anchor: .center) }
            }
        }
    }
}

/// Contenu d'une page : ses rangées de haut en bas ; en Structure, l'ajout d'une rangée.
struct PageContent: View {
    let page: Page

    @Environment(\.sheetMode) private var mode
    @Environment(\.structureEditor) private var editor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(page.sortedRows) { row in
                RowView(row: row)
            }
            if page.sortedRows.isEmpty && mode != .structure {
                Text("Page vide : ajoutez-y des sections en mode Structure.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
            if mode == .structure, let editor {
                DashedAddZone {
                    Menu {
                        ForEach(1...3, id: \.self) { count in
                            Button(count == 1 ? "1 colonne" : "\(count) colonnes") {
                                editor.addRow(columns: count, to: page)
                            }
                        }
                    } label: {
                        AddButtonLabel(title: "Rangée")
                    }
                }
            }
        }
    }
}

/// Une rangée : ses colonnes côte à côte, chacune empilant ses sections.
/// En mode Structure : un en-tête sélectionnable et une zone d'ajout au bas de chaque colonne.
struct RowView: View {
    let row: SheetRow

    @Environment(\.sheetMode) private var mode

    var body: some View {
        if mode == .structure {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.split.3x1")
                    Text(row.columnCount == 1 ? "Rangée · 1 colonne" : "Rangée · \(row.columnCount) colonnes")
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .structureItem(.row(row))
                columns
            }
            .padding(8)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2, 4]))
                    .foregroundStyle(.quaternary)
            }
        } else {
            columns
        }
    }

    private var columns: some View {
        ColumnsLayout(weights: row.columnWeights, spacing: 16, minColumnWidth: 300) {
            ForEach(0..<row.columnCount, id: \.self) { column in
                VStack(spacing: 16) {
                    ForEach(row.sections(inColumn: column)) { section in
                        SectionCard(section: section)
                            .id(section.persistentModelID)
                    }
                    if mode == .structure {
                        ColumnAddZone(row: row, column: column)
                    }
                }
            }
        }
    }
}

/// Bas de colonne : ajouter une section, ou y déposer une section glissée.
private struct ColumnAddZone: View {
    let row: SheetRow
    let column: Int

    @Environment(\.structureEditor) private var editor
    @State private var isTargeted = false

    var body: some View {
        if let editor {
            DashedAddZone {
                Menu {
                    Button("Section de champs", systemImage: "list.bullet.rectangle") {
                        editor.addSection(.fields, to: row, column: column)
                    }
                    Button("Tableau", systemImage: "tablecells") {
                        editor.addSection(.table, to: row, column: column)
                    }
                } label: {
                    AddButtonLabel(title: "Section")
                }
            }
            .background(isTargeted ? Color.accentColor.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .dropDestination(for: String.self) { tokens, _ in
                tokens.contains(StructureEditor.dragToken) && editor.dropSection(into: row, column: column)
            } isTargeted: {
                isTargeted = $0
            }
        }
    }
}

extension Page {
    /// Sections dans l'ordre de lecture : rangée par rangée, colonne par colonne.
    var sectionsInReadingOrder: [SheetSection] {
        sortedRows.flatMap { row in
            (0..<row.columnCount).flatMap { row.sections(inColumn: $0) }
        }
    }
}

private extension View {
    /// Fond du thème, clavier rangé en défilant.
    func sheetScrollStyle() -> some View {
        modifier(SheetScrollStyle())
    }

    /// En Structure, toucher le fond vide désélectionne.
    func deselectsOnBackgroundTap() -> some View {
        modifier(DeselectOnBackgroundTap())
    }
}

private struct SheetScrollStyle: ViewModifier {
    @Environment(\.sheetTheme) private var theme

    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .background { theme.pageBackground().ignoresSafeArea() }
    }
}

private struct DeselectOnBackgroundTap: ViewModifier {
    @Environment(\.sheetMode) private var mode
    @Environment(\.structureEditor) private var editor

    func body(content: Content) -> some View {
        content.background {
            if mode == .structure {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { editor?.clearSelection() }
            }
        }
    }
}
