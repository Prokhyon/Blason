import SwiftUI
import SwiftData
import SheetKit

/// Champ de texte de l'inspecteur qui a le focus.
enum InspectorFocus: Hashable {
    /// Libellé ou titre de l'élément : reçoit le curseur après une création ; Entrée crée le suivant.
    case label
    case other(String)
}

/// Inspecteur du mode Structure : propriétés de l'élément sélectionné.
/// (Panneau maison plutôt que `.inspector` : celui-ci empêche d'ouvrir la fiche
/// dans la pile de navigation de la bibliothèque sur iPadOS 26.)
struct StructureInspector: View {
    @Bindable var editor: StructureEditor
    let isTemplate: Bool
    let onClose: () -> Void

    @FocusState private var focus: InspectorFocus?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Label("Masquer l'inspecteur", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()
            content
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: focus) { _, value in
            editor.isEditingText = value != nil
        }
        .task(id: editor.primary) {
            guard let item = editor.primary, editor.focusLabel == item else { return }
            editor.focusLabel = nil
            try? await Task.sleep(for: .milliseconds(150))
            focus = .label
        }
    }

    private var title: LocalizedStringKey {
        let items = editor.liveSelection
        if items.count > 1 { return "\(items.count) éléments" }
        return items.first?.kindName ?? "Inspecteur"
    }

    @ViewBuilder
    private var content: some View {
        let items = editor.liveSelection
        if items.count > 1 {
            Form {
                Section {
                    ForEach(items, id: \.self) { item in
                        Label {
                            Text(item.displayName)
                        } icon: {
                            Text(item.kindName).font(.caption).foregroundStyle(.secondary)
                        }
                        .labelStyle(.titleOnly)
                    }
                } footer: {
                    Text("Copier, dupliquer ou supprimer agit sur toute la sélection.")
                }
                Section {
                    EditCommands(editor: editor)
                }
            }
        } else if let item = items.first {
            Group {
                switch item {
                case .page(let page): PageInspector(page: page, editor: editor, focus: $focus)
                case .row(let row): RowInspector(row: row, editor: editor)
                case .section(let section): SectionInspector(section: section, editor: editor, focus: $focus)
                case .field(let field): FieldInspector(field: field, editor: editor, isTemplate: isTemplate, focus: $focus)
                case .column(let column): ColumnInspector(column: column, editor: editor, focus: $focus)
                case .group(let group): GroupInspector(group: group, editor: editor, focus: $focus)
                case .tableRow(let row): TableRowInspector(row: row, editor: editor, isTemplate: isTemplate, focus: $focus)
                }
            }
            .id(item)
        } else {
            Form {
                Section {
                    Text("Touchez un élément de la fiche pour le modifier : page, rangée, section, champ, colonne, groupe ou ligne.")
                }
                Section("Astuces") {
                    Label("⌘ ou ⇧ + toucher : sélection multiple", systemImage: "checkmark.circle")
                    Label("Maintenir puis glisser : déplacer un élément", systemImage: "hand.draw")
                    Label("Entrée dans un libellé : crée l'élément suivant", systemImage: "return")
                    Label("⌘C ⌘V ⌘D ⌘⌫ : copier, coller, dupliquer, supprimer", systemImage: "keyboard")
                }
                Section {
                    Text("Une ligne par élément, valeurs séparées par « ; » ou une tabulation.")
                    Text("Champs : `Force;11;FOR` (libellé, valeur, code)")
                    Text("Tableau : `Marchander;5`, `# Communication` pour un groupe, `Langue (…)` pour une spécialisation à préciser")
                } header: {
                    Text("Coller une liste")
                }
                .font(.callout)
            }
        }
    }
}

extension StructureItem {
    /// Nom lisible de l'élément (libellé ou titre).
    var displayName: String {
        let name: String = switch self {
        case .page(let page): page.title
        case .row(let row): "\(row.columnCount) colonne(s)"
        case .section(let section): section.title
        case .field(let field): field.label
        case .column(let column): column.title
        case .group(let group): group.title
        case .tableRow(let row): row.displayLabel
        }
        return name.isEmpty ? String(localized: "Sans titre") : name
    }
}

// MARK: - Outils communs

/// Liaison texte vers une propriété optionnelle (vide ↔ nil).
private func optionalText(_ binding: Binding<String?>) -> Binding<String> {
    Binding(
        get: { binding.wrappedValue ?? "" },
        set: { binding.wrappedValue = $0.isEmpty ? nil : $0 }
    )
}

/// Ligne « libellé : saisie » compacte.
private struct InspectorTextRow: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var prompt: String = ""
    var focus: FocusState<InspectorFocus?>.Binding
    var focusValue: InspectorFocus
    var monospaced = false
    var onSubmit: (() -> Void)?

    var body: some View {
        LabeledContent(title) {
            TextField("", text: $text, prompt: Text(prompt))
                .multilineTextAlignment(.trailing)
                .font(monospaced ? .body.monospaced() : .body)
                .focused(focus, equals: focusValue)
                .submitLabel(onSubmit == nil ? .done : .next)
                .onSubmit { onSubmit?() }
        }
    }
}

/// Saisie validée à la sortie du champ (pour les valeurs interprétées : nombres, formules).
private struct CommittingTextField: View {
    let title: String
    let value: String
    var focus: FocusState<InspectorFocus?>.Binding
    let id: String
    let commit: (String) -> Void

    @State private var draft = ""

    var body: some View {
        LabeledContent(title) {
            TextField("", text: $draft, prompt: Text("—"))
                .multilineTextAlignment(.trailing)
                .focused(focus, equals: .other(id))
                .onSubmit { commit(draft) }
        }
        .onAppear { draft = value }
        .onChange(of: value) { _, newValue in
            if focus.wrappedValue != .other(id) { draft = newValue }
        }
        .onChange(of: focus.wrappedValue) { old, new in
            if old == .other(id) && new != .other(id) { commit(draft) }
        }
    }
}

/// Monter / descendre, dupliquer, copier, supprimer.
private struct ItemActions<Extra: View>: View {
    let item: StructureItem
    let editor: StructureEditor
    @ViewBuilder var extra: Extra

    private var horizontal: Bool {
        if case .column = item { return true }
        if case .page = item { return true }
        return false
    }

    var body: some View {
        Section {
            HStack {
                Button {
                    editor.move(item, by: -1)
                } label: {
                    Label(horizontal ? "Vers la gauche" : "Monter", systemImage: horizontal ? "arrow.left" : "arrow.up")
                }
                .disabled(!editor.canMove(item, by: -1))
                Spacer()
                Button {
                    editor.move(item, by: 1)
                } label: {
                    Label(horizontal ? "Vers la droite" : "Descendre", systemImage: horizontal ? "arrow.right" : "arrow.down")
                }
                .disabled(!editor.canMove(item, by: 1))
            }
            .buttonStyle(.borderless)
            extra
            Button("Dupliquer", systemImage: "plus.square.on.square") {
                editor.select(item)
                editor.duplicate()
            }
            Button("Copier", systemImage: "doc.on.doc") {
                editor.select(item)
                editor.copy()
            }
            Button("Supprimer", systemImage: "trash", role: .destructive) {
                editor.select(item)
                editor.delete()
            }
        }
    }
}

extension ItemActions where Extra == EmptyView {
    init(item: StructureItem, editor: StructureEditor) {
        self.init(item: item, editor: editor) { EmptyView() }
    }
}

// MARK: - Page

private struct PageInspector: View {
    @Bindable var page: Page
    let editor: StructureEditor
    var focus: FocusState<InspectorFocus?>.Binding

    var body: some View {
        Form {
            Section {
                InspectorTextRow(title: "Titre", text: $page.title, prompt: "Titre de l'onglet", focus: focus, focusValue: .label)
            }
            Section {
                Button("Ajouter une rangée", systemImage: "plus") {
                    editor.addRow(columns: 1, to: page)
                }
            }
            ItemActions(item: .page(page), editor: editor)
        }
    }
}

// MARK: - Rangée

private struct RowInspector: View {
    @Bindable var row: SheetRow
    let editor: StructureEditor

    var body: some View {
        Form {
            Section {
                Stepper("Colonnes : \(row.columnCount)", value: Binding(
                    get: { row.columnCount },
                    set: { row.setColumnCount($0) }
                ), in: 1...4)
                if row.columnCount > 1 {
                    ForEach(0..<row.columnCount, id: \.self) { index in
                        Stepper("Largeur de la colonne \(index + 1) : \(Int(row.columnWeights[index]))", value: Binding(
                            get: { Int(row.columnWeights[index]) },
                            set: { row.columnWeights[index] = Double($0) }
                        ), in: 1...6)
                    }
                }
            } footer: {
                Text("Largeurs relatives : 2 et 1 donnent ⅔ et ⅓. Sur un écran étroit, les colonnes s'empilent. Réduire le nombre de colonnes regroupe leurs sections dans la dernière.")
            }
            if let page = row.page {
                Section {
                    Button("Ajouter une rangée en dessous", systemImage: "plus") {
                        editor.addRow(columns: 1, to: page)
                    }
                }
            }
            ItemActions(item: .row(row), editor: editor)
        }
    }
}

// MARK: - Section

private struct SectionInspector: View {
    @Bindable var section: SheetSection
    let editor: StructureEditor
    var focus: FocusState<InspectorFocus?>.Binding

    var body: some View {
        Form {
            Section {
                InspectorTextRow(title: "Titre", text: $section.title, prompt: "Titre", focus: focus, focusValue: .label)
                LabeledContent("Contenu", value: section.kind == .fields ? "Champs" : "Tableau")
            }

            switch section.kind {
            case .fields:
                Section("Disposition") {
                    Picker("Disposition", selection: $section.arrangement) {
                        ForEach(FieldArrangement.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                    if section.arrangement != .list {
                        Stepper("\(section.arrangement == .grid ? "Colonnes" : "Listes") : \(section.columnCount)",
                                value: $section.columnCount, in: 1...6)
                    }
                }
            case .table:
                Section {
                    InspectorTextRow(title: "Colonne des libellés", text: $section.labelColumnTitle, prompt: "ex. Compétence",
                                     focus: focus, focusValue: .other("labelColumn"))
                    Stepper("Colonnes d'affichage : \(section.columnCount)", value: $section.columnCount, in: 1...4)
                } header: {
                    Text("Tableau")
                } footer: {
                    Text("Avec plusieurs colonnes d'affichage, les groupes se répartissent côte à côte quand la largeur le permet.")
                }
                Section("Colonnes") {
                    ForEach(section.sortedColumns) { column in
                        Button {
                            editor.select(.column(column))
                        } label: {
                            Label(column.title.isEmpty ? "Sans titre" : column.title, systemImage: column.kind.symbol)
                        }
                    }
                    Menu {
                        ForEach(ColumnKind.allCases, id: \.self) { kind in
                            Button {
                                editor.addColumn(kind, to: section)
                            } label: {
                                Label(kind.title, systemImage: kind.symbol)
                            }
                        }
                    } label: {
                        Label("Ajouter une colonne", systemImage: "plus")
                    }
                }
            }

            if let row = section.row {
                Section("Placement") {
                    if row.columnCount > 1 {
                        Picker("Colonne de la rangée", selection: Binding(
                            get: { row.effectiveColumn(of: section) },
                            set: { section.move(to: row, column: $0) }
                        )) {
                            ForEach(0..<row.columnCount, id: \.self) { Text("\($0 + 1)").tag($0) }
                        }
                    }
                    Menu("Déplacer vers une autre rangée…") {
                        ForEach(editor.pages) { page in
                            Section(page.title.isEmpty ? "Sans titre" : page.title) {
                                ForEach(Array(page.sortedRows.enumerated()), id: \.element.id) { index, target in
                                    Button("Rangée \(index + 1) (\(target.columnCount) col.)") {
                                        section.move(to: target, column: 0)
                                        if let pageIndex = editor.pages.firstIndex(where: { $0 === page }) {
                                            editor.pageIndex = pageIndex
                                        }
                                    }
                                    .disabled(target === row)
                                }
                            }
                        }
                    }
                }
            }
            ItemActions(item: .section(section), editor: editor)
        }
    }
}

// MARK: - Champ

private struct FieldInspector: View {
    @Bindable var field: SheetField
    let editor: StructureEditor
    let isTemplate: Bool
    var focus: FocusState<InspectorFocus?>.Binding

    private var sheet: Sheet? { field.section?.row?.page?.sheet }

    private var codeConflict: Bool {
        guard !field.code.isEmpty, let sheet else { return false }
        return sheet.uniqueFieldCode(field.code, excluding: field) != field.code
    }

    var body: some View {
        Form {
            Section {
                InspectorTextRow(title: "Libellé", text: $field.label, prompt: "Libellé", focus: focus, focusValue: .label) {
                    editor.addNext(after: .field(field))
                }
                InspectorTextRow(title: "Code", text: Binding(
                    get: { field.code },
                    set: { field.code = $0.filter { !$0.isWhitespace } }
                ), prompt: "ex. FOR", focus: focus, focusValue: .other("code"), monospaced: true)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                Picker("Type", selection: Binding(
                    get: { field.kind },
                    set: { kind in
                        field.kind = kind
                        if kind == .resource { field.isLive = true }
                    }
                )) {
                    ForEach(FieldKind.allCases, id: \.self) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }
            } footer: {
                if codeConflict {
                    Text("Ce code est déjà utilisé par un autre champ de la fiche.")
                        .foregroundStyle(.red)
                } else {
                    Text("Le code sert dans les formules (ex. =FOR*5). Entrée dans le libellé crée le champ suivant, du même type.")
                }
            }

            if field.kind != .formula {
                Section(isTemplate ? "Valeur par défaut" : "Valeur") {
                    FieldView(field: field, hideLabel: true)
                        .environment(\.sheetMode, .fill)
                }
            }

            kindSpecific

            if field.kind != .image {
                Section {
                    InspectorTextRow(title: field.kind == .resource ? "Maximum" : "Formule",
                                     text: optionalText($field.formula), prompt: "=FOR*5",
                                     focus: focus, focusValue: .other("formula"), monospaced: true)
                    if let result = FormulaEngine(sheet: sheet).computed(field) {
                        LabeledContent("Résultat") {
                            ComputedValueText(result: result)
                        }
                    }
                } header: {
                    Text("Formule")
                } footer: {
                    Text(formulaHelp)
                }
            }

            Section("Affichage") {
                Toggle("Modifiable en mode Jouer", isOn: $field.isLive)
                Picker("Libellé", selection: $field.labelPlacement) {
                    ForEach(LabelPlacement.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                if let section = field.section, section.arrangement == .columns, section.columnCount > 1 {
                    Stepper("Liste \(min(field.listIndex, section.columnCount - 1) + 1)", value: $field.listIndex,
                            in: 0...(section.columnCount - 1))
                }
                if field.kind == .text {
                    Toggle("Nom du personnage", isOn: Binding(
                        get: { field.isNameField },
                        set: { isName in
                            if isName {
                                for other in sheet?.allFields ?? [] where other !== field { other.isNameField = false }
                            }
                            field.isNameField = isName
                        }
                    ))
                }
            }

            ItemActions(item: .field(field), editor: editor) {
                Menu("Déplacer vers une autre section…") {
                    ForEach(editor.pages) { page in
                        Section(page.title.isEmpty ? "Sans titre" : page.title) {
                            ForEach(page.sortedRows.flatMap(\.sortedSections).filter { $0.kind == .fields }) { target in
                                Button(target.title.isEmpty ? "Section sans titre" : target.title) {
                                    field.move(to: target)
                                }
                                .disabled(target === field.section)
                            }
                        }
                    }
                }
            }
        }
    }

    private var formulaHelp: LocalizedStringKey {
        switch field.kind {
        case .formula: "La valeur est calculée et ne se saisit pas. Codes des champs, + − × ÷, parenthèses, plafond, plancher, arrondi, min, max. Ex. =FOR*5."
        case .resource: "Calcule le maximum de la ressource, ex. =plafond((CON+TAI)/2). PV désigne la valeur actuelle, PV.max le maximum."
        default: "Valeur par défaut calculée (ex. =POU*5) ; une valeur saisie la remplace, l'effacer revient au calcul."
        }
    }

    @ViewBuilder
    private var kindSpecific: some View {
        switch field.kind {
        case .integer, .decimal, .percentage:
            Section("Nombre") {
                if field.kind != .percentage {
                    InspectorTextRow(title: "Unité", text: optionalText($field.unit), prompt: "ex. m, kg",
                                     focus: focus, focusValue: .other("unit"))
                }
                LabeledContent("Minimum") { NumberField(value: $field.minimum, integer: false, prompt: "—", width: 80) }
                LabeledContent("Maximum") { NumberField(value: $field.maximum, integer: false, prompt: "—", width: 80) }
            }
        case .resource:
            Section("Ressource") {
                Picker("Affichage", selection: $field.resourceStyle) {
                    ForEach(ResourceStyle.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
        case .choice:
            Section {
                TextField("Options", text: Binding(
                    get: { field.options.joined(separator: "\n") },
                    set: { field.options = $0.components(separatedBy: "\n") }
                ), axis: .vertical)
                .lineLimit(3...12)
                .focused(focus, equals: .other("options"))
            } header: {
                Text("Options")
            } footer: {
                Text("Une option par ligne.")
            }
        case .text, .longText:
            Section {
                InspectorTextRow(title: "Indication", text: optionalText($field.hint), prompt: "texte grisé quand vide",
                                 focus: focus, focusValue: .other("hint"))
            }
        default:
            EmptyView()
        }
    }
}

// MARK: - Colonne de tableau

private struct ColumnInspector: View {
    @Bindable var column: SheetTableColumn
    let editor: StructureEditor
    var focus: FocusState<InspectorFocus?>.Binding

    private var codeConflict: Bool {
        guard !column.code.isEmpty else { return false }
        return (column.section?.columns ?? []).contains {
            $0 !== column && $0.code.caseInsensitiveCompare(column.code) == .orderedSame
        }
    }

    var body: some View {
        Form {
            Section {
                InspectorTextRow(title: "Titre", text: $column.title, prompt: "Titre", focus: focus, focusValue: .label) {
                    editor.addNext(after: .column(column))
                }
                InspectorTextRow(title: "Code", text: Binding(
                    get: { column.code },
                    set: { column.code = $0.filter { !$0.isWhitespace } }
                ), prompt: "ex. valeur", focus: focus, focusValue: .other("code"), monospaced: true)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                Picker("Type", selection: $column.kind) {
                    ForEach(ColumnKind.allCases, id: \.self) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }
                if column.kind != .text && column.kind != .checkbox {
                    InspectorTextRow(title: "Formule", text: optionalText($column.formula), prompt: "=valeur/2",
                                     focus: focus, focusValue: .other("formula"), monospaced: true)
                    if let formula = column.formula, let error = FormulaEngine.check(formula) {
                        FormulaErrorBadge(error: error, showsMessage: true)
                    }
                }
                Toggle("Modifiable en mode Jouer", isOn: $column.isLive)
            } footer: {
                if codeConflict {
                    Text("Ce code est déjà utilisé par une autre colonne du tableau.").foregroundStyle(.red)
                } else {
                    Text("Le code sert dans les formules de ligne (ex. =valeur/2). La formule s'applique à chaque ligne : calculée pour une colonne « Calcul », valeur par défaut sinon. « groupe » désigne la valeur du groupe (ex. =base+groupe).")
                }
            }
            ItemActions(item: .column(column), editor: editor)
        }
    }
}

// MARK: - Groupe

private struct GroupInspector: View {
    @Bindable var group: SheetTableGroup
    let editor: StructureEditor
    var focus: FocusState<InspectorFocus?>.Binding

    var body: some View {
        Form {
            Section {
                InspectorTextRow(title: "Titre", text: $group.title, prompt: "ex. Communication", focus: focus, focusValue: .label) {
                    editor.addNext(after: .group(group))
                }
                Toggle("Valeur de groupe", isOn: $group.hasValue)
                if group.hasValue {
                    LabeledContent("Valeur") { NumberField(value: $group.numberValue, prompt: "±", width: 70) }
                }
            } footer: {
                Text("Une valeur de groupe sert par exemple au bonus de catégorie de BRP.")
            }
            Section {
                Button("Ajouter une ligne", systemImage: "plus") {
                    editor.addTableRow(to: group)
                }
                if let section = group.section {
                    Button("Coller des lignes", systemImage: "list.clipboard") {
                        editor.requestPasteList(into: section, group: group)
                    }
                }
            }
            ItemActions(item: .group(group), editor: editor)
        }
    }
}

// MARK: - Ligne de tableau

private struct TableRowInspector: View {
    @Bindable var row: SheetTableRow
    let editor: StructureEditor
    let isTemplate: Bool
    var focus: FocusState<InspectorFocus?>.Binding

    var body: some View {
        Form {
            Section {
                InspectorTextRow(title: "Libellé", text: $row.label, prompt: "Libellé", focus: focus, focusValue: .label) {
                    editor.addNext(after: .tableRow(row))
                }
                Toggle("Spécialisation", isOn: $row.allowsSpecialization)
                if row.allowsSpecialization {
                    InspectorTextRow(title: "Précision", text: optionalText($row.specialization), prompt: "à préciser",
                                     focus: focus, focusValue: .other("specialization"))
                }
            } footer: {
                Text("Une spécialisation se précise sur la fiche : « Langue (Latin) », « Monter (Navire) ».")
            }

            if let section = row.group?.section {
                let columns = section.sortedColumns.filter { $0.kind != .formula }
                if !columns.isEmpty {
                    Section {
                        ForEach(columns) { column in
                            if let cell = row.cell(for: column) {
                                cellEditor(cell, column: column)
                            }
                        }
                    } header: {
                        Text(isTemplate ? "Valeurs par défaut" : "Valeurs")
                    } footer: {
                        Text("Une valeur commençant par « = » est une formule (ex. =DEX*2).")
                    }
                }
            }

            ItemActions(item: .tableRow(row), editor: editor) {
                if let section = row.group?.section, section.sortedGroups.count > 1 {
                    Menu("Déplacer vers un autre groupe…") {
                        ForEach(section.sortedGroups) { group in
                            Button(group.title.isEmpty ? "Groupe sans titre" : group.title) {
                                if let context = row.modelContext {
                                    row.move(to: group, in: context)
                                }
                            }
                            .disabled(group === row.group)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellEditor(_ cell: SheetTableCell, column: SheetTableColumn) -> some View {
        let title = column.title.isEmpty ? String(localized: "Sans titre") : column.title
        if column.kind == .checkbox {
            Toggle(title, isOn: Binding(
                get: { cell.boolValue == true },
                set: { cell.boolValue = $0 }
            ))
        } else {
            CommittingTextField(
                title: title,
                value: cell.formula ?? cell.displayValue,
                focus: focus,
                id: "cell-\(column.persistentModelID.hashValue)"
            ) { text in
                cell.textValue = nil
                cell.numberValue = nil
                cell.formula = nil
                cell.applyText(text, kind: column.kind)
            }
        }
    }
}
