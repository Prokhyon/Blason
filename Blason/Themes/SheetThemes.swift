import SwiftUI
import SheetKit

/// Un thème proposé dans le menu « Affichage ».
struct SheetThemeDescriptor: Identifiable {
    /// Identifiant enregistré dans la fiche (et dans les fichiers exportés) : ne jamais le changer.
    let id: String
    let name: LocalizedStringKey
    let symbol: String
    /// Le thème se teinte de la couleur choisie dans sa palette.
    let usesColor: Bool
    /// Couleurs proposées : celles du système, ou celles du thème (les émaux de l'enluminure).
    var palette: [ThemeColor] = ThemePalette.all
    let make: @MainActor (Color) -> SheetTheme

    /// Couleur d'un identifiant ; un identifiant d'une autre palette donne la première couleur.
    func color(_ id: String) -> ThemeColor {
        palette.first { $0.id == id } ?? palette[0]
    }
}

/// Thèmes disponibles. **Ajouter un thème** : écrire `static func monTheme(…) -> SheetTheme`
/// dans son propre fichier (en partant de `SheetTheme()`), puis l'inscrire ici. Pistes à venir :
/// `Design/Themes/README.md`.
enum SheetThemes {
    static let all: [SheetThemeDescriptor] = [
        SheetThemeDescriptor(id: "native", name: "Natif", symbol: "ipad", usesColor: false) { _ in .native },
        SheetThemeDescriptor(id: "templateColor", name: "Couleur du template", symbol: "paintpalette",
                             usesColor: true, make: SheetTheme.templateColor),
        SheetThemeDescriptor(id: "paper", name: "Fiche papier", symbol: "doc.plaintext", usesColor: false) { _ in .paper },
        SheetThemeDescriptor(id: "illuminated", name: "Enluminure", symbol: "scroll", usesColor: true,
                             palette: IlluminatedTheme.tinctures, make: SheetTheme.illuminated),
    ]

    /// Thème d'une apparence ; un identifiant inconnu (version plus récente) donne le thème natif.
    static func theme(for appearance: SheetAppearance) -> SheetTheme {
        let descriptor = all.first { $0.id == appearance.themeID } ?? all[0]
        var theme = descriptor.make(descriptor.color(appearance.colorID).color)
        theme.identity = appearance
        return theme
    }

    static func descriptor(_ id: String) -> SheetThemeDescriptor? {
        all.first { $0.id == id }
    }
}

/// Une couleur de la palette.
struct ThemeColor: Identifiable {
    /// Identifiant enregistré dans la fiche : ne jamais le changer.
    let id: String
    let name: LocalizedStringKey
    let color: Color
}

/// Couleurs proposées pour teinter une fiche : celles du système, qui s'ajustent en clair, en sombre
/// et en contraste élevé (le jaune et le vert menthe, peu lisibles en texte sur fond clair, n'y sont pas).
enum ThemePalette {
    static let all: [ThemeColor] = [
        ThemeColor(id: "blue", name: "Bleu", color: .blue),
        ThemeColor(id: "indigo", name: "Indigo", color: .indigo),
        ThemeColor(id: "purple", name: "Violet", color: .purple),
        ThemeColor(id: "pink", name: "Rose", color: .pink),
        ThemeColor(id: "red", name: "Rouge", color: .red),
        ThemeColor(id: "orange", name: "Orange", color: .orange),
        ThemeColor(id: "green", name: "Vert", color: .green),
        ThemeColor(id: "teal", name: "Sarcelle", color: .teal),
        ThemeColor(id: "brown", name: "Brun", color: .brown),
        ThemeColor(id: "gray", name: "Graphite", color: .gray),
    ]

    /// Pastille de couleur pour un menu (les menus affichent les images en une seule teinte, sauf celles-ci).
    static func swatch(_ color: Color) -> Image {
        let side: CGFloat = 18
        let fill = color.resolve(in: EnvironmentValues()).cgColor
        guard let image = DrawnImage.make(width: side, height: side, draw: { context in
            context.setFillColor(fill)
            context.fillEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
        }) else { return Image(systemName: "circle.fill") }
        return Image(decorative: image, scale: 3).renderingMode(.original)
    }
}
