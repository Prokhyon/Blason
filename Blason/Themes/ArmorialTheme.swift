import SwiftUI

extension SheetTheme {
    /// « Armorial » : héraldique sur papier ivoire. Titre de section sur une banderole d'émail en
    /// lettres d'or, posée sur un cadre à double filet doré aux coins losangés ; titre de page dans
    /// un cartouche ; cases en forme d'écu. Toujours clair. Palette : les émaux.
    static func armorial(_ tincture: Color) -> SheetTheme {
        var theme = SheetTheme()
        let ink = ArmorialTheme.ink
        theme.ink = ink
        theme.headingColor = tincture
        theme.accent = tincture
        theme.colorScheme = .light
        theme.fontDesign = .serif
        theme.pageTitleFont = .custom("Copperplate-Bold", size: 24, relativeTo: .title2)
        theme.sectionTitleFont = .custom("Copperplate-Bold", size: 15, relativeTo: .headline)
        theme.sectionTitleCase = .uppercase
        theme.sectionTitleTracking = 1.4
        theme.groupTitleFont = .custom("Copperplate-Bold", size: 14, relativeTo: .subheadline)
        theme.sessionTitleFont = .custom("Copperplate-Bold", size: 26, relativeTo: .title)
        theme.labelColor = ink.opacity(0.75)
        theme.cardBackground = .clear
        theme.inputFill = tincture.opacity(0.07)
        theme.trackStroke = ink.opacity(0.4)
        theme.rowBackground = Color.white.opacity(0.55)
        theme.journal = JournalStyle(serif: true, titleFontName: "Copperplate-Bold", headingFontName: "Copperplate-Bold",
                                     text: ink, heading: tincture, accent: tincture)
        theme.pageBackground = { AnyView(GrainBackground(tile: ArmorialTheme.ivory, fallback: ArmorialTheme.paper)) }
        theme.panelBackground = theme.pageBackground
        theme.pageTitle = { AnyView(ArmorialPageTitle(configuration: $0)) }
        theme.sectionFrame = { AnyView(ArmorialSectionFrame(configuration: $0, tincture: tincture)) }
        theme.inputFrame = { AnyView(ArmorialInputFrame(field: $0)) }
        theme.checkbox = { AnyView(ArmorialCheckbox(isOn: $0, tincture: tincture)) }
        theme.tileFrame = { AnyView(ArmorialTileFrame(configuration: $0)) }
        return theme
    }
}

enum ArmorialTheme {
    static let ink = Color(red: 0.15, green: 0.15, blue: 0.14)
    /// Papier ivoire (#FBF8F1), plus clair et plus froid que le vélin.
    static let paper = Color(red: 0.984, green: 0.973, blue: 0.945)

    /// Grain discret : quelques points, peu de fibres.
    @MainActor static let ivory: CGImage? = Grain.tile(
        base: .init(red: 0.984, green: 0.973, blue: 0.945),
        fleck: .init(red: 0.40, green: 0.36, blue: 0.28),
        fibre: .init(red: 0.50, green: 0.44, blue: 0.32),
        seed: 0xA4A1, flecks: 3500, fibres: 20)

    // MARK: Cadre

    /// Taille de l'image du cadre et de ses coins fixes.
    static let frameSide: CGFloat = 48
    static let frameCorner: CGFloat = 18
    /// Distance du bord au filet extérieur : la banderole s'y pose.
    static let outerRule: CGFloat = 7

    @MainActor static let frames = TintedImageCache(draw: drawFrame(tincture:))

    /// Double filet d'or ; à chaque angle, un losange d'émail cerclé d'or et un besant.
    private static func drawFrame(tincture: CGColor) -> CGImage? {
        let side = frameSide
        let gold = Gilding.shadeCG
        return DrawnImage.make(width: side, height: side) { context in
            context.setStrokeColor(gold)
            context.setLineWidth(1.4)
            context.stroke(CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: outerRule, dy: outerRule))
            context.setStrokeColor(gold.copy(alpha: 0.8) ?? gold)
            context.setLineWidth(0.7)
            context.stroke(CGRect(x: 0, y: 0, width: side, height: side).insetBy(dx: outerRule + 3.5, dy: outerRule + 3.5))
            for x in [outerRule, side - outerRule] {
                for y in [outerRule, side - outerRule] {
                    let half: CGFloat = 5.6
                    context.move(to: CGPoint(x: x, y: y + half))
                    context.addLine(to: CGPoint(x: x + half, y: y))
                    context.addLine(to: CGPoint(x: x, y: y - half))
                    context.addLine(to: CGPoint(x: x - half, y: y))
                    context.closePath()
                    context.setFillColor(tincture)
                    context.setStrokeColor(gold)
                    context.setLineWidth(0.9)
                    context.drawPath(using: .fillStroke)
                    context.setFillColor(CGColor(srgbRed: 0.98, green: 0.78, blue: 0.46, alpha: 1))
                    context.fillEllipse(in: CGRect(x: x - 1.3, y: y - 1.3, width: 2.6, height: 2.6))
                }
            }
        }
    }
}

// MARK: - Pièces

/// Section : la banderole à cheval sur le filet du haut, centrée ; dessous, le cadre doré.
private struct ArmorialSectionFrame: View {
    let configuration: SectionFrameConfiguration
    let tincture: Color

    @Environment(\.sheetTheme) private var theme

    /// Part de la banderole qui descend sur le cadre.
    private let overlap: CGFloat = 18

    var body: some View {
        if let text = configuration.titleText {
            VStack(spacing: -overlap) {
                Banderole(text: text, tincture: tincture, font: theme.sectionTitleFont,
                          tracking: theme.sectionTitleTracking)
                    .padding(.horizontal, 24)
                    .zIndex(1)
                framed(topPadding: overlap + 10)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                // « Section sans titre » du mode Structure.
                if let title = configuration.title { title.padding(.horizontal, 4) }
                framed(topPadding: 18)
            }
        }
    }

    private func framed(topPadding: CGFloat) -> some View {
        configuration.content
            .padding(.horizontal, 20)
            .padding(.top, topPadding)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Rectangle()
                    .fill(Color.white.opacity(0.55))
                    .padding(ArmorialTheme.outerRule)
            }
            .background {
                NineSliceFrame(image: ArmorialTheme.frames.image(for: tincture), corner: ArmorialTheme.frameCorner)
            }
    }
}

/// Banderole d'émail, lettres d'or (couleur sur métal, comme le veut le blason), bouts fendus repliés
/// derrière.
struct Banderole: View {
    let text: String
    let tincture: Color
    let font: Font
    var tracking: CGFloat = 1.4

    var body: some View {
        Text(text)
            .font(font)
            .textCase(.uppercase)
            .tracking(tracking)
            .foregroundStyle(Gilding.light)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 22)
            .padding(.vertical, 7)
            .background {
                NotchedBand()
                    .fill(tincture)
                    .overlay(NotchedBand().stroke(Gilding.shade, lineWidth: 0.8))
            }
            .background(alignment: .leading) { tail.offset(x: -11, y: 5) }
            .background(alignment: .trailing) { tail.scaleEffect(x: -1).offset(x: 11, y: 5) }
            .accessibilityAddTraits(.isHeader)
    }

    private var tail: some View {
        SwallowTail()
            .fill(tincture.mix(with: .black, by: 0.35))
            .overlay(SwallowTail().stroke(Gilding.shade, lineWidth: 0.6))
            .frame(width: 18)
    }

    /// Bande aux bouts entaillés en V.
    nonisolated private struct NotchedBand: Shape {
        func path(in rect: CGRect) -> Path {
            let notch = min(8, rect.height * 0.3)
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
            path.closeSubpath()
            return path
        }
    }

    /// Bout replié, fendu en queue d'aronde (vers la gauche).
    nonisolated private struct SwallowTail: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.15))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.15))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
    }
}

/// Titre de page dans un cartouche aux angles rentrants, double filet d'or.
private struct ArmorialPageTitle: View {
    let configuration: PageTitleConfiguration

    var body: some View {
        configuration.title
            .padding(.horizontal, 26)
            .padding(.vertical, 10)
            .background {
                ZStack {
                    Cartouche().fill(Color.white.opacity(0.6))
                    Cartouche().stroke(Gilding.shade, lineWidth: 1.4)
                    Cartouche().stroke(Gilding.shade.opacity(0.8), lineWidth: 0.6).padding(3.5)
                }
            }
    }

    nonisolated private struct Cartouche: Shape {
        func path(in rect: CGRect) -> Path {
            let radius = min(10, rect.height * 0.3)
            var path = Path()
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                              control: CGPoint(x: rect.maxX - radius, y: rect.minY + radius))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                              control: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                              control: CGPoint(x: rect.minX + radius, y: rect.maxY - radius))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                              control: CGPoint(x: rect.minX + radius, y: rect.minY + radius))
            path.closeSubpath()
            return path
        }
    }
}

/// Ligne d'encre à compléter.
private struct ArmorialInputFrame: View {
    let field: AnyView

    var body: some View {
        field
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(ArmorialTheme.ink.opacity(0.4))
                    .frame(height: 0.7)
            }
    }
}

/// Case en forme d'écu : vide, tracée à l'encre ; cochée, pleine d'émail et bordée d'or.
private struct ArmorialCheckbox: View {
    let isOn: Bool
    let tincture: Color

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 17

    var body: some View {
        Group {
            if isOn {
                Escutcheon()
                    .fill(tincture)
                    .overlay(Escutcheon().stroke(Gilding.shade, lineWidth: 1.2))
            } else {
                Escutcheon().stroke(ArmorialTheme.ink, lineWidth: 1.1)
            }
        }
        .frame(width: side * 0.85, height: side)
        .padding(2)
    }

    /// Écu français : chef droit, flancs droits, pointe en accolade.
    nonisolated private struct Escutcheon: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.5))
            path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                              control: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.88))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.5),
                              control: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.88))
            path.closeSubpath()
            return path
        }
    }
}

/// Tuile : papier plus clair, double filet d'or fin.
private struct ArmorialTileFrame: View {
    let configuration: TileConfiguration

    var body: some View {
        configuration.content
            .background(Color.white.opacity(configuration.emphasized ? 0.7 : 0.5))
            .overlay {
                ZStack {
                    Rectangle().strokeBorder(Gilding.shade, lineWidth: 0.9)
                    Rectangle().strokeBorder(Gilding.shade.opacity(0.7), lineWidth: 0.4).padding(2.5)
                }
            }
    }
}
