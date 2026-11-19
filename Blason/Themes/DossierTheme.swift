import SwiftUI

extension SheetTheme {
    /// « Dossier 1920 » : le dossier d'un enquêteur des années 1920. Chaque section est un feuillet
    /// dactylographié aux coins coupés, posé sur une chemise kraft, dans un double filet Art déco ;
    /// son titre dans un bandeau noir en capitales espacées (Futura). Valeurs et récit tapés à la
    /// machine (American Typewriter), tampon « CONFIDENTIEL » près du titre de page. Toujours clair.
    /// Palette : les encres du tampon, qui marquent aussi les cases et les valeurs courantes.
    static func dossier(_ ink: Color) -> SheetTheme {
        var theme = SheetTheme()
        let black = DossierTheme.ink
        theme.ink = black
        theme.headingColor = black
        theme.accent = ink
        theme.colorScheme = .light
        theme.bodyFont = .custom("AmericanTypewriter", size: 16, relativeTo: .body)
        theme.pageTitleFont = .custom("Futura-CondensedExtraBold", size: 32, relativeTo: .title2)
        theme.sectionTitleFont = .custom("Futura-Medium", size: 14, relativeTo: .headline)
        theme.sectionTitleCase = .uppercase
        theme.sectionTitleTracking = 3
        theme.groupTitleFont = .custom("Futura-Bold", size: 14, relativeTo: .subheadline)
        theme.sessionTitleFont = .custom("Futura-CondensedExtraBold", size: 32, relativeTo: .title)
        theme.labelColor = black.opacity(0.62)
        theme.cardBackground = .clear
        theme.inputFill = black.opacity(0.05)
        theme.trackStroke = black.opacity(0.4)
        theme.rowBackground = DossierTheme.paper
        theme.journal = JournalStyle(bodyFontName: "AmericanTypewriter", titleFontName: "Futura-CondensedExtraBold",
                                     headingFontName: "Futura-Bold", text: black, heading: black, accent: ink)
        theme.pageBackground = { AnyView(GrainBackground(tile: DossierTheme.manila, fallback: DossierTheme.manilaColor)) }
        theme.panelBackground = theme.pageBackground
        theme.pageTitle = { AnyView(DossierPageTitle(configuration: $0, ink: ink)) }
        theme.sectionFrame = { AnyView(DossierSectionFrame(configuration: $0)) }
        theme.inputFrame = { AnyView(DossierInputFrame(field: $0)) }
        theme.checkbox = { AnyView(DossierCheckbox(isOn: $0, ink: ink)) }
        theme.tileFrame = { AnyView(DossierTileFrame(configuration: $0)) }
        return theme
    }
}

enum DossierTheme {
    /// Encre de la machine à écrire (#232120).
    static let ink = Color(red: 0.137, green: 0.129, blue: 0.125)
    /// Feuillet dactylographié (#F5F0E3).
    static let paper = Color(red: 0.96, green: 0.94, blue: 0.89)
    /// Chemise kraft (#D9CBA3).
    static let manilaColor = Color(red: 0.85, green: 0.795, blue: 0.64)

    /// Grain de la chemise : fibres nombreuses, comme un carton.
    @MainActor static let manila: CGImage? = Grain.tile(
        base: .init(red: 0.85, green: 0.795, blue: 0.64),
        fleck: .init(red: 0.45, green: 0.36, blue: 0.20),
        fibre: .init(red: 0.55, green: 0.45, blue: 0.28),
        seed: 0x1920, flecks: 8000, fibres: 140)

    /// Encres du tampon.
    static let inks: [ThemeColor] = [
        ThemeColor(id: "rouge", name: "Rouge tampon", color: Color(red: 0.64, green: 0.15, blue: 0.16)), // #A3262A
        ThemeColor(id: "bleu", name: "Bleu encre", color: Color(red: 0.12, green: 0.23, blue: 0.45)),    // #1F3B73
        ThemeColor(id: "vert", name: "Vert bureau", color: Color(red: 0.18, green: 0.36, blue: 0.27)),   // #2E5B45
        ThemeColor(id: "noir", name: "Noir", color: Color(red: 0.16, green: 0.16, blue: 0.15)),          // #2A2826
    ]

    /// Coin coupé du feuillet et des cadres.
    static let cut: CGFloat = 12
}

// MARK: - Pièces

/// Rectangle aux coins coupés en biais, la forme Art déco du dossier.
nonisolated struct ChamferedRectangle: InsettableShape {
    var cut: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        let cut = max(0, min(cut - inset * 0.4, min(rect.width, rect.height) / 2))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> ChamferedRectangle {
        ChamferedRectangle(cut: cut, inset: inset + amount)
    }
}

/// Trois barres verticales, l'ornement Art déco du bandeau.
private struct DecoBars: View {
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { _ in
                Rectangle().fill(color).frame(width: 2, height: 11)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Section : feuillet aux coins coupés sur la chemise, double filet ; en tête, le bandeau noir.
private struct DossierSectionFrame: View {
    let configuration: SectionFrameConfiguration

    @Environment(\.sheetTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let text = configuration.titleText {
                band(text)
            } else if let title = configuration.title {
                title
            }
            configuration.content
        }
        .padding(.horizontal, 16)
        .padding(.top, configuration.title == nil ? 18 : 14)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                ChamferedRectangle(cut: DossierTheme.cut)
                    .fill(DossierTheme.paper)
                    .shadow(color: .black.opacity(0.14), radius: 2, y: 1)
                ChamferedRectangle(cut: DossierTheme.cut)
                    .strokeBorder(DossierTheme.ink, lineWidth: 1.4)
                    .padding(4)
                ChamferedRectangle(cut: DossierTheme.cut)
                    .strokeBorder(DossierTheme.ink.opacity(0.7), lineWidth: 0.6)
                    .padding(7)
            }
            .accessibilityHidden(true)
        }
    }

    /// Bandeau noir : le titre en capitales espacées, couleur du papier, et les barres Art déco.
    private func band(_ text: String) -> some View {
        HStack(spacing: 10) {
            Text(text)
                .themeFont(theme.sectionTitleFont)
                .textCase(theme.sectionTitleCase)
                .tracking(theme.sectionTitleTracking)
                .foregroundStyle(DossierTheme.paper)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            DecoBars(color: DossierTheme.paper.opacity(0.75))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(ChamferedRectangle(cut: 6).fill(DossierTheme.ink))
    }
}

/// Tampon « CONFIDENTIEL » : double cadre, de travers, encre un peu passée.
struct ConfidentialStamp: View {
    let ink: Color

    var body: some View {
        Text("CONFIDENTIEL")
            .themeFont(.custom("Futura-Bold", fixedSize: 12))
            .tracking(2.5)
            .foregroundStyle(ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(ink, lineWidth: 1.6))
            .padding(2.5)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(ink, lineWidth: 0.7))
            .opacity(0.8)
            .rotationEffect(.degrees(-6))
            .fixedSize()
            .accessibilityHidden(true)
    }
}

/// Titre de page (et de session) : capitales condensées, double filet dessous, tampon au bout du
/// filet (à côté du titre, il raccourcissait le titre de session sur iPhone).
private struct DossierPageTitle: View {
    let configuration: PageTitleConfiguration
    let ink: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            configuration.title
            HStack(alignment: .center, spacing: 14) {
                VStack(spacing: 2) {
                    Rectangle().frame(height: 2.2)
                    Rectangle().frame(height: 0.7)
                }
                .foregroundStyle(DossierTheme.ink)
                .frame(width: 160)
                .accessibilityHidden(true)
                ConfidentialStamp(ink: ink)
            }
        }
    }
}

/// Ligne de formulaire à remplir à la machine.
private struct DossierInputFrame: View {
    let field: AnyView

    var body: some View {
        field
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DossierTheme.ink.opacity(0.45))
                    .frame(height: 0.8)
            }
    }
}

/// Case de formulaire ; cochée, un X tapé à la machine, à l'encre du tampon.
private struct DossierCheckbox: View {
    let isOn: Bool
    let ink: Color

    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 17

    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(DossierTheme.ink.opacity(0.85), lineWidth: 1.1)
            if isOn {
                Text(verbatim: "X")
                    .themeFont(.custom("AmericanTypewriter-Bold", fixedSize: side * 0.95))
                    .foregroundStyle(ink)
                    .offset(y: -side * 0.03)
            }
        }
        .frame(width: side, height: side)
        .padding(2)
    }
}

/// Tuile : coins coupés, filet fin.
private struct DossierTileFrame: View {
    let configuration: TileConfiguration

    var body: some View {
        let shape = ChamferedRectangle(cut: 7)
        configuration.content
            .background(shape.fill(DossierTheme.ink.opacity(configuration.emphasized ? 0.07 : 0.035)))
            .overlay(shape.strokeBorder(DossierTheme.ink.opacity(0.6), lineWidth: 0.8))
    }
}
