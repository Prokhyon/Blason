import SwiftUI

/// Apparence de la fiche. Les vues de la fiche prennent leurs couleurs, formes et polices ici,
/// pour que d'autres thèmes puissent s'ajouter sans les modifier : couleur du template,
/// fiche papier… (SPEC §6). Seul le thème natif existe pour l'instant.
struct SheetTheme {
    /// Fond de la page, derrière les sections.
    var pageBackground: Color
    /// Fond d'une section.
    var cardBackground: Color
    var cardCornerRadius: CGFloat
    /// Fond discret d'une zone de saisie.
    var inputFill: Color
    /// Mise en avant : valeur courante d'une ressource, case cochée…
    var accent: Color
    var pageTitleFont: Font
    var sectionTitleFont: Font

    /// Couleurs et typographie du système : clair / sombre, contraste et taille du texte suivent les réglages.
    static let native = SheetTheme(
        pageBackground: Color(.systemGroupedBackground),
        cardBackground: Color(.secondarySystemGroupedBackground),
        cardCornerRadius: 14,
        inputFill: Color(.tertiarySystemFill),
        accent: .accentColor,
        pageTitleFont: .title2.weight(.bold),
        sectionTitleFont: .headline
    )
}

extension EnvironmentValues {
    @Entry var sheetTheme: SheetTheme = .native
}

extension View {
    /// Fond discret qui signale un champ de saisie.
    func inputBackground() -> some View {
        modifier(InputBackground())
    }
}

private struct InputBackground: ViewModifier {
    @Environment(\.sheetTheme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(theme.inputFill, in: RoundedRectangle(cornerRadius: 6))
    }
}
