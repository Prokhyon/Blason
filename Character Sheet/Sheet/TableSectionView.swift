import SwiftUI
import SwiftData
import SheetKit

/// Section « Tableau » : groupes de lignes répartis sur `columnCount` colonnes d'affichage.
struct TableSectionView: View {
    let section: SheetSection

    @Environment(\.sheetMode) private var mode
    @State private var width: CGFloat = 0

    /// Nombre de colonnes d'affichage qui tiennent dans la largeur disponible
    /// (la saisie demande plus de place que la lecture).
    private func fittingColumns(_ wanted: Int) -> Int {
        guard width > 0 else { return wanted }
        let minimum: CGFloat = mode == .fill ? 360 : 250
        return min(wanted, max(1, Int((width + 24) / (minimum + 24))))
    }

    var body: some View {
        let columns = section.sortedColumns
        let groups = section.sortedGroups
        let displayColumns = fittingColumns(max(1, section.columnCount))

        if section.columnCount > 1 {
            let buckets = Self.distribute(groups, into: displayColumns)
            HStack(alignment: .top, spacing: 24) {
                ForEach(buckets.indices, id: \.self) { index in
                    TableGrid(section: section, groups: buckets[index], columns: columns)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        } else if columns.count > 4 {
            ScrollView(.horizontal) {
                TableGrid(section: section, groups: groups, columns: columns)
            }
        } else {
            TableGrid(section: section, groups: groups, columns: columns)
        }
    }

    /// Répartit les groupes (sans les couper) en colonnes de hauteurs proches.
    static func distribute(_ groups: [SheetTableGroup], into count: Int) -> [[SheetTableGroup]] {
        let sizes = groups.map { ($0.rows?.count ?? 0) + 2 }
        let total = Double(sizes.reduce(0, +))
        var buckets: [[SheetTableGroup]] = [[]]
        var accumulated = 0.0
        for (group, size) in zip(groups, sizes) {
            let target = total * Double(buckets.count) / Double(count)
            if !buckets[buckets.count - 1].isEmpty, buckets.count < count,
               accumulated + Double(size) / 2 > target {
                buckets.append([])
            }
            buckets[buckets.count - 1].append(group)
            accumulated += Double(size)
        }
        return buckets
    }
}

/// Grille d'en-têtes, de groupes et de lignes.
private struct TableGrid: View {
    let section: SheetSection
    let groups: [SheetTableGroup]
    let columns: [SheetTableColumn]

    @Environment(\.sheetMode) private var mode
    @Environment(\.structureEditor) private var editor
    @Environment(\.modelContext) private var context

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
            GridRow {
                Text(section.labelColumnTitle)
                ForEach(columns) { column in
                    Group {
                        if column.title.isEmpty && mode == .structure {
                            Text("Sans titre").foregroundStyle(.tertiary)
                        } else {
                            Text(column.title)
                        }
                    }
                    .structureItem(.column(column))
                    .gridColumnAlignment(column.kind == .text ? .leading : .trailing)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ForEach(groups) { group in
                if !group.title.isEmpty || group.hasValue || mode == .structure {
                    GroupHeader(group: group)
                        .structureItem(.group(group))
                        .gridCellColumns(columns.count + 1)
                        .padding(.top, 6)
                }
                ForEach(group.sortedRows) { row in
                    GridRow {
                        RowLabel(row: row)
                        ForEach(columns) { column in
                            if let cell = row.cell(for: column) {
                                CellView(cell: cell, column: column)
                                    .gridColumnAlignment(column.kind == .text ? .leading : .trailing)
                            } else {
                                Color.clear.frame(width: 1, height: 1)
                            }
                        }
                    }
                }
                if mode == .fill {
                    Button {
                        section.addRow(label: "", to: group, isFromTemplate: false, in: context)
                    } label: {
                        Label("Ajouter une ligne", systemImage: "plus")
                            .font(.callout)
                    }
                    .buttonStyle(.borderless)
                    .gridCellColumns(columns.count + 1)
                } else if mode == .structure, let editor {
                    AddButtonsBar {
                        Button {
                            editor.addTableRow(to: group)
                        } label: {
                            AddButtonLabel(title: "Ligne")
                        }
                        Button {
                            editor.requestPasteList(into: section, group: group)
                        } label: {
                            AddButtonLabel(title: "Coller des lignes", systemImage: "list.clipboard")
                        }
                    }
                    .gridCellColumns(columns.count + 1)
                }
            }
        }
    }
}

/// En-tête de groupe, avec sa valeur éventuelle (bonus de catégorie).
private struct GroupHeader: View {
    @Bindable var group: SheetTableGroup
    @Environment(\.sheetMode) private var mode

    var body: some View {
        HStack(spacing: 6) {
            if group.title.isEmpty && mode == .structure {
                Text("Groupe sans titre")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                Text(group.title)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer(minLength: 8)
            if group.hasValue {
                if mode == .fill {
                    NumberField(value: $group.numberValue, prompt: "±", width: 48)
                } else if let value = group.numberValue {
                    Text(SheetFormat.number(value)).monospacedDigit()
                }
                Text("%").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Libellé d'une ligne, avec sa spécialisation ; menu contextuel en mode Remplir.
private struct RowLabel: View {
    @Bindable var row: SheetTableRow
    @Environment(\.sheetMode) private var mode
    @Environment(\.modelContext) private var context

    var body: some View {
        if mode == .structure {
            HStack(spacing: 4) {
                if row.label.isEmpty {
                    Text("Sans libellé").foregroundStyle(.tertiary)
                } else {
                    Text(row.label)
                }
                if row.allowsSpecialization {
                    Text("(\(row.specialization ?? "…"))").foregroundStyle(.secondary)
                }
            }
            .lineLimit(1)
            .structureItem(.tableRow(row))
        } else {
            editableLabel
        }
    }

    private var editableLabel: some View {
        HStack(spacing: 4) {
            if mode == .fill && !row.isFromTemplate {
                TextField("", text: $row.label, prompt: Text("Nom"))
                    .frame(minWidth: 80)
                    .inputBackground()
            } else {
                Text(row.label)
            }
            if row.allowsSpecialization {
                if mode == .fill {
                    TextField("", text: specialization, prompt: Text("précision"))
                        .frame(minWidth: 70)
                        .inputBackground()
                } else if let value = row.specialization, !value.isEmpty {
                    Text("(\(value))").foregroundStyle(.secondary)
                }
            }
        }
        .lineLimit(1)
        .contextMenu {
            if mode == .fill {
                Button("Dupliquer la ligne", systemImage: "plus.square.on.square") {
                    row.duplicate(in: context)
                }
                Button("Supprimer la ligne", systemImage: "trash", role: .destructive) {
                    context.delete(row)
                }
            }
        }
    }

    private var specialization: Binding<String> {
        Binding(
            get: { row.specialization ?? "" },
            set: { row.specialization = $0.isEmpty ? nil : $0 }
        )
    }
}

/// Cellule, selon le type de sa colonne.
private struct CellView: View {
    @Bindable var cell: SheetTableCell
    let column: SheetTableColumn

    @Environment(\.sheetMode) private var mode

    private var editable: Bool {
        column.kind != .formula && mode.canEdit(live: column.isLive)
    }

    var body: some View {
        switch column.kind {
        case .text:
            if editable {
                TextField("", text: Binding(
                    get: { cell.textValue ?? "" },
                    set: { cell.textValue = $0.isEmpty ? nil : $0 }
                ))
                .frame(minWidth: 60)
                .inputBackground()
            } else {
                Text(cell.textValue ?? "")
            }
        case .number, .percentage:
            if editable {
                let computed = engine.computed(cell)
                HStack(spacing: 2) {
                    NumberField(value: $cell.numberValue, prompt: computed?.promptText, width: 52)
                    if cell.numberValue == nil, case .failure(let error)? = computed {
                        FormulaErrorBadge(error: error)
                    }
                }
            } else {
                ComputedValueText(result: engine.value(of: cell))
            }
        case .checkbox:
            CheckboxButton(isOn: Binding(
                get: { cell.boolValue == true },
                set: { cell.boolValue = $0 }
            ), enabled: editable)
        case .formula:
            ComputedValueText(result: engine.value(of: cell))
        }
    }

    /// Moteur neuf à chaque affichage (voir `FieldView.engine`).
    private var engine: FormulaEngine { FormulaEngine(sheet: cell.sheet) }
}
