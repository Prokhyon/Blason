import SwiftUI

/// Rinceau : une tige de vigne qui ondule le long d'une marge, feuilles de sinople et baies d'émail
/// cerclées d'or. Une tuile dessinée une fois par émail, répétée sur la hauteur ; un losange
/// d'émail la termine en haut et en bas.
struct VineBorder: View {
    let tint: Color

    static let width: CGFloat = 18

    var body: some View {
        VStack(spacing: 0) {
            finial
            Group {
                if let tile = Self.tile(for: tint) {
                    Image(decorative: tile, scale: 3)
                        .resizable(resizingMode: .tile)
                } else {
                    Rectangle().fill(Self.stem).frame(width: 1.2)
                }
            }
            .frame(maxHeight: .infinity)
            finial
        }
        .frame(width: Self.width)
        .accessibilityHidden(true)
    }

    private var finial: some View {
        Rectangle()
            .fill(tint)
            .overlay(Rectangle().strokeBorder(Gilding.shade, lineWidth: 0.8))
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(45))
            .frame(width: Self.width, height: 14)
    }

    // MARK: Tuile

    private static let stem = Color(red: 0.23, green: 0.43, blue: 0.07)    // sinople #3B6D11
    private static let tileHeight: CGFloat = 72
    @MainActor private static let tiles = TintedImageCache(draw: drawTile(berry:))

    @MainActor static func tile(for tint: Color) -> CGImage? {
        tiles.image(for: tint)
    }

    /// La tige fait une période entière sur la hauteur de la tuile : les tuiles se raccordent.
    private static func drawTile(berry: CGColor) -> CGImage? {
        let width = Self.width, height = tileHeight
        let center = width / 2, amplitude: CGFloat = 4.5
        func stemX(_ y: CGFloat) -> CGFloat { center + amplitude * sin(2 * .pi * y / height) }
        let green = CGColor(srgbRed: 0.23, green: 0.43, blue: 0.07, alpha: 1)
        let leaf = CGColor(srgbRed: 0.39, green: 0.60, blue: 0.13, alpha: 1)       // #639922
        let gold = CGColor(srgbRed: 0.73, green: 0.46, blue: 0.09, alpha: 1)

        return DrawnImage.make(width: width, height: height) { context in
            // Tige.
            context.setStrokeColor(green)
            context.setLineWidth(1.3)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: stemX(-1), y: -1))
            for step in 0...72 {
                let y = CGFloat(step) / 72 * (height + 2) - 1
                context.addLine(to: CGPoint(x: stemX(y), y: y))
            }
            context.strokePath()

            // Feuilles, de part et d'autre de la tige.
            func drawLeaf(at y: CGFloat, side: CGFloat) {
                context.saveGState()
                context.translateBy(x: stemX(y) + side * 3.9, y: y + 1.8)
                context.rotate(by: side * -0.55)
                context.setFillColor(leaf)
                context.fillEllipse(in: CGRect(x: -4.2, y: -1.7, width: 8.4, height: 3.4))
                context.setStrokeColor(green)
                context.setLineWidth(0.4)
                context.move(to: CGPoint(x: -3.8, y: 0))
                context.addLine(to: CGPoint(x: 3.8, y: 0))
                context.strokePath()
                context.restoreGState()
            }
            drawLeaf(at: height * 0.12, side: -1)
            drawLeaf(at: height * 0.62, side: 1)

            // Baies d'émail cerclées d'or, au creux des boucles.
            func drawBerry(at y: CGFloat, side: CGFloat) {
                let x = stemX(y) + side * 4.4
                let rect = CGRect(x: x - 1.9, y: y - 1.9, width: 3.8, height: 3.8)
                context.setFillColor(berry)
                context.fillEllipse(in: rect)
                context.setStrokeColor(gold)
                context.setLineWidth(0.6)
                context.strokeEllipse(in: rect)
            }
            drawBerry(at: height * 0.37, side: -1)
            drawBerry(at: height * 0.87, side: 1)
        }
    }
}
