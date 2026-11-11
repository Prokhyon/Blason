import SwiftUI
import SheetKit

/// Carte d'une section : titre, puis champs ou tableau.
struct SectionCard: View {
    let section: SheetSection

    @Environment(\.sheetMode) private var mode
    @Environment(\.structureEditor) private var editor
    @Environment(\.sheetTheme) private var theme

    var body: some View {
        theme.sectionFrame(SectionFrameConfiguration(title: title, content: AnyView(content)))
            .structureItem(.section(section))
    }

    /// Titre mis en forme par le thème ; le cadre du thème décide où le poser.
    private var title: AnyView? {
        if mode == .structure && section.title.isEmpty {
            return AnyView(Text("Section sans titre")
                .font(theme.sectionTitleFont)
                .foregroundStyle(.tertiary))
        }
        guard !section.title.isEmpty else { return nil }
        return AnyView(Text(section.title)
            .font(theme.sectionTitleFont)
            .textCase(theme.sectionTitleCase)
            .tracking(theme.sectionTitleTracking)
            .sheetHeading(theme)
            .accessibilityAddTraits(.isHeader))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch section.kind {
            case .fields:
                FieldsSectionView(section: section)
            case .table:
                TableSectionView(section: section)
            }
            if mode == .structure, let editor {
                addBar(editor)
            }
        }
    }

    /// Ajouts en bas de section : champ (par type) ou colonne / groupe, et « Coller une liste ».
    @ViewBuilder
    private func addBar(_ editor: StructureEditor) -> some View {
        AddButtonsBar {
            switch section.kind {
            case .fields:
                Menu {
                    ForEach(FieldKind.allCases, id: \.self) { kind in
                        Button {
                            editor.addField(kind, to: section)
                        } label: {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                    }
                } label: {
                    AddButtonLabel(title: "Champ")
                }
            case .table:
                Menu {
                    ForEach(ColumnKind.allCases, id: \.self) { kind in
                        Button {
                            editor.addColumn(kind, to: section)
                        } label: {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                    }
                } label: {
                    AddButtonLabel(title: "Colonne")
                }
                Button {
                    editor.addGroup(to: section)
                } label: {
                    AddButtonLabel(title: "Groupe")
                }
            }
            Button {
                editor.requestPasteList(into: section)
            } label: {
                AddButtonLabel(title: "Coller une liste", systemImage: "list.clipboard")
            }
        }
        .padding(.top, 4)
    }
}

/// Champs d'une section selon sa disposition : liste, grille ou listes côte à côte.
struct FieldsSectionView: View {
    let section: SheetSection

    @Environment(\.sheetMode) private var mode
    @State private var width: CGFloat = 0

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

    /// Nombre de colonnes qui tiennent dans la largeur : une section étroite (colonne de page étroite,
    /// inspecteur ouvert, grand texte) passe à moins de colonnes plutôt que de couper ses libellés.
    private var fittingCount: Int {
        let wanted = max(1, section.columnCount)
        guard width > 0 else { return wanted }
        let minimum: CGFloat = (mode == .fill ? 240 : 190) * scale
        return min(wanted, max(1, Int((width + 20) / (minimum + 20))))
    }

    @ScaledMetric(relativeTo: .subheadline) private var scale: CGFloat = 1

    @ViewBuilder
    private var content: some View {
        let fields = section.sortedFields
        let count = fittingCount
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
                Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 10) {
                    ForEach(Self.gridLines(fields, columns: count)) { line in
                        GridRow {
                            ForEach(line.fields) { field in
                                FieldView(field: field)
                                    .structureItem(.field(field))
                                    .gridCellColumns(line.spansAll ? count : 1)
                            }
                        }
                    }
                }
            case .columns:
                HStack(alignment: .top, spacing: 20) {
                    ForEach(0..<count, id: \.self) { list in
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(fields.filter { min($0.listIndex, count - 1) == list }) { field in
                                FieldView(field: field)
                                    .structureItem(.field(field))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
            }
        }
    }

    /// Un champ seul dont le libellé répète le titre de la section n'affiche pas son libellé.
    private func hidesLabel(_ field: SheetField) -> Bool {
        mode != .structure && section.fields?.count == 1 && field.label == section.title
    }

    struct GridLine: Identifiable {
        let id: Int
        let fields: [SheetField]
        let spansAll: Bool
    }

    /// Découpe en lignes de `columns` champs ; texte long et image occupent une ligne entière.
    static func gridLines(_ fields: [SheetField], columns: Int) -> [GridLine] {
        var lines: [GridLine] = []
        var current: [SheetField] = []
        func flush() {
            if !current.isEmpty { lines.append(GridLine(id: lines.count, fields: current, spansAll: false)) }
            current = []
        }
        for field in fields {
            if field.kind == .longText || field.kind == .image {
                flush()
                lines.append(GridLine(id: lines.count, fields: [field], spansAll: true))
            } else {
                current.append(field)
                if current.count == columns { flush() }
            }
        }
        flush()
        return lines
    }
}
