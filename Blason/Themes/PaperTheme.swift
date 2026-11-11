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

    /// Grain du papier : une tuile dessinée une fois (points et fibres, tirage reproductible).
    /// Dessinée avec Core Graphics, à 3 pixels par point, identique sur iOS et macOS.
    @MainActor static let texture: CGImage? = {
        let side: CGFloat = 256
        var random = SplitMix64(seed: 0x5EED)
        func srgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
            CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
        }
        // Tuile opaque, points mélangés au papier (et non copiés : ils feraient des trous).
        return DrawnImage.make(width: side, height: side, opaque: true) { context in
            context.setFillColor(srgb(0.955, 0.93, 0.865))
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            for _ in 0..<7000 {
                let dark = Bool.random(using: &random)
                let alpha = CGFloat.random(in: 0.015...0.06, using: &random)
                context.setFillColor(dark ? srgb(0.35, 0.28, 0.18, alpha) : srgb(1, 1, 1, alpha * 1.5))
                let size = CGFloat.random(in: 0.6...1.6, using: &random)
                context.fill(CGRect(x: .random(in: 0..<side, using: &random), y: .random(in: 0..<side, using: &random),
                                    width: size, height: size))
            }
            context.setLineWidth(0.5)
            for _ in 0..<45 {
                context.setStrokeColor(srgb(0.45, 0.36, 0.24, .random(in: 0.04...0.09, using: &random)))
                let start = CGPoint(x: .random(in: 0..<side, using: &random), y: .random(in: 0..<side, using: &random))
                let end = CGPoint(x: start.x + .random(in: -14...14, using: &random), y: start.y + .random(in: -14...14, using: &random))
                let control = CGPoint(x: start.x + .random(in: -8...8, using: &random), y: start.y + .random(in: -8...8, using: &random))
                context.move(to: start)
                context.addQuadCurve(to: end, control: control)
                context.strokePath()
            }
        }
    }()
}

/// Générateur reproductible : la texture est la même à chaque lancement.
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private struct PaperBackground: View {
    var body: some View {
        if let texture = PaperTheme.texture {
            Image(decorative: texture, scale: 3)
                .resizable(resizingMode: .tile)
        } else {
            PaperTheme.paper
        }
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
