import SwiftUI
import Combine
import SwiftData
import SheetKit

/// Un onglet de la fiche : les pages (Fiche) ou la Besace (Inventaire), avec son mode et sa barre.
/// En Remplir et Jouer, la fiche de l'objet touché s'ouvre à droite ; en Structure, l'inspecteur.
struct SheetView: View {
    let title: String
    let sheet: Sheet?
    /// `.sheet` ou `.inventory` (le journal a son propre écran).
    let tab: CharacterTab
    let editor: StructureEditor
    /// Onglet affiché : lui seul publie son mode pour les menus et ses raccourcis.
    var isActive = true

    @State private var mode: SheetMode
    /// Mode quitté en ouvrant la Structure, retrouvé par « Terminé ».
    @State private var modeBeforeStructure: SheetMode?
    /// Inspecteur ouvert (grand écran) : en touchant un élément, ou par « Afficher l'inspecteur ».
    @State private var showsInspector: Bool
    /// Réglages de la Besace (onglet Inventaire, Remplir).
    @State private var showsInventorySettings = false
    /// Objet de la Besace ouvert (Remplir, Jouer) : panneau latéral, ou feuille sur iPhone.
    @State private var openedItem: InventoryItem?
    /// Hauteur de la feuille de l'inspecteur (iPhone) : la fiche garde cette marge en bas
    /// pour que tout élément puisse remonter au-dessus d'elle.
    @State private var inspectorSheetHeight: CGFloat = 0
    @AppStorage(SheetLayout.storageKey) private var layout: SheetLayout = .tabs
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.modelContext) private var context
    @Environment(\.paneControl) private var paneControl

    init(title: String, sheet: Sheet?, tab: CharacterTab, editor: StructureEditor, isActive: Bool = true) {
        self.title = title
        self.sheet = sheet
        self.tab = tab
        self.editor = editor
        self.isActive = isActive
        // Un personnage s'ouvre en Jouer ; un template, en Structure (on le construit).
        var mode = sheet?.template != nil ? SheetMode.structure : .play
        #if DEBUG
        // Arguments de lancement pour les captures : -demoMode structure -demoItem Corde
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "demoMode"), let value = SheetMode(rawValue: raw) {
            mode = value
        }
        if let name = defaults.string(forKey: "demoItem") {
            _openedItem = State(initialValue: sheet?.inventories.flatMap(\.allItems).first { $0.name == name })
        }
        #endif
        _mode = State(initialValue: mode)
        _showsInspector = State(initialValue: editor.primary != nil)
    }

    private var isTemplate: Bool { sheet?.template != nil }

    var body: some View {
        // Le panneau latéral flotte par-dessus la page, sous la rangée des pages : la page garde
        // sa largeur (et sa disposition) en ouvrant l'inspecteur.
        tabContent
            .environment(\.sheetSidePanel, showsSidePanel ? SheetSidePanel(view: AnyView(sidePanel)) : nil)
        .paneTitle(title)
        .inlineNavigationTitle()
        .toolbar { toolbar }
        .sheet(isPresented: compactInspectorShown) {
            StructureInspector(editor: editor, isTemplate: isTemplate) {
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
        .sheet(item: pasteList) { request in
            PasteListView(request: request, editor: editor)
        }
        .background { if mode == .structure && isActive { shortcuts } }
        .environment(\.sheetMode, mode)
        .focusedSceneValue(\.sheetModeBinding, isActive ? $mode : nil)
        .environment(\.structureEditor, editor)
        .environment(\.inventoryItemOpener, InventoryItemOpener { openedItem = $0 })
        .onChange(of: mode) { old, new in
            if new == .structure, old != .structure { modeBeforeStructure = old }
            if new != .structure { editor.clearSelection() }
        }
        #if DEBUG
        // -demoModeCycle YES : Jouer → Remplir → Jouer → Structure → Jouer…, toutes les 3 s (vidéos).
        .task {
            guard UserDefaults.standard.bool(forKey: "demoModeCycle"), isActive else { return }
            let cycle: [SheetMode] = [.fill, .play, .structure, .play]
            for index in 0... {
                try? await Task.sleep(for: .seconds(3))
                if Task.isCancelled { return }
                mode = cycle[index % cycle.count]
            }
        }
        #endif
        .onChange(of: editor.primary) { _, selection in
            // L'inspecteur suit la sélection : il s'ouvre en touchant un élément, se range en
            // désélectionnant (il ne cache pas la page tant qu'on n'en a pas besoin).
            if isActive { showsInspector = selection != nil }
        }
    }

    /// Inspecteur (Structure) ou fiche de l'objet ouvert (Remplir, Jouer).
    @ViewBuilder
    private var sidePanel: some View {
        if mode == .structure {
            StructureInspector(editor: editor, isTemplate: isTemplate) {
                showsInspector = false
            }
        } else if let openedItem {
            ItemDetailView(item: openedItem) { self.openedItem = nil }
                .id(openedItem.persistentModelID)
        }
    }

    /// Coller une liste : demandé depuis l'onglet affiché seulement.
    private var pasteList: Binding<PasteListRequest?> {
        Binding(
            get: { isActive && mode == .structure ? editor.pasteList : nil },
            set: { editor.pasteList = $0 }
        )
    }

    /// Panneau flottant sur grand écran (feuille sur écran étroit) : l'inspecteur en Structure,
    /// la fiche de l'objet ouvert en Remplir et Jouer (SPEC §5.15).
    private var showsSidePanel: Bool {
        guard sizeClass != .compact else { return false }
        return mode == .structure ? showsInspector && ownsSelection : openedItem != nil
    }

    /// Côte à côte, les deux panneaux partagent la sélection de la Structure : l'inspecteur s'ouvre
    /// dans celui qui montre l'élément (la Besace dans l'Inventaire, le reste dans la Fiche).
    private var ownsSelection: Bool {
        guard paneControl?.isSplit == true else { return true }
        guard let primary = editor.primary else { return true }
        let isBesace = if case .section(let section) = primary { section.kind == .inventory } else { false }
        return isBesace == (tab == .inventory)
    }

    /// iPhone : fiche de l'objet en feuille.
    private var compactOpenedItem: Binding<InventoryItem?> {
        Binding(
            get: { mode != .structure && sizeClass == .compact && isActive ? openedItem : nil },
            set: { openedItem = $0 }
        )
    }

    /// Contenu de l'onglet.
    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .inventory:
            InventoryTabView(sheet: sheet, showsSettings: $showsInventorySettings)
                .safeAreaPadding(.bottom, showsCompactInspector || compactOpenedItem.wrappedValue != nil ? inspectorSheetHeight : 0)
                .sheetTheme(SheetThemes.theme(for: sheet?.appearance(in: context) ?? .standard))
        default:
            sheetContent
        }
    }

    /// iPhone : la feuille n'apparaît qu'avec une sélection ; la fermer désélectionne.
    private var compactInspectorShown: Binding<Bool> {
        Binding(
            get: { showsCompactInspector },
            set: { if !$0 { editor.clearSelection() } }
        )
    }

    private var showsCompactInspector: Bool {
        mode == .structure && sizeClass == .compact && editor.primary != nil && isActive
    }

    /// Pages, en onglets ou à la suite.
    private var sheetContent: some View {
        Group {
            if editor.pages.isEmpty {
                emptySheet.floatingSidePanel()
            } else {
                switch layout {
                case .tabs: TabbedPages(editor: editor)
                case .scroll: ContinuousPages(editor: editor)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let notice = editor.notice, isActive {
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
                 : "Ouvrez la structure (menu …) pour construire la fiche.")
        } actions: {
            if mode == .structure {
                Button("Ajouter une page") { editor.addPage() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Éditer la structure") { mode = .structure }
            }
        }
    }

    // MARK: Barre

    /// À droite : annuler / rétablir hors Jouer, le menu « … »,
    /// puis le bouton du mode (Éditer, OK, Terminé), toujours en dernier, au même endroit.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if mode != .play {
            ToolbarItemGroup(placement: .primaryAction) {
                UndoRedoButtons()
            }
            ToolbarSpacer(.fixed, placement: .primaryAction)
        }
        ToolbarItem(placement: .primaryAction) {
            moreMenu
        }
        ToolbarSpacer(.fixed, placement: .primaryAction)
        ToolbarItem(placement: .primaryAction) {
            modeButton
        }
    }

    /// Éditer → mode d'édition ; OK / Terminé → retour au mode de départ (SPEC §4).
    @ViewBuilder
    private var modeButton: some View {
        let rest = SheetMode.rest(isTemplate: isTemplate)
        if mode == rest {
            Button("Éditer") {
                mode = SheetMode.edit(isTemplate: isTemplate)
            }
        } else {
            // Terminé en coche (convention d'iOS 26) : le libellé ne tenait pas dans la barre en
            // Structure sur iPad en portrait et partait dans le menu de débordement.
            Group {
                if mode == .structure {
                    Button("Terminé", systemImage: "checkmark") {
                        mode = modeBeforeStructure ?? rest
                    }
                } else {
                    Button("OK") { mode = rest }
                }
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }

    /// Structure (personnage), édition de la sélection (Structure), disposition des pages et thème.
    private var moreMenu: some View {
        Menu {
            if mode == .structure {
                Section {
                    EditCommands(editor: editor)
                }
                if sizeClass != .compact && !showsInspector {
                    Button("Afficher l'inspecteur", systemImage: "sidebar.trailing") {
                        showsInspector = true
                    }
                }
            } else {
                if tab == .inventory, mode == .fill, sheet?.inventory != nil {
                    Button("Réglages de la Besace", systemImage: "slider.horizontal.3") {
                        showsInventorySettings = true
                    }
                }
                if !isTemplate {
                    Button("Éditer la structure", systemImage: "square.stack.3d.up") {
                        mode = .structure
                    }
                }
            }
            displayCommands
            OpenBesideMenu()
        } label: {
            Label("Plus", systemImage: "ellipsis")
        }
    }

    /// Disposition des pages (onglet Fiche) et thème.
    @ViewBuilder
    private var displayCommands: some View {
        if tab == .sheet {
            Picker("Pages", selection: $layout) {
                ForEach(SheetLayout.allCases) { layout in
                    Label(layout.title, systemImage: layout.symbol).tag(layout)
                }
            }
            .pickerStyle(.inline)
        }
        if let sheet {
            Section {
                ThemeMenu(sheet: sheet)
            }
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
        SheetView(title: "Leo", sheet: PreviewData.leo?.sheet, tab: .sheet,
                  editor: StructureEditor(sheet: PreviewData.leo?.sheet))
    }
    .modelContainer(PreviewData.container)
}
