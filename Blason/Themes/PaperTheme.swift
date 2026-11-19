import SwiftUI

extension SheetTheme {
    /// « Fiche papier » : papier crème au grain léger, encre, cadres à double filet, titres en
    /// capitales gravées, lignes à compléter au lieu de cases grises. Toujours clair, comme du papier.
    static let paper: SheetTheme = {
        var theme = SheetTheme()
        theme.ink = PaperTheme.ink
        theme.headingColor = PaperTheme.ink
        theme.accent = PaperTheme.ink
        theme.colorScheme = .light
        theme.fontDesign = .serif
        theme.pageTitleFont = .custom("Baskerville-SemiBold", size: 28, relativeTo: .title2)
        theme.sectionTitleFont = .custom("Copperplate", size: 16, relativeTo: .headline)
        theme.sectionTitleCase = .uppercase
        theme.sectionTitleTracking = 1.2
        theme.cardBackground = .clear
        theme.inputFill = PaperTheme.ink.opacity(0.05)
        theme.trackStroke = PaperTheme.ink.opacity(0.55)
        theme.pageBackground = { AnyView(PaperBackground()) }
        theme.sectionFrame = { AnyView(PaperSectionFrame(configuration: $0)) }
        theme.inputFrame = { AnyView(PaperInputFrame(field: $0)) }
        theme.checkbox = { AnyView(PaperCheckbox(isOn: $0)) }
        return theme
    }()
}

enum PaperTheme {
    static let ink = Color(red: 0.17, green: 0.15, blue: 0.13)
    static let paper = Color(red: 0.955, green: 0.93, blue: 0.865)

    /// Grain du papier : points et fibres brunes (voir `Grain`).
    @MainActor static let texture: CGImage? = Grain.tile(
        base: .init(red: 0.955, green: 0.93, blue: 0.865),
        fleck: .init(red: 0.35, green: 0.28, blue: 0.18),
        fibre: .init(red: 0.45, green: 0.36, blue: 0.24),
        seed: 0x5EED)
}

private struct PaperBackground: View {
    var body: some View {
        GrainBackground(tile: PaperTheme.texture, fallback: PaperTheme.paper)
    }
}

/// Cadre à double filet ; le titre est posé sur le filet du haut, comme sur une fiche imprimée.
private struct PaperSectionFrame: View {
    let configuration: SectionFrameConfiguration

    var body: some View {
        configuration.content
            .padding(.horizontal, 16)
            .padding(.top, configuration.title == nil ? 16 : 22)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    Rectangle().strokeBorder(PaperTheme.ink, lineWidth: 1.4)
                    Rectangle().strokeBorder(PaperTheme.ink.opacity(0.6), lineWidth: 0.6).padding(3.5)
                }
            }
            .overlay(alignment: .topLeading) {
                if let title = configuration.title {
                    title
                        .padding(.horizontal, 6)
                        .background(PaperTheme.paper)
                        .alignmentGuide(.top) { $0[VerticalAlignment.center] }
                        .padding(.leading, 12)
                }
            }
            .padding(.top, configuration.title == nil ? 0 : 8)
    }
}

/// Ligne à compléter.
private struct PaperInputFrame: View {
    let field: AnyView

    var body: some View {
        field
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(PaperTheme.ink.opacity(0.5))
                    .frame(height: 0.8)
            }
    }
}

/// Case tracée à l'encre, cochée d'une croix.
private struct PaperCheckbox: View {
    let isOn: Bool

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 17

    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(PaperTheme.ink, lineWidth: 1.2)
            if isOn {
                Image(systemName: "xmark")
                    .font(.system(size: side * 0.7, weight: .bold))
                    .foregroundStyle(PaperTheme.ink)
            }
        }
        .frame(width: side, height: side)
        .padding(2)
    }
}
