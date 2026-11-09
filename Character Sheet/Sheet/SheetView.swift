import SwiftUI
import Combine
import SwiftData
import SheetKit

/// Fiche complète : onglets de pages, sélecteur de mode, contenu de la page ;
/// en mode Structure, inspecteur à droite et commandes d'édition.
struct SheetView: View {
    let title: String
    let sheet: Sheet?
    /// Appelé après chaque enregistrement d'une modification faite pendant que la fiche est ouverte
    /// (sert à mettre à jour la date de modification du personnage ou du template).
    var onEdit: () -> Void = {}

    @State private var mode: SheetMode
    @State private var editor: StructureEditor
    @State private var showsInspector = true
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(title: String, sheet: Sheet?, initialMode: SheetMode, onEdit: @escaping () -> Void = {}) {
        self.title = title
        self.sheet = sheet
        self.onEdit = onEdit
        var mode = initialMode
        let editor = StructureEditor(sheet: sheet)
        #if DEBUG
        // Arguments de lancement pour les captures : -demoMode structure -demoPage 1 -demoSelect FOR
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "demoMode"), let value = SheetMode(rawValue: raw) {
            mode = value
        }
        editor.pageIndex = defaults.integer(forKey: "demoPage")
        if let code = defaults.string(forKey: "demoSelect") {
            if let field = sheet?.field(code: code) {
                editor.select(.field(field))
            } else if let section = sheet?.section(titled: code) {
                editor.select(.section(section))
            }
        }
        #endif
        _mode = State(initialValue: mode)
        _editor = State(initialValue: editor)
    }

    var body: some View {
        HStack(spacing: 0) {
            sheetContent
            if showsSidePanel {
                Divider().ignoresSafeArea(edges: .bottom)
                StructureInspector(editor: editor, isTemplate: sheet?.template != nil) {
                    showsInspector = false
                }
                .frame(width: 340)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.default, value: showsSidePanel)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(isPresented: compactInspectorShown) {
            StructureInspector(editor: editor, isTemplate: sheet?.template != nil) {
                showsInspector = false
            }
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .environment(\.structureEditor, editor)
        }
        .sheet(item: $editor.pasteList) { request in
            PasteListView(request: request, editor: editor)
        }
        .background { if mode == .structure { shortcuts } }
        .environment(\.sheetMode, mode)
        .environment(\.structureEditor, editor)
        .onChange(of: mode) { _, newMode in
            if newMode != .structure { editor.clearSelection() }
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { notification in
            if Self.containsSheetEdit(notification, owner: sheet?.character?.persistentModelID ?? sheet?.template?.persistentModelID) {
                onEdit()
            }
        }
    }

    /// Inspecteur en panneau latéral sur grand écran, en feuille sur écran étroit.
    private var showsSidePanel: Bool {
        mode == .structure && showsInspector && sizeClass != .compact
    }

    private var compactInspectorShown: Binding<Bool> {
        Binding(
            get: { mode == .structure && showsInspector && sizeClass == .compact },
            set: { showsInspector = $0 }
        )
    }

    /// Onglets et page affichée.
    private var sheetContent: some View {
        Group {
            if let page = editor.currentPage {
                PageView(page: page)
                    .id(page.persistentModelID)
            } else {
                emptySheet
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if editor.pages.count > 1 || (mode == .structure && !editor.pages.isEmpty) {
                PageTabs(editor: editor, isStructure: mode == .structure)
            }
        }
        .overlay(alignment: .bottom) {
            if let notice = editor.notice {
                Text(notice)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
        .animation(.default, value: editor.notice)
    }

    @ViewBuilder
    private var emptySheet: some View {
        ContentUnavailableView {
            Label("Fiche vide", systemImage: "doc")
        } description: {
            Text(mode == .structure
                 ? "Ajoutez une première page pour construire la fiche."
                 : "Passez en mode Structure pour construire la fiche.")
        } actions: {
            if mode == .structure {
                Button("Ajouter une page") { editor.addPage() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if mode != .play {
                UndoRedoButtons()
            }
            if mode == .structure {
                Menu {
                    EditCommands(editor: editor)
                } label: {
                    Label("Édition", systemImage: "ellipsis.circle")
                }
                Button {
                    showsInspector.toggle()
                } label: {
                    Label("Inspecteur", systemImage: "sidebar.trailing")
                }
            }
        }
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

    /// Raccourcis clavier du mode Structure (inactifs pendant la saisie dans l'inspecteur,
    /// pour laisser ⌘C / ⌘V au texte).
    private var shortcuts: some View {
        Group {
            Button("Copier") { editor.copy() }
                .keyboardShortcut("c")
            Button("Coller") { editor.paste() }
                .keyboardShortcut("v")
            Button("Dupliquer") { editor.duplicate() }
                .keyboardShortcut("d")
            Button("Supprimer") { editor.delete() }
                .keyboardShortcut(.delete)
            Button("Désélectionner") { editor.clearSelection() }
                .keyboardShortcut(.escape, modifiers: [])
        }
        .disabled(editor.isEditingText)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Un enregistrement contient une modification de la fiche s'il touche autre chose que
    /// le propriétaire lui-même (dont seule la date change en réponse : pas de boucle).
    private static func containsSheetEdit(_ notification: Notification, owner: PersistentIdentifier?) -> Bool {
        SheetStore.savedIdentifiers(in: notification).contains { $0 != owner }
    }
}

/// Copier, coller, dupliquer, supprimer : la sélection courante.
struct EditCommands: View {
    let editor: StructureEditor

    var body: some View {
        Button("Copier", systemImage: "doc.on.doc") { editor.copy() }
            .disabled(!editor.canCopy)
        Button("Coller", systemImage: "doc.on.clipboard") { editor.paste() }
            .disabled(!editor.canPaste)
        Button("Dupliquer", systemImage: "plus.square.on.square") { editor.duplicate() }
            .disabled(!editor.canCopy)
        Divider()
        Button("Supprimer", systemImage: "trash", role: .destructive) { editor.delete() }
            .disabled(!editor.canCopy)
        Button("Tout désélectionner", systemImage: "xmark.circle") { editor.clearSelection() }
            .disabled(editor.selection.isEmpty)
    }
}

/// Annuler / Rétablir (⌘Z / ⇧⌘Z), sur le gestionnaire d'annulation du contexte.
struct UndoRedoButtons: View {
    @Environment(\.modelContext) private var context
    @State private var revision = 0

    private static let changes = NotificationCenter.default.publisher(for: .NSUndoManagerDidCloseUndoGroup)
        .merge(with: NotificationCenter.default.publisher(for: .NSUndoManagerDidUndoChange))
        .merge(with: NotificationCenter.default.publisher(for: .NSUndoManagerDidRedoChange))

    var body: some View {
        let _ = revision
        let manager = context.undoManager
        Button("Annuler", systemImage: "arrow.uturn.backward") { manager?.undo() }
            .keyboardShortcut("z")
            .disabled(manager?.canUndo != true)
            .onReceive(Self.changes) { _ in revision += 1 }
        Button("Rétablir", systemImage: "arrow.uturn.forward") { manager?.redo() }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(manager?.canRedo != true)
    }
}

/// Onglets des pages ; en mode Structure, ajout de page et réglages de la page affichée.
private struct PageTabs: View {
    @Bindable var editor: StructureEditor
    let isStructure: Bool

    var body: some View {
        let pages = editor.pages
        HStack(spacing: 12) {
            if !pages.isEmpty {
                Picker("Page", selection: $editor.pageIndex) {
                    ForEach(pages.indices, id: \.self) { index in
                        Text(pages[index].title.isEmpty ? "Sans titre" : pages[index].title).tag(index)
                    }
                }
                .pickerStyle(.segmented)
            }
            if isStructure {
                if let page = editor.currentPage {
                    Button {
                        editor.select(.page(page))
                    } label: {
                        Label("Réglages de la page", systemImage: "slider.horizontal.3")
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(editor.isSelected(.page(page)) ? Color.accentColor : .secondary)
                }
                Button {
                    editor.addPage()
                } label: {
                    Label("Ajouter une page", systemImage: "plus")
                }
                .labelStyle(.iconOnly)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

/// Une page : ses rangées, de haut en bas.
struct PageView: View {
    let page: Page

    @Environment(\.sheetMode) private var mode
    @Environment(\.structureEditor) private var editor

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(page.sortedRows) { row in
                    RowView(row: row)
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
            .padding()
            .background {
                if mode == .structure {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { editor?.clearSelection() }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground))
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

#Preview("Leo — Jouer") {
    NavigationStack {
        SheetView(title: "Leo", sheet: PreviewData.leo?.sheet, initialMode: .play)
    }
    .modelContainer(PreviewData.container)
}

#Preview("Leo — Structure") {
    NavigationStack {
        SheetView(title: "Leo", sheet: PreviewData.leo?.sheet, initialMode: .structure)
    }
    .modelContainer(PreviewData.container)
}
