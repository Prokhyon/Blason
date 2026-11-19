import SwiftUI

extension SheetTheme {
    /// « Entrelacs » : celtique et nordique, sur une pierre claire. Chaque section est tenue entre
    /// deux frises tressées, reliées par un double filet ; un triquetra devant son titre. Tout en
    /// Optima. Toujours clair. Palette : les teintures (vert profond, guède, garance, ocre).
    static func entrelacs(_ dye: Color) -> SheetTheme {
        var theme = SheetTheme()
        let ink = EntrelacsTheme.ink
        theme.ink = ink
        theme.headingColor = dye
        theme.accent = dye
        theme.colorScheme = .light
        theme.bodyFont = .custom("Optima-Regular", size: 17, relativeTo: .body)
        theme.pageTitleFont = .custom("Optima-Bold", size: 30, relativeTo: .title2)
        theme.sectionTitleFont = .custom("Optima-Bold", size: 20, relativeTo: .title3)
        theme.groupTitleFont = .custom("Optima-Bold", size: 15, relativeTo: .subheadline)
        theme.sessionTitleFont = .custom("Optima-Bold", size: 32, relativeTo: .title)
        theme.labelColor = ink.opacity(0.62)
        theme.cardBackground = .clear
        theme.inputFill = ink.opacity(0.05)
        theme.trackStroke = ink.opacity(0.4)
        theme.rowBackground = Color.white.opacity(0.35)
        theme.journal = JournalStyle(bodyFontName: "Optima-Regular", titleFontName: "Optima-Bold",
                                     headingFontName: "Optima-Bold", text: ink, heading: dye, accent: dye)
        theme.pageBackground = { AnyView(GrainBackground(tile: EntrelacsTheme.stone, fallback: EntrelacsTheme.stoneColor)) }
        theme.panelBackground = theme.pageBackground
        theme.pageTitle = { AnyView(EntrelacsPageTitle(configuration: $0, dye: dye)) }
        theme.sectionFrame = { AnyView(EntrelacsSectionFrame(configuration: $0, dye: dye)) }
        theme.inputFrame = { AnyView(EntrelacsInputFrame(field: $0)) }
        theme.checkbox = { AnyView(EntrelacsCheckbox(isOn: $0, dye: dye)) }
        theme.tileFrame = { AnyView(EntrelacsTileFrame(configuration: $0, dye: dye)) }
        return theme
    }
}

enum EntrelacsTheme {
    /// Encre : vert presque noir (#1F2621).
    static let ink = Color(red: 0.12, green: 0.15, blue: 0.13)
    /// Pierre claire (#ECEBDF).
    static let stoneColor = Color(red: 0.925, green: 0.92, blue: 0.875)

    /// Grain de la pierre : points fins, peu de fibres.
    @MainActor static let stone: CGImage? = Grain.tile(
        base: .init(red: 0.925, green: 0.92, blue: 0.875),
        fleck: .init(red: 0.25, green: 0.30, blue: 0.26),
        fibre: .init(red: 0.40, green: 0.42, blue: 0.36),
        seed: 0xCE17, flecks: 9000, fibres: 25)

    /// Teintures végétales.
    static let dyes: [ThemeColor] = [
        ThemeColor(id: "vert", name: "Vert profond", color: Color(red: 0.12, green: 0.30, blue: 0.23)),   // #1F4D3A
        ThemeColor(id: "guede", name: "Bleu guède", color: Color(red: 0.16, green: 0.29, blue: 0.42)),    // #2A4A6B
        ThemeColor(id: "garance", name: "Rouge garance", color: Color(red: 0.56, green: 0.18, blue: 0.15)), // #8E2F25
        ThemeColor(id: "ocre", name: "Ocre", color: Color(red: 0.54, green: 0.39, blue: 0.09)),           // #8A6418
    ]
}

// MARK: - Pièces

/// Section : frise tressée en haut et en bas, double filet sur les côtés ; titre précédé d'un
/// triquetra.
private struct EntrelacsSectionFrame: View {
    let configuration: SectionFrameConfiguration
    let dye: Color

    var body: some View {
        VStack(spacing: 0) {
            KnotBand(tint: dye)
            VStack(alignment: .leading, spacing: 10) {
                if let title = configuration.title {
                    HStack(alignment: .center, spacing: 8) {
                        Triquetra()
                            .stroke(dye, lineWidth: 1.6)
                            .frame(width: 21, height: 21)
                            .accessibilityHidden(true)
                        title
                    }
                }
                configuration.content
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.32))
            .overlay {
                HStack {
                    sideRule
                    Spacer()
                    sideRule
                }
                .padding(.horizontal, 2.5)
            }
            KnotBand(tint: dye)
        }
    }

    /// Double filet vertical, aligné sur les nœuds des frises.
    private var sideRule: some View {
        HStack(spacing: 2) {
            Rectangle().frame(width: 1.1)
            Rectangle().frame(width: 0.5)
        }
        .foregroundStyle(EntrelacsTheme.ink.opacity(0.7))
        .accessibilityHidden(true)
    }
}

/// Titre de page : une courte frise dessous.
private struct EntrelacsPageTitle: View {
    let configuration: PageTitleConfiguration
    let dye: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            configuration.title
            KnotBand(tint: dye)
                .frame(width: 170)
        }
    }
}

/// Ligne à compléter.
private struct EntrelacsInputFrame: View {
    let field: AnyView

    var body: some View {
        field
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(EntrelacsTheme.ink.opacity(0.4))
                    .frame(height: 0.8)
            }
    }
}

/// Case ronde ; cochée, une pastille teinte marquée d'un triquetra.
private struct EntrelacsCheckbox: View {
    let isOn: Bool
    let dye: Color

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 18

    var body: some View {
        ZStack {
            if isOn {
                Circle().fill(dye)
                Triquetra()
                    .stroke(EntrelacsTheme.stoneColor, lineWidth: 1)
                    .padding(side * 0.18)
            }
            Circle().strokeBorder(EntrelacsTheme.ink.opacity(0.8), lineWidth: 1.1)
        }
        .frame(width: side, height: side)
        .padding(2)
    }
}

/// Tuile : pierre plus claire, filet teint.
private struct EntrelacsTileFrame: View {
    let configuration: TileConfiguration
    let dye: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4)
        configuration.content
            .background(shape.fill(Color.white.opacity(configuration.emphasized ? 0.45 : 0.3)))
            .overlay(shape.strokeBorder(dye.opacity(0.55), lineWidth: 0.9))
    }
}
