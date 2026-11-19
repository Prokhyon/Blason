import SwiftUI

/// Émaux et métaux des thèmes héraldiques (Enluminure, Armorial), aux couleurs des icônes de l'app
/// (`Design/Blason/make.py`).
enum Heraldry {
    /// Les émaux, en version foncée : lisibles en texte sur un fond clair. Les métaux (or, argent) ne
    /// s'écrivent pas sur le fond : l'or est réservé aux ornements.
    static let tinctures: [ThemeColor] = [
        ThemeColor(id: "gueules", name: "Gueules", color: Color(red: 0.64, green: 0.18, blue: 0.18)),   // #A32D2D
        ThemeColor(id: "azur", name: "Azur", color: Color(red: 0.09, green: 0.37, blue: 0.65)),        // #185FA5
        ThemeColor(id: "sinople", name: "Sinople", color: Color(red: 0.23, green: 0.43, blue: 0.07)),  // #3B6D11
        ThemeColor(id: "pourpre", name: "Pourpre", color: Color(red: 0.33, green: 0.29, blue: 0.72)),  // #534AB7
        ThemeColor(id: "sable", name: "Sable", color: Color(red: 0.17, green: 0.17, blue: 0.16)),      // #2C2C2A
    ]
}

/// Or des ornements.
enum Gilding {
    static let light = Color(red: 0.98, green: 0.78, blue: 0.46)    // #FAC775, or des icônes
    static let shade = Color(red: 0.73, green: 0.46, blue: 0.09)    // #BA7517
    static let shadeCG = CGColor(srgbRed: 0.73, green: 0.46, blue: 0.09, alpha: 1)
}

/// Images d'ornement dessinées une fois par couleur (un émail), puis gardées.
@MainActor
final class TintedImageCache {
    private var images: [Color.Resolved: CGImage] = [:]
    private let draw: @MainActor (CGColor) -> CGImage?

    init(draw: @escaping @MainActor (CGColor) -> CGImage?) {
        self.draw = draw
    }

    func image(for tint: Color) -> CGImage? {
        let key = tint.resolve(in: EnvironmentValues())
        if let image = images[key] { return image }
        let image = draw(key.cgColor)
        images[key] = image
        return image
    }
}
