import SwiftUI
import SheetKit

// Thèmes de fiche (SPEC §5.9).
//
// Un thème, c'est :
// - des **couleurs** et des **polices** (valeurs simples) ;
// - des **pièces** remplaçables, chacune une fonction qui dessine une partie de la fiche :
//   fond et cadre de page, titre de page, cadre de section, zone de saisie, case à cocher, tuile.
//   Les ornements partagés entre thèmes (grain, lettrine, rinceaux) sont dans `Themes/Ornaments`.
//
// `SheetTheme.native` fournit tout. Un nouveau thème part du natif et ne change que ce qu'il veut
// (voir `PaperTheme.swift`), puis s'inscrit dans `SheetThemes.all`. Les vues de la fiche ne
// connaissent que `SheetTheme` : elles ne changent pas quand un thème s'ajoute.

struct SheetTheme: Equatable {
    /// Apparence dont le thème est issu : deux thèmes de même apparence sont égaux. Sans cela,
    /// les fonctions qu'il contient (fond, cadre) le rendaient « nouveau » à chaque affichage de la
    /// fiche, et tout ce qui le lit (dont chaque champ de saisie) était mis à jour.
    var identity = SheetAppearance.standard

    static func == (lhs: SheetTheme, rhs: SheetTheme) -> Bool {
        lhs.identity == rhs.identity
    }

    // MARK: Couleurs

    /// Mise en avant : valeur courante d'une ressource, case cochée, boutons de la fiche.
    var accent: Color = .accentColor
    /// Couleur du texte de la fiche ; nil : celle du système.
    var ink: Color?
    /// Couleur des titres (page, section, groupe) ; nil : celle du texte.
    var headingColor: Color?
    /// Fond d'une section (cadre natif).
    var cardBackground: Color = Color.secondaryGroupedBackground
    /// Fond discret d'une zone de saisie et d'une case de piste.
    var inputFill: Color = Color.tertiaryFill
    /// Contour d'une case de piste ; nil : aucun.
    var trackStroke: Color?
    /// Clair ou sombre imposé (une fiche papier reste claire) ; nil : réglage du système.
    var colorScheme: ColorScheme?

    // MARK: Polices

    /// Dessin des polices du système dans toute la fiche (avec empattements pour le papier).
    var fontDesign: Font.Design = .default
    var pageTitleFont: Font = .title2.weight(.bold)
    /// Titre de section : il se détache des titres de groupe et des lignes (le cadre du thème
    /// décide où le poser).
    var sectionTitleFont: Font = .title3.weight(.bold)
    var sectionTitleCase: Text.Case?
    var sectionTitleTracking: CGFloat = 0
    /// Titre d'un groupe de tableau.
    var groupTitleFont: Font = .subheadline.weight(.semibold)
    /// Titre d'une session du journal, en tête du récit.
    var sessionTitleFont: Font = .title.weight(.bold)

    // MARK: Libellés

    /// Couleur des libellés de champ ; nil : secondaire.
    var labelColor: Color?
    /// Signe posé devant chaque libellé, dans la couleur des titres (pied-de-mouche ¶ de l'enluminure).
    var labelMark: String?

    // MARK: Journal et panneaux

    /// Récit du journal : polices et couleurs de la vue de texte du système.
    var journal = JournalStyle()
    /// Fond d'une ligne de liste (sessions, carnet, documents) ; nil : celui du système.
    var rowBackground: Color?

    // MARK: Pièces

    /// Fond derrière les pages : blanc, noir en sombre (les cartes se détachent par leur ombre).
    var pageBackground: @MainActor @Sendable () -> AnyView = {
        AnyView(Color.writingBackground)
    }
    /// Fond des panneaux et des listes (sessions, carnet et documents).
    var panelBackground: @MainActor @Sendable () -> AnyView = {
        AnyView(Color.groupedBackground)
    }
    /// Cadre d'une page : entoure son titre (défilement continu) et ses sections ; rien en natif.
    var pageFrame: @MainActor @Sendable (AnyView) -> AnyView = { page in
        page
    }
    /// Titre de page déjà mis en forme (police, couleur) : le thème peut l'orner.
    var pageTitle: @MainActor @Sendable (PageTitleConfiguration) -> AnyView = { configuration in
        configuration.title
    }
    /// Cadre d'une section : place son titre et son contenu. Chaque thème choisit où va le titre :
    /// au-dessus de la carte (natif), dans un bandeau (couleur), sur le filet du cadre (papier),
    /// ou dans un cadre collé à la section.
    var sectionFrame: @MainActor @Sendable (SectionFrameConfiguration) -> AnyView = { configuration in
        AnyView(NativeSectionFrame(configuration: configuration))
    }
    /// Habillage d'une zone de saisie (texte, nombre).
    var inputFrame: @MainActor @Sendable (AnyView) -> AnyView = { field in
        AnyView(NativeInputFrame(field: field))
    }
    /// Dessin d'une case à cocher.
    var checkbox: @MainActor @Sendable (Bool) -> AnyView = { isOn in
        AnyView(NativeCheckbox(isOn: isOn))
    }
    /// Fond d'une tuile (grand champ sous son libellé, dans la grille).
    var tileFrame: @MainActor @Sendable (TileConfiguration) -> AnyView = { configuration in
        AnyView(NativeTileFrame(configuration: configuration))
    }

    /// Thème natif : couleurs et typographie du système (clair / sombre, contraste, taille du texte).
    static let native = SheetTheme()
}

/// Ce qu'un cadre de section reçoit : le titre déjà mis en forme (absent si la section n'en a pas)
/// et le contenu.
struct SectionFrameConfiguration {
    let title: AnyView?
    /// Texte du titre, pour un cadre qui le compose lui-même (lettrine) ; nil sans titre, ou pour
    /// l'indication « Section sans titre » du mode Structure.
    var titleText: String?
    let content: AnyView
}

/// Ce que reçoit le titre d'une page : le titre mis en forme, et son texte (vide si la page n'en a pas).
struct PageTitleConfiguration {
    let title: AnyView
    let text: String
}

/// Ce que reçoit le fond d'une tuile : la tuile, et si elle est mise en avant (mode Jouer).
struct TileConfiguration {
    let content: AnyView
    let emphasized: Bool
}

extension EnvironmentValues {
    @Entry var sheetTheme: SheetTheme = .native
}

extension View {
    /// Applique un thème à la fiche : environnement, polices, couleur du texte, clair / sombre.
    func sheetTheme(_ theme: SheetTheme) -> some View {
        modifier(SheetThemeModifier(theme: theme))
    }

    /// Couleur des titres du thème (inchangée si le thème n'en a pas).
    func sheetHeading(_ theme: SheetTheme) -> some View {
        foregroundStyle(ifSet: theme.headingColor)
    }

    /// Couleur imposée seulement si elle est donnée : sinon le style hérité reste.
    @ViewBuilder
    func foregroundStyle(ifSet color: Color?) -> some View {
        if let color { foregroundStyle(color) } else { self }
    }

    /// Fond discret qui signale un champ de saisie.
    func inputBackground() -> some View {
        modifier(InputBackground())
    }

    /// Liste ou formulaire sur le fond des panneaux du thème (ses lignes : `themedRows()`).
    func themedList() -> some View {
        modifier(ThemedList())
    }

    /// Fond des lignes de liste du thème ; à poser sur le contenu d'une liste ou d'une section.
    func themedRows() -> some View {
        modifier(ThemedRows())
    }
}

private struct ThemedList: ViewModifier {
    @Environment(\.sheetTheme) private var theme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background { theme.panelBackground() }
    }
}

private struct ThemedRows: ViewModifier {
    @Environment(\.sheetTheme) private var theme

    func body(content: Content) -> some View {
        content.listRowBackground(theme.rowBackground)
    }
}

private struct SheetThemeModifier: ViewModifier {
    let theme: SheetTheme

    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        content
            .environment(\.sheetTheme, theme)
            .fontDesign(theme.fontDesign)
            .tint(theme.accent)
            .foregroundStyle(ifSet: theme.ink)
            .environment(\.colorScheme, theme.colorScheme ?? systemScheme)
    }
}

private struct InputBackground: ViewModifier {
    @Environment(\.sheetTheme) private var theme

    func body(content: Content) -> some View {
        theme.inputFrame(AnyView(content))
    }
}

// MARK: - Pièces natives

/// Section du thème natif : le titre au-dessus de la carte, comme les rubriques de Santé ou de
/// Forme ; la carte ne porte que le contenu.
struct NativeSectionFrame: View {
    let configuration: SectionFrameConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = configuration.title {
                title.padding(.horizontal, 4)
            }
            NativeCard {
                configuration.content
                    .padding(16)
            }
        }
    }
}

/// Carte flottante (S1) : blanche, ombre douce et filet très fin sur fond blanc ; en sombre, gris
/// surélevé sans ombre.
struct NativeCard<Content: View>: View {
    @ViewBuilder let content: Content

    @Environment(\.sheetTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let dark = colorScheme == .dark
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBackground)
            .clipShape(shape)
            .background {
                shape.fill(theme.cardBackground)
                    .shadow(color: .black.opacity(dark ? 0 : 0.06), radius: 10, y: 3)
            }
            .overlay(shape.strokeBorder(Color.primary.opacity(dark ? 0.08 : 0.06), lineWidth: 0.5))
    }
}

struct NativeInputFrame: View {
    let field: AnyView

    @Environment(\.sheetTheme) private var theme

    var body: some View {
        field
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(theme.inputFill, in: RoundedRectangle(cornerRadius: 6))
    }
}

struct NativeTileFrame: View {
    let configuration: TileConfiguration

    @Environment(\.sheetTheme) private var theme

    var body: some View {
        configuration.content
            .background(theme.inputFill.opacity(configuration.emphasized ? 1 : 0.5),
                        in: RoundedRectangle(cornerRadius: 14))
    }
}

struct NativeCheckbox: View {
    let isOn: Bool

    @Environment(\.sheetTheme) private var theme

    var body: some View {
        Image(systemName: isOn ? "checkmark.square.fill" : "square")
            .font(.title3)
            .foregroundStyle(isOn ? theme.accent : Color.secondary)
    }
}
