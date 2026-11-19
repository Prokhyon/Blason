import SwiftUI

extension SheetTheme {
    /// « Enluminure » : manuscrit sur vélin. Lettrine d'or sur fond d'émail en tête de chaque section,
    /// titres rubriqués dans l'émail choisi, pied-de-mouche ¶ devant les libellés, rinceau de vigne
    /// en marge de chaque page. Toujours clair, comme le vélin. Palette : les émaux héraldiques.
    static func illuminated(_ tincture: Color) -> SheetTheme {
        var theme = SheetTheme()
        let ink = IlluminatedTheme.ink
        theme.ink = ink
        theme.headingColor = tincture
        theme.accent = tincture
        theme.colorScheme = .light
        theme.fontDesign = .serif
        theme.pageTitleFont = .custom("BigCaslon-Medium", size: 30, relativeTo: .title2)
        theme.sectionTitleFont = .custom("Cochin-Bold", size: 19, relativeTo: .title3)
        theme.groupTitleFont = .custom("Cochin-Bold", size: 15, relativeTo: .subheadline)
        theme.sessionTitleFont = .custom("BigCaslon-Medium", size: 32, relativeTo: .title)
        theme.journal = JournalStyle(serif: true, titleFontName: "BigCaslon-Medium", headingFontName: "Cochin-Bold",
                                     text: ink, heading: tincture, accent: tincture)
        theme.rowBackground = Color.white.opacity(0.32)
        theme.labelColor = ink.opacity(0.78)
        theme.labelMark = "¶"
        theme.cardBackground = .clear
        theme.inputFill = tincture.opacity(0.07)
        theme.trackStroke = ink.opacity(0.4)
        theme.pageBackground = { AnyView(GrainBackground(tile: IlluminatedTheme.vellum, fallback: IlluminatedTheme.parchment)) }
        theme.panelBackground = theme.pageBackground
        theme.pageFrame = { AnyView(IlluminatedPageFrame(page: $0, tincture: tincture)) }
        theme.pageTitle = { AnyView(IlluminatedPageTitle(configuration: $0)) }
        theme.sectionFrame = { AnyView(IlluminatedSectionFrame(configuration: $0, tincture: tincture)) }
        theme.inputFrame = { AnyView(IlluminatedInputFrame(field: $0)) }
        theme.checkbox = { AnyView(IlluminatedCheckbox(isOn: $0, tincture: tincture)) }
        theme.tileFrame = { AnyView(IlluminatedTileFrame(configuration: $0)) }
        return theme
    }
}

enum IlluminatedTheme {
    /// Encre ferro-gallique, brun très sombre.
    static let ink = Color(red: 0.17, green: 0.14, blue: 0.09)
    /// Vélin : le « parchemin » des pistes d'icônes (#F3EAD8).
    static let parchment = Color(red: 0.953, green: 0.918, blue: 0.847)

    /// Grain du vélin : plus chaud et plus fibreux que le papier.
    @MainActor static let vellum: CGImage? = Grain.tile(
        base: .init(red: 0.953, green: 0.918, blue: 0.847),
        fleck: .init(red: 0.45, green: 0.30, blue: 0.12),
        fibre: .init(red: 0.55, green: 0.40, blue: 0.20),
        seed: 0x7E11, fibres: 70)

    /// Les émaux, aux couleurs des icônes de l'app (`Design/Blason/make.py`), en version foncée :
    /// lisibles en texte sur le vélin. L'or et l'argent sont des métaux : ils ne s'écrivent pas sur
    /// le vélin, l'or est réservé aux lettrines.
    static let tinctures: [ThemeColor] = [
        ThemeColor(id: "gueules", name: "Gueules", color: Color(red: 0.64, green: 0.18, blue: 0.18)),   // #A32D2D
        ThemeColor(id: "azur", name: "Azur", color: Color(red: 0.09, green: 0.37, blue: 0.65)),        // #185FA5
        ThemeColor(id: "sinople", name: "Sinople", color: Color(red: 0.23, green: 0.43, blue: 0.07)),  // #3B6D11
        ThemeColor(id: "pourpre", name: "Pourpre", color: Color(red: 0.33, green: 0.29, blue: 0.72)),  // #534AB7
        ThemeColor(id: "sable", name: "Sable", color: Color(red: 0.17, green: 0.17, blue: 0.16)),      // #2C2C2A
    ]
}

/// Page : un rinceau dans la marge de gauche, sur toute sa hauteur.
private struct IlluminatedPageFrame: View {
    let page: AnyView
    let tincture: Color

    var body: some View {
        page
            .padding(.leading, VineBorder.width + 10)
            .background(alignment: .leading) {
                VineBorder(tint: tincture)
            }
    }
}

/// Titre de page souligné d'un filet d'or terminé par deux losanges.
private struct IlluminatedPageTitle: View {
    let configuration: PageTitleConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration.title
            HStack(spacing: 4) {
                Lozenge()
                Rectangle().fill(Gilding.shade).frame(height: 1)
                Lozenge()
            }
            .frame(maxWidth: 220)
            .accessibilityHidden(true)
        }
    }

    private struct Lozenge: View {
        var body: some View {
            Rectangle()
                .fill(Gilding.shade)
                .frame(width: 5, height: 5)
                .rotationEffect(.degrees(45))
        }
    }
}

/// Section : la lettrine et la suite du titre rubriquée, un filet d'émail jusqu'au bord ; dessous,
/// le contenu sur un vélin plus clair, tenu par un filet d'encre.
private struct IlluminatedSectionFrame: View {
    let configuration: SectionFrameConfiguration
    let tincture: Color

    @Environment(\.sheetTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            heading
            configuration.content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.28))
                .overlay(Rectangle().strokeBorder(IlluminatedTheme.ink.opacity(0.35), lineWidth: 0.6))
        }
    }

    @ViewBuilder
    private var heading: some View {
        if let text = configuration.titleText, let parts = Lettrine.split(text) {
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Lettrine(letter: parts.initial, field: tincture)
                    .alignmentGuide(.lastTextBaseline) { $0[.bottom] - 2 }
                Text(parts.rest)
                    .font(theme.sectionTitleFont)
                    .foregroundStyle(tincture)
                    .lineLimit(2)
                Rectangle()
                    .fill(tincture.opacity(0.5))
                    .frame(height: 0.8)
                    .frame(minWidth: 12)
                    .padding(.leading, 6)
                    .alignmentGuide(.lastTextBaseline) { $0[.bottom] + 4 }
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .accessibilityAddTraits(.isHeader)
        } else if let title = configuration.title {
            title
        }
    }
}

/// Ligne d'encre à compléter.
private struct IlluminatedInputFrame: View {
    let field: AnyView

    var body: some View {
        field
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(IlluminatedTheme.ink.opacity(0.4))
                    .frame(height: 0.7)
            }
    }
}

/// Case tracée à l'encre ; cochée, un losange d'émail cerclé d'or.
private struct IlluminatedCheckbox: View {
    let isOn: Bool
    let tincture: Color

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 17

    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(IlluminatedTheme.ink, lineWidth: 1.1)
            if isOn {
                Rectangle()
                    .fill(tincture)
                    .overlay(Rectangle().strokeBorder(Gilding.shade, lineWidth: 0.8))
                    .frame(width: side * 0.5, height: side * 0.5)
                    .rotationEffect(.degrees(45))
            }
        }
        .frame(width: side, height: side)
        .padding(2)
    }
}

/// Tuile : un cartouche de vélin clair, filet d'encre fin.
private struct IlluminatedTileFrame: View {
    let configuration: TileConfiguration

    var body: some View {
        configuration.content
            .background(Color.white.opacity(configuration.emphasized ? 0.45 : 0.25))
            .overlay(Rectangle().strokeBorder(IlluminatedTheme.ink.opacity(0.3), lineWidth: 0.6))
    }
}
