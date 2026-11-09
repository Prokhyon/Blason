import SwiftUI
import SheetKit

/// Carte d'une section : titre, puis champs ou tableau.
struct SectionCard: View {
    let section: SheetSection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.headline)
            switch section.kind {
            case .fields:
                FieldsSectionView(section: section)
            case .table:
                TableSectionView(section: section)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// Champs d'une section selon sa disposition : liste, grille ou listes côte à côte.
struct FieldsSectionView: View {
    let section: SheetSection

    var body: some View {
        let fields = section.sortedFields
        let count = max(1, section.columnCount)
        if fields.isEmpty {
            Text("Aucun champ").font(.callout).foregroundStyle(.secondary)
        } else {
            switch section.arrangement {
            case .list:
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(fields) { field in
                        FieldView(field: field, hideLabel: hidesLabel(field))
                    }
                }
            case .grid:
                Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 10) {
                    ForEach(Self.gridLines(fields, columns: count)) { line in
                        GridRow {
                            ForEach(line.fields) { field in
                                FieldView(field: field)
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
        section.fields?.count == 1 && field.label == section.title
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
