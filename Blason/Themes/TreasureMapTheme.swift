import SwiftUI

extension SheetTheme {
    /// « Carte au trésor » : parchemin sépia taché, comme une carte marine ou un journal de bord.
    /// Sections dans une corde, rose des vents en coin, titres manuscrits (Snell Roundhand), lignes
    /// en pointillés comme une route sur la carte, cases cochées d'une croix rouge (« X marque
    /// l'endroit »). Toujours clair. Palette : les encres du navigateur.
    static func treasureMap(_ ink: Color) -> SheetTheme {
        var theme = SheetTheme()
        let sepia = TreasureMapTheme.sepia
        theme.ink = sepia
        theme.headingColor = ink
        theme.accent = ink
        theme.colorScheme = .light
        theme.fontDesign = .serif
        theme.pageTitleFont = .custom("SnellRoundhand-Black", size: 36, relativeTo: .title2)
        theme.sectionTitleFont = .custom("SnellRoundhand-Bold", size: 24, relativeTo: .title3)
        theme.groupTitleFont = .custom("SnellRoundhand-Bold", size: 19, relativeTo: .subheadline)
        theme.sessionTitleFont = .custom("SnellRoundhand-Black", size: 36, relativeTo: .title)
        theme.labelColor = sepia.opacity(0.72)
        theme.cardBackground = .clear
        theme.inputFill = sepia.opacity(0.07)
        theme.trackStroke = sepia.opacity(0.45)
        theme.rowBackground = Color.white.opacity(0.25)
        theme.journal = JournalStyle(serif: true, titleFontName: "SnellRoundhand-Black",
                                     headingFontName: "SnellRoundhand-Bold", fontScale: 1.35,
                                     text: sepia, heading: ink, accent: ink)
        theme.pageBackground = { AnyView(GrainBackground(tile: TreasureMapTheme.parchment, fallback: TreasureMapTheme.paper,
                                                            foxing: TreasureMapTheme.foxing)) }
        theme.panelBackground = theme.pageBackground
        theme.pageTitle = { AnyView(TreasureMapPageTitle(configuration: $0, ink: ink)) }
        theme.sectionFrame = { AnyView(TreasureMapSectionFrame(configuration: $0, ink: ink)) }
        theme.inputFrame = { AnyView(TreasureMapInputFrame(field: $0)) }
        theme.checkbox = { AnyView(TreasureMapCheckbox(isOn: $0, ink: ink)) }
        theme.tileFrame = { AnyView(TreasureMapTileFrame(configuration: $0)) }
        return theme
    }
}

enum TreasureMapTheme {
    /// Encre sépia (#3E2A16).
    static let sepia = Color(red: 0.243, green: 0.165, blue: 0.086)
    /// Parchemin (#EAD9B8).
    static let paper = Color(red: 0.918, green: 0.851, blue: 0.722)
    /// Corde : chanvre clair et ombre des torons.
    static let rope = Color(red: 0.69, green: 0.54, blue: 0.35)
    static let ropeShade = Color(red: 0.48, green: 0.35, blue: 0.21)
    /// Taches de rousseur.
    static let foxing = Color(red: 0.42, green: 0.27, blue: 0.10)

    /// Grain du parchemin : fibres nombreuses et taches de rousseur.
    @MainActor static let parchment: CGImage? = Grain.tile(
        base: .init(red: 0.918, green: 0.851, blue: 0.722),
        fleck: .init(red: 0.42, green: 0.27, blue: 0.10),
        fibre: .init(red: 0.50, green: 0.36, blue: 0.20),
        seed: 0x7EA5, flecks: 8000, fibres: 80)

    /// Encres du navigateur ; le carmin est celui des routes et des croix sur les cartes.
    static let inks: [ThemeColor] = [
        ThemeColor(id: "carmin", name: "Carmin", color: Color(red: 0.61, green: 0.17, blue: 0.17)),   // #9B2C2C
        ThemeColor(id: "marine", name: "Bleu marine", color: Color(red: 0.12, green: 0.23, blue: 0.37)), // #1F3A5F
        ThemeColor(id: "ocean", name: "Vert océan", color: Color(red: 0.12, green: 0.37, blue: 0.33)), // #1F5F55
        ThemeColor(id: "sepia", name: "Sépia", color: Color(red: 0.36, green: 0.24, blue: 0.12)),     // #5C3D1F
    ]
}

// MARK: - Pièces

/// Corde : un trait de chanvre, barré de torons plus sombres.
private struct Rope<S: Shape>: View {
    let shape: S
    var width: CGFloat = 3

    var body: some View {
        ZStack {
            shape.stroke(TreasureMapTheme.rope, lineWidth: width)
            shape.stroke(TreasureMapTheme.ropeShade, style: StrokeStyle(lineWidth: width, dash: [1.4, 2.6]))
        }
        .accessibilityHidden(true)
    }
}

/// Section : le titre manuscrit en haut à gauche, le contenu, dans une corde ; la rose des vents
/// déborde sur l'angle en haut à droite.
private struct TreasureMapSectionFrame: View {
    let configuration: SectionFrameConfiguration
    let ink: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = configuration.title {
                title.padding(.trailing, 28)
            }
            configuration.content
        }
        .padding(.horizontal, 18)
        .padding(.top, configuration.title == nil ? 18 : 10)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: 6)
            shape.fill(Color.white.opacity(0.18))
            Rope(shape: shape).padding(1.5)
        }
        .overlay(alignment: .topTrailing) {
            CompassRose(north: ink)
                .frame(width: 38, height: 38)
                .offset(x: 12, y: -12)
        }
        .padding(.top, 12)
        .padding(.trailing, 12)
    }
}

/// Rose des vents : quatre grandes pointes, quatre petites, la pointe du nord à l'encre choisie.
struct CompassRose: View {
    let north: Color

    var body: some View {
        ZStack {
            Circle().fill(TreasureMapTheme.paper)
            Circle().stroke(TreasureMapTheme.sepia.opacity(0.7), lineWidth: 0.8).padding(4)
            Star(points: 4, inner: 0.22).rotation(.degrees(45)).fill(TreasureMapTheme.sepia.opacity(0.55)).padding(9)
            Star(points: 4, inner: 0.2).fill(TreasureMapTheme.sepia)
            HalfPoint().fill(north)
            Circle().fill(TreasureMapTheme.paper).frame(width: 3.5, height: 3.5)
        }
        .accessibilityHidden(true)
    }

    nonisolated private struct Star: Shape {
        let points: Int
        let inner: CGFloat

        func path(in rect: CGRect) -> Path {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outer = min(rect.width, rect.height) / 2
            var path = Path()
            for index in 0..<(points * 2) {
                let angle = Double(index) * .pi / Double(points) - .pi / 2
                let radius = index.isMultiple(of: 2) ? outer : outer * inner
                let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            return path
        }
    }

    /// Pointe du nord, en couleur.
    nonisolated private struct HalfPoint: Shape {
        func path(in rect: CGRect) -> Path {
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let outer = min(rect.width, rect.height) / 2
            let side = outer * 0.2 * cos(.pi / 4)
            var path = Path()
            path.move(to: CGPoint(x: center.x, y: center.y - outer))
            path.addLine(to: CGPoint(x: center.x + side, y: center.y - side))
            path.addLine(to: center)
            path.addLine(to: CGPoint(x: center.x - side, y: center.y - side))
            path.closeSubpath()
            return path
        }
    }
}

/// Titre de page manuscrit, souligné d'une vague à l'encre choisie.
private struct TreasureMapPageTitle: View {
    let configuration: PageTitleConfiguration
    let ink: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.title
            Wave()
                .stroke(ink.opacity(0.75), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                .frame(width: 160, height: 8)
                .accessibilityHidden(true)
        }
    }

    nonisolated private struct Wave: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let steps = 60
            for step in 0...steps {
                let progress = CGFloat(step) / CGFloat(steps)
                // Vague qui s'amenuise vers la fin, comme un trait de plume.
                let amplitude = rect.height / 2 * (1 - progress * 0.6)
                let point = CGPoint(x: rect.minX + progress * rect.width,
                                    y: rect.midY + amplitude * sin(progress * .pi * 5))
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            return path
        }
    }
}

/// Route en pointillés à compléter.
private struct TreasureMapInputFrame: View {
    let field: AnyView

    var body: some View {
        field
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .overlay(alignment: .bottom) {
                DottedLine()
                    .stroke(TreasureMapTheme.sepia.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [0.1, 3.4]))
                    .frame(height: 1.2)
            }
    }

    nonisolated private struct DottedLine: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

/// Case tracée à la plume ; cochée, la croix de la carte au trésor, à l'encre choisie.
private struct TreasureMapCheckbox: View {
    let isOn: Bool
    let ink: Color

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 17

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(TreasureMapTheme.sepia.opacity(0.8), lineWidth: 1.1)
            if isOn {
                Cross()
                    .stroke(ink, style: StrokeStyle(lineWidth: side * 0.16, lineCap: .round))
                    .padding(-side * 0.08)
            }
        }
        .frame(width: side, height: side)
        .padding(2)
    }

    /// Croix légèrement de travers, tracée à main levée.
    nonisolated private struct Cross: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.08))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - rect.width * 0.06, y: rect.maxY - rect.height * 0.12),
                              control: CGPoint(x: rect.midX + rect.width * 0.08, y: rect.midY - rect.height * 0.04))
            path.move(to: CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.minY + rect.height * 0.04))
            path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY - rect.height * 0.06),
                              control: CGPoint(x: rect.midX - rect.width * 0.02, y: rect.midY + rect.height * 0.06))
            return path
        }
    }
}

/// Tuile : parchemin plus clair, cordelette fine.
private struct TreasureMapTileFrame: View {
    let configuration: TileConfiguration

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 5)
        configuration.content
            .background(shape.fill(Color.white.opacity(configuration.emphasized ? 0.32 : 0.2)))
            .overlay(Rope(shape: shape, width: 1.6).padding(0.8))
    }
}
