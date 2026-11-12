import SwiftUI
import SwiftData
import SheetKit

/// Écran d'un personnage ou d'un template, ouvert en plein écran depuis la bibliothèque (SPEC §5.17) :
/// onglets Fiche, Inventaire et Journal (le journal pour un personnage seulement). Fiche et
/// Inventaire ont chacun leur barre et leur mode ; ils partagent l'éditeur de structure.
struct SheetScreen: View {
    let title: String
    let sheet: Sheet?
    /// Appelé après chaque enregistrement d'une modification faite pendant que la fiche est ouverte
    /// (sert à mettre à jour la date de modification du personnage ou du template).
    var onEdit: () -> Void = {}
    /// Revient à la bibliothèque (iPhone, iPad). Sur Mac, la pile a son bouton de retour.
    var onClose: (() -> Void)?

    @State private var tab: CharacterTab = .sheet
    @State private var editor: StructureEditor

    init(title: String, sheet: Sheet?, onEdit: @escaping () -> Void = {}, onClose: (() -> Void)? = nil) {
        self.title = title
        self.sheet = sheet
        self.onEdit = onEdit
        self.onClose = onClose
        let editor = StructureEditor(sheet: sheet)
        #if DEBUG
        // Arguments de lancement pour les captures : -demoPage 1 -demoSelect FOR
        let defaults = UserDefaults.standard
        editor.pageIndex = defaults.integer(forKey: "demoPage")
        // -demoTheme paper -demoColor teal : apparence de la fiche ouverte (modifie la base de développement).
        if let theme = defaults.string(forKey: "demoTheme") {
            sheet?.ownAppearance = SheetAppearance(themeID: theme, colorID: defaults.string(forKey: "demoColor") ?? "blue")
        }
        if defaults.bool(forKey: "demoBesace"), let sheet, let context = sheet.modelContext {
            DemoData.addDemoInventory(to: sheet, in: context)
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
        _editor = State(initialValue: editor)
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab(CharacterTab.sheet.title, systemImage: CharacterTab.sheet.symbol, value: CharacterTab.sheet) {
                pane(.sheet)
            }
            Tab(CharacterTab.inventory.title, systemImage: CharacterTab.inventory.symbol, value: CharacterTab.inventory) {
                pane(.inventory)
            }
            if let character = sheet?.character {
                Tab(CharacterTab.journal.title, systemImage: CharacterTab.journal.symbol, value: CharacterTab.journal) {
                    TabStack {
                        JournalScreen(character: character)
                            .navigationTitle(title)
                            .inlineNavigationTitle()
                            .closesToLibrary(onClose, title: title)
                    }
                }
            }
        }
        .focusedSceneValue(\.characterTabBinding, $tab)
        .focusedSceneValue(\.availableCharacterTabs, availableTabs)
        .onChange(of: tab) {
            // La sélection de la Structure ne suit pas d'un onglet à l'autre.
            editor.clearSelection()
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

    private func pane(_ kind: CharacterTab) -> some View {
        TabStack {
            SheetView(title: title, sheet: sheet, tab: kind, editor: editor, isActive: tab == kind)
                .closesToLibrary(onClose, title: title)
        }
    }

    /// Un enregistrement contient une modification de la fiche s'il touche autre chose que
    /// le propriétaire lui-même (dont seule la date change en réponse : pas de boucle).
    private static func containsSheetEdit(_ notification: Notification, owner: PersistentIdentifier?) -> Bool {
        SheetStore.savedIdentifiers(in: notification).contains { $0 != owner }
    }
}

extension View {
    /// Retour à la bibliothèque et nom du personnage, en tête de chaque onglet (iPhone, iPad).
    /// Sur Mac, la pile a son bouton de retour.
    fileprivate func closesToLibrary(_ onClose: (() -> Void)?, title: String) -> some View {
        modifier(LibraryReturn(onClose: onClose, title: title))
    }
}

/// Bouton de retour, suivi du nom sur grand écran : la barre d'onglets occupe le centre de la barre,
/// où le titre ne s'affiche plus. Sur iPhone, les onglets sont en bas et le titre reste au centre.
private struct LibraryReturn: ViewModifier {
    let onClose: (() -> Void)?
    let title: String

    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        #if os(iOS)
        if let onClose {
            content.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Bibliothèque", systemImage: "chevron.backward", action: onClose)
                }
                if sizeClass != .compact {
                    ToolbarItem(placement: .topBarLeading) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)
                            .accessibilityAddTraits(.isHeader)
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// Pile de navigation d'un onglet (sa barre, ses titres) ; sur Mac, l'écran est déjà dans la pile
/// de la bibliothèque.
private struct TabStack<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        #if os(iOS)
        NavigationStack { content }
        #else
        content
        #endif
    }
}

#Preview("Leo") {
    SheetScreen(title: "Leo", sheet: PreviewData.leo?.sheet)
        .modelContainer(PreviewData.container)
}
