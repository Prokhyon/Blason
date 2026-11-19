import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

extension SheetTheme {
    /// « Couleur du template » : la fiche native (fond blanc, cartes flottantes), teintée de la
    /// couleur choisie : bandeau de titre des sections, titres, valeurs mises en avant.
    static func templateColor(_ tint: Color) -> SheetTheme {
        var theme = SheetTheme()
        // Texte et pleins en version plus contrastée : la sarcelle ou l'orange purs se lisent mal sur fond clair.
        let strong = readable(tint)
        theme.accent = strong
        theme.headingColor = strong
        theme.inputFill = tint.opacity(0.10)
        theme.sectionFrame = { configuration in
            AnyView(TintedSectionFrame(configuration: configuration, tint: tint))
        }
        return theme
    }
}

/// La couleur assombrie en mode clair, éclaircie en mode sombre, pour le texte et les pleins sous texte blanc.
private func readable(_ tint: Color) -> Color {
    #if canImport(UIKit)
    let base = UIColor(tint)
    return Color(uiColor: UIColor { traits in
        let color = base.resolvedColor(with: traits)
        let dark = traits.userInterfaceStyle == .dark
        return color.mixed(with: dark ? .white : .black, amount: dark ? 0.15 : 0.32)
    })
    #else
    let base = NSColor(tint)
    return Color(nsColor: NSColor(name: nil) { appearance in
        let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        var color = base
        appearance.performAsCurrentDrawingAppearance {
            color = base.usingColorSpace(.sRGB) ?? base
        }
        return color.blended(withFraction: dark ? 0.15 : 0.32, of: dark ? .white : .black) ?? color
    })
    #endif
}

#if canImport(UIKit)
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
#endif

/// Carte flottante dont le titre occupe un bandeau teinté.
private struct TintedSectionFrame: View {
    let configuration: SectionFrameConfiguration
    let tint: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NativeCard {
            VStack(alignment: .leading, spacing: 0) {
                if let title = configuration.title {
                    title
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(tint.opacity(colorScheme == .dark ? 0.22 : 0.12))
                }
                configuration.content
                    .padding(16)
            }
        }
    }
}
