import SwiftUI

extension SheetTheme {
    /// « Couleur du template » : la fiche native, teintée de la couleur choisie (titres, en-têtes
    /// de section, fond de page, valeurs mises en avant).
    static func templateColor(_ tint: Color) -> SheetTheme {
        var theme = SheetTheme()
        // Texte et pleins en version plus contrastée : la sarcelle ou l'orange purs se lisent mal sur fond clair.
        let strong = readable(tint)
        theme.accent = strong
        theme.headingColor = strong
        theme.inputFill = tint.opacity(0.10)
        theme.pageBackground = {
            AnyView(ZStack {
                Color(.systemGroupedBackground)
                tint.opacity(0.07)
            })
        }
        theme.sectionFrame = { configuration in
            AnyView(TintedSectionFrame(configuration: configuration, tint: tint))
        }
        return theme
    }
}

/// La couleur assombrie en mode clair, éclaircie en mode sombre, pour le texte et les pleins sous texte blanc.
private func readable(_ tint: Color) -> Color {
    let base = UIColor(tint)
    return Color(uiColor: UIColor { traits in
        let color = base.resolvedColor(with: traits)
        let dark = traits.userInterfaceStyle == .dark
        return color.mixed(with: dark ? .white : .black, amount: dark ? 0.15 : 0.32)
    })
}

private extension UIColor {
    func mixed(with other: UIColor, amount: CGFloat) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * amount, green: g1 + (g2 - g1) * amount,
                       blue: b1 + (b2 - b1) * amount, alpha: a1)
    }
}

/// Section avec un bandeau de titre teinté et un liseré.
private struct TintedSectionFrame: View {
    let configuration: SectionFrameConfiguration
    let tint: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14)
        VStack(alignment: .leading, spacing: 0) {
            if let title = configuration.title {
                title
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tint.opacity(0.14))
            }
            configuration.content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(shape)
        .overlay(shape.strokeBorder(tint.opacity(0.35), lineWidth: 1))
    }
}
