import SwiftUI

/// Lettrine : initiale d'or dans un carré d'émail, double filet d'or et points aux coins,
/// comme en tête d'un chapitre de manuscrit.
struct Lettrine: View {
    let letter: String
    /// Émail du fond (gueules, azur…).
    let field: Color
    /// Or clair (lettre, filet intérieur) et or sombre (filet extérieur, points).
    var gold = Gilding.light
    var goldShade = Gilding.shade
    var fontName = "HoeflerText-Black"

    @ScaledMetric(relativeTo: .title3) private var side: CGFloat = 38

    var body: some View {
        ZStack {
            Rectangle().fill(field)
            Rectangle().strokeBorder(goldShade, lineWidth: 1.6)
            Rectangle().strokeBorder(gold.opacity(0.75), lineWidth: 0.6).padding(3.2)
            corners
            Text(letter)
                .themeFont(.custom(fontName, fixedSize: side * 0.74))
                .foregroundStyle(gold)
                .offset(y: side * 0.04)
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }

    /// Quatre besants d'or dans les angles, entre les deux filets.
    private var corners: some View {
        let dot = side * 0.075
        let inset = side * 0.17
        return ZStack {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(gold)
                    .frame(width: dot, height: dot)
                    .offset(x: (index % 2 == 0 ? -1 : 1) * (side / 2 - inset),
                            y: (index < 2 ? -1 : 1) * (side / 2 - inset))
            }
        }
    }

    /// Initiale d'un titre, si elle peut s'enluminer (une lettre) : sinon nil.
    static func split(_ title: String) -> (initial: String, rest: String)? {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first, first.isLetter else { return nil }
        return (String(first).uppercased(), String(trimmed.dropFirst()))
    }
}
