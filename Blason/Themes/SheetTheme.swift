import SwiftUI
import SheetKit

// Thèmes de fiche (SPEC §5.9).
//
// Un thème, c'est :
// - des **couleurs** et des **polices** (valeurs simples) ;
// - des **pièces** remplaçables, chacune une fonction qui dessine une partie de la fiche :
//   fond de page, cadre de section, zone de saisie, case à cocher.
//
// `SheetTheme.native` fournit tout. Un nouveau thème part du natif et ne change que ce qu'il veut
// (voir `PaperTheme.swift`), puis s'inscrit dans `SheetThemes.all`. Les vues de la fiche ne
// connaissent que `SheetTheme` : elles ne changent pas quand un thème s'ajoute.

struct SheetTheme {
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
    var sectionTitleFont: Font = .headline
    var sectionTitleCase: Text.Case?
    var sectionTitleTracking: CGFloat = 0

    // MARK: Pièces

    /// Fond derrière les pages : blanc, noir en sombre (les cartes se détachent par leur ombre).
    var pageBackground: @MainActor @Sendable () -> AnyView = {
        AnyView(Color.writingBackground)
    }
    /// Cadre d'une section : place son titre et son contenu.
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

    /// Thème natif : couleurs et typographie du système (clair / sombre, contraste, taille du texte).
    static let native = SheetTheme()
}

/// Ce qu'un cadre de section reçoit : le titre déjà mis en forme (absent si la section n'en a pas)
/// et le contenu.
struct SectionFrameConfiguration {
    let title: AnyView?
    let content: AnyView
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

/// Carte flottante (S1) : blanche, ombre douce et filet très fin sur fond blanc ; en sombre, gris
/// surélevé sans ombre.
struct NativeSectionFrame: View {
    let configuration: SectionFrameConfiguration

    @Environment(\.sheetTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let dark = colorScheme == .dark
        VStack(alignment: .leading, spacing: 10) {
            configuration.title
            configuration.content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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

struct NativeCheckbox: View {
    let isOn: Bool

    @Environment(\.sheetTheme) private var theme

    var body: some View {
        Image(systemName: isOn ? "checkmark.square.fill" : "square")
            .font(.title3)
            .foregroundStyle(isOn ? theme.accent : Color.secondary)
    }
}
