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
    @AppStorage(SheetLayout.storageKey) private var layout: SheetLayout = .tabs
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
            Menu {
                Picker("Pages", selection: $layout) {
                    ForEach(SheetLayout.allCases) { layout in
                        Label(layout.title, systemImage: layout.symbol).tag(layout)
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Affichage", systemImage: layout.symbol)
            }
        }
        ToolbarItem(placement: .primaryAction) {
            if let file = exportFile {
                ShareLink(item: file, preview: SharePreview(file.document.title)) {
                    Label("Exporter", systemImage: "square.and.arrow.up")
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
