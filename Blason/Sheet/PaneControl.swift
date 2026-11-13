import SwiftUI

/// Panneau de l'écran d'un personnage (SPEC §5.17) : son onglet et, quand deux onglets sont
/// côte à côte, de quoi en changer, ouvrir l'autre panneau ou se fermer.
struct PaneControl {
    /// Onglets proposés (le journal pour un personnage seulement).
    let tabs: [CharacterTab]
    /// Onglet affiché dans ce panneau.
    let current: CharacterTab
    /// Deux onglets sont côte à côte.
    let isSplit: Bool
    /// La largeur permet d'afficher deux onglets côte à côte.
    let canSplit: Bool
    let select: @MainActor (CharacterTab) -> Void
    let openBeside: @MainActor (CharacterTab) -> Void
    let close: @MainActor () -> Void

    /// Onglets qu'on peut ouvrir à côté de celui-ci.
    var others: [CharacterTab] { tabs.filter { $0 != current } }
}

extension EnvironmentValues {
    @Entry var paneControl: PaneControl?
}

extension View {
    /// Titre de la barre : le nom du personnage, ou, côte à côte, l'onglet du panneau en titre-menu.
    func paneTitle(_ title: String) -> some View {
        modifier(PaneTitle(title: title))
    }
}

private struct PaneTitle: ViewModifier {
    let title: String
    @Environment(\.paneControl) private var pane

    func body(content: Content) -> some View {
        if let pane, pane.isSplit {
            content
                .navigationTitle(pane.current.title)
                .toolbarTitleMenu { PaneMenu(pane: pane) }
        } else {
            content.navigationTitle(title)
        }
    }
}

/// Menu du titre d'un panneau : les onglets, puis fermer le panneau.
private struct PaneMenu: View {
    let pane: PaneControl

    var body: some View {
        Picker("Onglet", selection: Binding(get: { pane.current }, set: { pane.select($0) })) {
            ForEach(pane.tabs) { tab in
                Label(tab.title, systemImage: tab.symbol).tag(tab)
            }
        }
        .pickerStyle(.inline)
        Button("Fermer ce panneau", systemImage: "xmark.rectangle") { pane.close() }
    }
}

/// « Afficher à côté » : les autres onglets, quand la largeur le permet et qu'un seul est affiché.
struct OpenBesideMenu: View {
    @Environment(\.paneControl) private var pane

    var body: some View {
        if let pane, pane.canSplit, !pane.isSplit {
            Menu("Afficher à côté", systemImage: "rectangle.split.2x1") {
                ForEach(pane.others) { tab in
                    Button(tab.title, systemImage: tab.symbol) { pane.openBeside(tab) }
                }
            }
        }
    }
}

// MARK: - Panneau flottant

/// Inspecteur (Structure) ou fiche d'objet (Remplir, Jouer), posé par l'onglet sur son contenu.
struct SheetSidePanel {
    let view: AnyView
}

extension EnvironmentValues {
    @Entry var sheetSidePanel: SheetSidePanel?
}

extension View {
    /// Pose le panneau flottant de l'onglet (`sheetSidePanel`) sur ce contenu : à poser avant la
    /// rangée du haut (`safeAreaBar`), pour que le panneau s'arrête dessous. Il se place à droite,
    /// ou à gauche quand l'élément sélectionné serait dessous.
    func floatingSidePanel() -> some View {
        modifier(FloatingSidePanel())
    }
}

private struct FloatingSidePanel: ViewModifier {
    static let width: CGFloat = 340

    @Environment(\.sheetSidePanel) private var panel

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(SelectionBoundsKey.self) { anchor in
            GeometryReader { proxy in
                let leading = anchor.map { Self.prefersLeading(proxy[$0], width: proxy.size.width) } ?? false
                ZStack(alignment: leading ? .leading : .trailing) {
                    Color.clear.allowsHitTesting(false)
                    if let panel {
                        panel.view
                            .floatingPanel(width: Self.width)
                            .transition(.move(edge: leading ? .leading : .trailing).combined(with: .opacity))
                    }
                }
                .animation(.snappy, value: panel != nil)
                .animation(.snappy, value: leading)
            }
        }
    }

    /// À gauche si l'élément serait sous le panneau à droite et reste visible à gauche.
    private static func prefersLeading(_ frame: CGRect, width: CGFloat) -> Bool {
        let covered = Self.width + 20
        return frame.maxX > width - covered && frame.minX >= covered
    }
}
