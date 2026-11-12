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
    /// Objet de la Besace ouvert (Remplir, Jouer) : panneau latéral, ou feuille sur iPhone.
    @State private var openedItem: InventoryItem?
    /// Onglet affiché : fiche, inventaire (Besace) ou journal (personnage seulement).
    @State private var tab: CharacterTab = .sheet
    /// Hauteur de la feuille de l'inspecteur (iPhone) : la fiche garde cette marge en bas
    /// pour que tout élément puisse remonter au-dessus d'elle.
    @State private var inspectorSheetHeight: CGFloat = 0
    @AppStorage(SheetLayout.storageKey) private var layout: SheetLayout = .tabs
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var context

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
        // -demoTheme paper -demoColor teal : apparence de la fiche ouverte (modifie la base de développement).
        if let theme = defaults.string(forKey: "demoTheme") {
            sheet?.ownAppearance = SheetAppearance(themeID: theme, colorID: defaults.string(forKey: "demoColor") ?? "blue")
        }
        if defaults.bool(forKey: "demoBesace"), let sheet, let context = sheet.modelContext {
            DemoData.addDemoInventory(to: sheet, in: context)
        }
        if let name = defaults.string(forKey: "demoItem") {
            _openedItem = State(initialValue: sheet?.inventories.flatMap(\.allItems).first { $0.name == name })
        }
        // -demoTab inventory | journal ; -demoJournal YES : journal d'exemple, onglet Journal.
        if let raw = defaults.string(forKey: "demoTab"), let value = CharacterTab(rawValue: raw) {
            _tab = State(initialValue: value)
        }
        if defaults.bool(forKey: "demoJournal"), let character = sheet?.character, let context = sheet?.modelContext {
            DemoData.addDemoJournal(to: character, in: context)
            _tab = State(initialValue: .journal)
        }
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
            tabContent
            if showsSidePanel {
                Divider().ignoresSafeArea(edges: .bottom)
                Group {
                    if mode == .structure {
                        StructureInspector(editor: editor, isTemplate: sheet?.template != nil) {
                            showsInspector = false
                        }
                    } else if let openedItem {
                        ItemDetailView(item: openedItem) { self.openedItem = nil }
                            .id(openedItem.persistentModelID)
                    }
                }
                .frame(width: 340)
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.default, value: showsSidePanel)
        .navigationTitle(title)
        .inlineNavigationTitle()
        .toolbar { toolbar }
        .sheet(isPresented: compactInspectorShown) {
            StructureInspector(editor: editor, isTemplate: sheet?.template != nil) {
                editor.clearSelection()
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { inspectorSheetHeight = $0 }
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .environment(\.structureEditor, editor)
        }
        .sheet(item: compactOpenedItem) { item in
            ItemDetailView(item: item) { openedItem = nil }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { inspectorSheetHeight = $0 }
                .presentationDetents([.medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .environment(\.sheetMode, mode)
        }
        .sheet(item: $editor.pasteList) { request in
            PasteListView(request: request, editor: editor)
        }
        .background { if mode == .structure { shortcuts } }
        .environment(\.sheetMode, mode)
        .focusedSceneValue(\.sheetModeBinding, $mode)
        .environment(\.structureEditor, editor)
        .environment(\.inventoryItemOpener, InventoryItemOpener { openedItem = $0 })
        .focusedSceneValue(\.characterTabBinding, $tab)
        .focusedSceneValue(\.availableCharacterTabs, availableTabs)
        .onChange(of: mode) { _, newMode in
            if newMode != .structure { editor.clearSelection() }
        }
        .onChange(of: tab) { _, newTab in
            // La sélection de la fiche ne suit pas dans un autre onglet (et inversement).
            if mode == .structure { editor.clearSelection() }
            if newTab == .journal { openedItem = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { notification in
            if Self.containsSheetEdit(notification, owner: sheet?.character?.persistentModelID ?? sheet?.template?.persistentModelID) {
                onEdit()
            }
        }
    }

    /// Onglets proposés : le journal appartient au personnage, un template n'en a pas.
    private var availableTabs: [CharacterTab] {
        sheet?.character != nil ? CharacterTab.allCases : [.sheet, .inventory]
    }

    /// Panneau latéral sur grand écran (feuille sur écran étroit) : l'inspecteur en Structure,
    /// la fiche de l'objet ouvert en Remplir et Jouer (SPEC §5.15). Le journal a ses propres panneaux.
    private var showsSidePanel: Bool {
        guard sizeClass != .compact, tab != .journal else { return false }
        return mode == .structure ? showsInspector : openedItem != nil
    }

    /// iPhone : fiche de l'objet en feuille.
    private var compactOpenedItem: Binding<InventoryItem?> {
        Binding(
            get: { mode != .structure && sizeClass == .compact && tab != .journal ? openedItem : nil },
            set: { openedItem = $0 }
        )
    }

    /// Contenu de l'onglet.
    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .sheet:
            sheetContent
        case .inventory:
            InventoryTabView(sheet: sheet)
                .safeAreaPadding(.bottom, showsCompactInspector || compactOpenedItem.wrappedValue != nil ? inspectorSheetHeight : 0)
                .sheetTheme(SheetThemes.theme(for: sheet?.appearance(in: context) ?? .standard))
        case .journal:
            if let character = sheet?.character {
                JournalScreen(character: character)
            }
        }
    }

    /// iPhone : la feuille n'apparaît qu'avec une sélection (sinon elle couvrirait la barre du bas
    /// et le choix du mode) ; la fermer désélectionne.
    private var compactInspectorShown: Binding<Bool> {
        Binding(
            get: { showsCompactInspector },
            set: { if !$0 { editor.clearSelection() } }
        )
    }

    private var showsCompactInspector: Bool {
        mode == .structure && sizeClass == .compact && editor.primary != nil
    }

    /// Pages, en onglets ou à la suite.
    private var sheetContent: some View {
        Group {
            if editor.pages.isEmpty {
                emptySheet
            } else {
                switch layout {
                case .tabs: TabbedPages(editor: editor)
                case .scroll: ContinuousPages(editor: editor)
                }
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
        .safeAreaPadding(.bottom, showsCompactInspector || compactOpenedItem.wrappedValue != nil ? inspectorSheetHeight : 0)
        .sheetTheme(SheetThemes.theme(for: sheet?.appearance(in: context) ?? .standard))
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
        #if os(iOS)
        if sizeClass == .compact {
            compactToolbar
        } else {
            regularToolbar
        }
        #else
        regularToolbar
        #endif
    }

    /// iPad et Mac : l'onglet au centre ; le reste à droite. Le journal n'a ni mode ni disposition,
    /// et l'annulation y est celle de l'éditeur de texte.
    @ToolbarContentBuilder
    private var regularToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            tabPicker
        }
        if tab != .journal {
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
                    inspectorButton
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    displayCommands
                } label: {
                    Label("Affichage", systemImage: layout.symbol)
                }
            }
        }
        ToolbarItem(placement: .primaryAction) {
            exportLink
        }
        if tab != .journal {
            ToolbarItem(placement: .primaryAction) {
                modePicker
            }
        }
    }

    #if os(iOS)
    /// iPhone : l'onglet au centre, le mode en bas, sous le pouce ; en haut, annuler et un menu
    /// qui regroupe édition, affichage et export. L'inspecteur s'ouvre en touchant un élément.
    @ToolbarContentBuilder
    private var compactToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            tabPicker
        }
        if tab != .journal {
            ToolbarItemGroup(placement: .primaryAction) {
                if mode != .play {
                    UndoRedoButtons()
                }
                Menu {
                    if mode == .structure {
                        Section {
                            EditCommands(editor: editor)
                        }
                    }
                    displayCommands
                    Section {
                        exportLink
                    }
                } label: {
                    Label("Plus", systemImage: "ellipsis")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                modePicker
            }
        }
    }
    #endif

    /// Fiche, Inventaire, Journal.
    private var tabPicker: some View {
        Picker("Onglet", selection: $tab) {
            ForEach(availableTabs) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }

    private var inspectorButton: some View {
        Button {
            showsInspector.toggle()
        } label: {
            Label("Inspecteur", systemImage: "sidebar.trailing")
        }
    }

    /// Disposition des pages et thème.
    @ViewBuilder
    private var displayCommands: some View {
        Picker("Pages", selection: $layout) {
            ForEach(SheetLayout.allCases) { layout in
                Label(layout.title, systemImage: layout.symbol).tag(layout)
            }
        }
        .pickerStyle(.inline)
        if let sheet {
            Section {
                ThemeMenu(sheet: sheet)
            }
        }
    }

    @ViewBuilder
    private var exportLink: some View {
        if let file = exportFile {
            ShareLink(item: file, preview: SharePreview(file.document.title)) {
                Label("Exporter", systemImage: "square.and.arrow.up")
            }
        }
    }

    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            ForEach(SheetMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
    }

    /// Fichier d'export du personnage ou du template ouvert.
    private var exportFile: SheetExportFile? {
        if let character = sheet?.character { return SheetExportFile(character: character) }
        if let template = sheet?.template { return SheetExportFile(template: template) }
        return nil
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
