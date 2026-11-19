import SwiftUI

/// Frise tressée : deux rubans qui se croisent en passant tour à tour dessus et dessous, cerclés
/// de la teinte, terminés par un nœud rond à chaque bout. Une maille dessinée une fois par teinte,
/// répétée un nombre entier de fois et à peine étirée : la tresse remplit toute la largeur sans
/// être coupée, et ses nœuds tombent aux bords.
struct KnotBand: View {
    let tint: Color

    static let height: CGFloat = 17
    private static let tileWidth: CGFloat = 32
    private static let knot: CGFloat = 11

    var body: some View {
        GeometryReader { proxy in
            let room = max(0, proxy.size.width - Self.knot * 2)
            let count = max(1, Int((room / Self.tileWidth).rounded()))
            HStack(spacing: 0) {
                knot
                if let tile = Self.tiles.image(for: tint) {
                    ForEach(0..<count, id: \.self) { _ in
                        Image(decorative: tile, scale: 3)
                            .resizable()
                            .frame(width: room / CGFloat(count), height: Self.height)
                    }
                } else {
                    Rectangle().fill(tint).frame(width: room, height: 2)
                }
                knot
            }
        }
        .frame(height: Self.height)
        .accessibilityHidden(true)
    }

    private var knot: some View {
        Circle()
            .fill(tint)
            .overlay(Circle().fill(Color(red: 0.98, green: 0.975, blue: 0.95)).padding(3.2))
            .frame(width: Self.knot, height: Self.knot)
    }

    // MARK: Tuile

    @MainActor private static let tiles = TintedImageCache(draw: drawTile(tint:))

    /// Rubans clairs cerclés de la teinte, comme les entrelacs des manuscrits.
    /// Deux sinusoïdes opposées qui se croisent au bord et au milieu de la tuile. Le ruban B passe
    /// dessus au bord, le ruban A au milieu : chaque ruban alterne dessus, dessous.
    private static func drawTile(tint: CGColor) -> CGImage? {
        let width = tileWidth, height = Self.height
        let middle = height / 2, amplitude: CGFloat = 4.3
        let ribbonFill = CGColor(srgbRed: 0.98, green: 0.975, blue: 0.95, alpha: 1)
        return DrawnImage.make(width: width, height: height) { context in
            func ribbon(sign: CGFloat, from start: CGFloat, to end: CGFloat) {
                let path = CGMutablePath()
                let steps = 40
                for step in 0...steps {
                    let x = start + (end - start) * CGFloat(step) / CGFloat(steps)
                    let point = CGPoint(x: x, y: middle + sign * amplitude * sin(2 * .pi * x / width))
                    if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.setLineCap(.butt)
                context.addPath(path)
                context.setStrokeColor(tint)
                context.setLineWidth(5.6)
                context.strokePath()
                context.addPath(path)
                context.setStrokeColor(ribbonFill)
                context.setLineWidth(3)
                context.strokePath()
            }
            ribbon(sign: 1, from: -2, to: width + 2)
            ribbon(sign: -1, from: -2, to: width + 2)
            ribbon(sign: 1, from: width / 2 - 6, to: width / 2 + 6)
        }
    }
}

/// Triquetra : trois arcs en amande autour d'un cercle (nœud de la Trinité).
nonisolated struct Triquetra: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<3 {
            let angle = -Double.pi / 2 + Double(index) * 2 * .pi / 3
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            let normal = CGPoint(x: -direction.y, y: direction.x)
            let tip = CGPoint(x: center.x + direction.x * radius, y: center.y + direction.y * radius)
            let middle = CGPoint(x: center.x + direction.x * radius * 0.5, y: center.y + direction.y * radius * 0.5)
            let bulge = radius * 0.62
            path.move(to: center)
            path.addQuadCurve(to: tip, control: CGPoint(x: middle.x + normal.x * bulge, y: middle.y + normal.y * bulge))
            path.addQuadCurve(to: center, control: CGPoint(x: middle.x - normal.x * bulge, y: middle.y - normal.y * bulge))
        }
        let ring = radius * 0.5
        path.addEllipse(in: CGRect(x: center.x - ring, y: center.y - ring, width: ring * 2, height: ring * 2))
        return path
    }
}
