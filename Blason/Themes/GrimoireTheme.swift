import SwiftUI

extension SheetTheme {
    /// « Grimoire » : cuir sombre et encre d'or. Sections dans un filet d'or aux coins de reliure en
    /// laiton, titres centrés en capitales gravées sous un séparateur étoilé, cases en sceaux de cire.
    /// Toujours sombre. Palette : les encres (or, argent, et les émaux en version claire).
    static func grimoire(_ ink: Color) -> SheetTheme {
        var theme = SheetTheme()
        let text = GrimoireTheme.parchment
        theme.ink = text
        theme.headingColor = ink
        theme.accent = ink
        theme.colorScheme = .dark
        theme.fontDesign = .serif
        theme.pageTitleFont = .custom("HoeflerText-Regular", size: 30, relativeTo: .title2)
        theme.sectionTitleFont = .custom("HoeflerText-Regular", size: 16, relativeTo: .headline)
        theme.sectionTitleCase = .uppercase
        theme.sectionTitleTracking = 2.5
        theme.groupTitleFont = .custom("HoeflerText-Regular", size: 15, relativeTo: .subheadline)
        theme.sessionTitleFont = .custom("HoeflerText-Regular", size: 32, relativeTo: .title)
        theme.labelColor = text.opacity(0.68)
        theme.cardBackground = .clear
        theme.inputFill = GrimoireTheme.gold.opacity(0.10)
        theme.trackStroke = GrimoireTheme.gold.opacity(0.45)
        theme.rowBackground = Color.white.opacity(0.06)
        theme.journal = JournalStyle(serif: true, titleFontName: "HoeflerText-Regular", headingFontName: "Cochin-Bold",
                                     text: text, heading: ink, accent: ink)
        theme.pageBackground = { AnyView(GrainBackground(tile: GrimoireTheme.leather, fallback: GrimoireTheme.leatherColor)) }
        theme.panelBackground = theme.pageBackground
        theme.pageTitle = { AnyView(GrimoirePageTitle(configuration: $0)) }
        theme.sectionFrame = { AnyView(GrimoireSectionFrame(configuration: $0)) }
        theme.inputFrame = { AnyView(GrimoireInputFrame(field: $0)) }
        theme.checkbox = { AnyView(GrimoireCheckbox(isOn: $0, ink: ink)) }
        theme.tileFrame = { AnyView(GrimoireTileFrame(configuration: $0)) }
        return theme
    }
}

enum GrimoireTheme {
    /// Texte : parchemin pâle (#E9DFC8).
    static let parchment = Color(red: 0.91, green: 0.87, blue: 0.78)
    /// Or des filets et des titres (#C9A24A) ; laiton des coins (#8C6A28).
    static let gold = Color(red: 0.79, green: 0.64, blue: 0.29)
    static let brass = Color(red: 0.55, green: 0.42, blue: 0.16)
    /// Cuir (#2A1F1A).
    static let leatherColor = Color(red: 0.165, green: 0.122, blue: 0.10)

    /// Grain du cuir : points sombres et reflets, fibres rares.
    @MainActor static let leather: CGImage? = Grain.tile(
        base: .init(red: 0.165, green: 0.122, blue: 0.10),
        fleck: .init(red: 0.04, green: 0.03, blue: 0.02),
        fibre: .init(red: 0.40, green: 0.29, blue: 0.20),
        seed: 0x6A1E, flecks: 9000, fibres: 30)

    /// Les encres, lisibles sur le cuir : l'or d'abord, l'argent, puis les émaux en version claire
    /// (mêmes identifiants que dans l'Enluminure et l'Armorial).
    static let inks: [ThemeColor] = [
        ThemeColor(id: "or", name: "Or", color: gold),
        ThemeColor(id: "argent", name: "Argent", color: Color(red: 0.79, green: 0.78, blue: 0.74)),      // #C9C6BC
        ThemeColor(id: "gueules", name: "Gueules", color: Color(red: 0.89, green: 0.45, blue: 0.40)),    // sang clair
        ThemeColor(id: "azur", name: "Azur", color: Color(red: 0.52, green: 0.72, blue: 0.92)),          // #85B7EB
        ThemeColor(id: "sinople", name: "Sinople", color: Color(red: 0.59, green: 0.77, blue: 0.35)),    // #97C459
        ThemeColor(id: "pourpre", name: "Pourpre", color: Color(red: 0.69, green: 0.66, blue: 0.93)),    // #AFA9EC
    ]

    // MARK: Cadre

    static let frameSide: CGFloat = 48
    static let frameCorner: CGFloat = 18
    static let rule: CGFloat = 6

    /// Filet d'or ; aux angles, des coins de reliure en laiton, bordés d'or, avec un rivet.
    @MainActor static let frame: CGImage? = {
        let side = frameSide
        let gold = CGColor(srgbRed: 0.79, green: 0.64, blue: 0.29, alpha: 1)
        let brass = CGColor(srgbRed: 0.55, green: 0.42, blue: 0.16, alpha: 1)
        let rivet = CGColor(srgbRed: 0.93, green: 0.80, blue: 0.48, alpha: 1)
        return DrawnImage.make(width: side, height: side) { context in
            context.setStrokeColor(gold)
            context.setLineWidth(1)
            context.stroke(CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: rule, dy: rule))
            let leg: CGFloat = 16
            for (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (side, 0, -1, 1), (0, side, 1, -1), (side, side, -1, -1)] {
                context.move(to: CGPoint(x: x, y: y))
                context.addLine(to: CGPoint(x: x + dx * leg, y: y))
                context.addLine(to: CGPoint(x: x, y: y + dy * leg))
                context.closePath()
                context.setFillColor(brass)
                context.fillPath()
                context.move(to: CGPoint(x: x + dx * leg, y: y))
                context.addLine(to: CGPoint(x: x, y: y + dy * leg))
                context.setStrokeColor(gold)
                context.setLineWidth(1)
                context.strokePath()
                context.setFillColor(rivet)
                context.fillEllipse(in: CGRect(x: x + dx * 4.5 - 1.4, y: y + dy * 4.5 - 1.4, width: 2.8, height: 2.8))
            }
        }
    }()
}

// MARK: - Pièces

/// Séparateur « — ✦ — » : deux filets d'or et une étoile à quatre branches.
struct StarRule: View {
    var color = GrimoireTheme.gold
    var width: CGFloat = 26

    var body: some View {
        HStack(spacing: 5) {
            Rectangle().fill(color.opacity(0.7)).frame(width: width, height: 0.8)
            FourPointStar().fill(color).frame(width: 9, height: 9)
            Rectangle().fill(color.opacity(0.7)).frame(width: width, height: 0.8)
        }
        .accessibilityHidden(true)
    }

    nonisolated private struct FourPointStar: Shape {
        func path(in rect: CGRect) -> Path {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outer = min(rect.width, rect.height) / 2
            let inner = outer * 0.28
            var path = Path()
            for index in 0..<8 {
                let angle = Double(index) * .pi / 4 - .pi / 2
                let radius = index.isMultiple(of: 2) ? outer : inner
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            return path
        }
    }
}

/// Section : le titre centré en capitales gravées, le séparateur étoilé, puis le contenu, le tout
/// dans le filet d'or aux coins de reliure.
private struct GrimoireSectionFrame: View {
    let configuration: SectionFrameConfiguration

    var body: some View {
        VStack(spacing: 0) {
            if let title = configuration.title {
                VStack(spacing: 6) {
                    title
                        .multilineTextAlignment(.center)
                    StarRule()
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 12)
            }
            configuration.content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.top, configuration.title == nil ? 20 : 16)
        .padding(.bottom, 20)
        .background {
            Rectangle()
                .fill(Color.black.opacity(0.22))
                .padding(GrimoireTheme.rule)
        }
        .background {
            NineSliceFrame(image: GrimoireTheme.frame, corner: GrimoireTheme.frameCorner)
        }
    }
}

/// Titre de page, le séparateur étoilé dessous.
private struct GrimoirePageTitle: View {
    let configuration: PageTitleConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration.title
            StarRule(width: 40)
        }
    }
}

/// Ligne d'or à compléter.
private struct GrimoireInputFrame: View {
    let field: AnyView

    var body: some View {
        field
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(GrimoireTheme.gold.opacity(0.4))
                    .frame(height: 0.7)
            }
    }
}

/// Case en sceau : un cercle d'or ; cochée, un sceau de cire de l'encre choisie, cerclé d'or.
private struct GrimoireCheckbox: View {
    let isOn: Bool
    let ink: Color

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 17

    var body: some View {
        ZStack {
            if isOn {
                Circle().fill(ink)
                Circle().strokeBorder(GrimoireTheme.gold, lineWidth: 1.2)
                Circle().strokeBorder(Color.black.opacity(0.3), lineWidth: 0.6).padding(3)
            } else {
                Circle().strokeBorder(GrimoireTheme.gold.opacity(0.85), lineWidth: 1.1)
            }
        }
        .frame(width: side, height: side)
        .padding(2)
    }
}

/// Tuile : un creux plus sombre, filet d'or fin.
private struct GrimoireTileFrame: View {
    let configuration: TileConfiguration

    var body: some View {
        configuration.content
            .background(Color.black.opacity(configuration.emphasized ? 0.32 : 0.22))
            .overlay(Rectangle().strokeBorder(GrimoireTheme.gold.opacity(0.6), lineWidth: 0.7))
    }
}
