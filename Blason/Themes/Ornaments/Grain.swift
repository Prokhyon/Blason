import SwiftUI

/// Grain d'un support (papier, vélin) : une tuile opaque dessinée une fois, points et fibres,
/// tirage reproductible. Dessinée avec Core Graphics, à 3 pixels par point, identique sur iOS et macOS.
enum Grain {
    /// Couleur sRGB, composantes de 0 à 1.
    struct RGB {
        let red, green, blue: CGFloat
    }

    static func tile(base: RGB, fleck: RGB, fibre: RGB, seed: UInt64,
                     flecks: Int = 7000, fibres: Int = 45) -> CGImage? {
        let side: CGFloat = 256
        var random = SplitMix64(seed: seed)
        func srgb(_ color: RGB, _ alpha: CGFloat = 1) -> CGColor {
            CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: alpha)
        }
        let white = RGB(red: 1, green: 1, blue: 1)
        // Tuile opaque, points mélangés au support (et non copiés : ils feraient des trous).
        return DrawnImage.make(width: side, height: side, opaque: true) { context in
            context.setFillColor(srgb(base))
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            for _ in 0..<flecks {
                let dark = Bool.random(using: &random)
                let alpha = CGFloat.random(in: 0.015...0.06, using: &random)
                context.setFillColor(dark ? srgb(fleck, alpha) : srgb(white, alpha * 1.5))
                let size = CGFloat.random(in: 0.6...1.6, using: &random)
                context.fill(CGRect(x: .random(in: 0..<side, using: &random), y: .random(in: 0..<side, using: &random),
                                    width: size, height: size))
            }
            context.setLineWidth(0.5)
            for _ in 0..<fibres {
                context.setStrokeColor(srgb(fibre, .random(in: 0.04...0.09, using: &random)))
                let start = CGPoint(x: .random(in: 0..<side, using: &random), y: .random(in: 0..<side, using: &random))
                let end = CGPoint(x: start.x + .random(in: -14...14, using: &random), y: start.y + .random(in: -14...14, using: &random))
                let control = CGPoint(x: start.x + .random(in: -8...8, using: &random), y: start.y + .random(in: -8...8, using: &random))
                context.move(to: start)
                context.addQuadCurve(to: end, control: control)
                context.strokePath()
            }
        }
    }
}

/// Fond de page tuilé à partir d'une tuile de grain, ou d'une couleur unie si elle manque.
struct GrainBackground: View {
    let tile: CGImage?
    let fallback: Color

    var body: some View {
        if let tile {
            Image(decorative: tile, scale: 3)
                .resizable(resizingMode: .tile)
        } else {
            fallback
        }
    }
}

/// Générateur reproductible : une texture est la même à chaque lancement.
struct SplitMix64: RandomNumberGenerator {
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
