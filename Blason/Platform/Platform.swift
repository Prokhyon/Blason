import SwiftUI
import ImageIO
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

// Ce qui diffère entre iOS / iPadOS et macOS, réuni ici : les vues n'utilisent ni UIKit ni AppKit.

#if canImport(UIKit)
typealias PlatformImage = UIImage
#else
typealias PlatformImage = NSImage
#endif

extension Image {
    /// Image décodée par le système (portrait, champ image).
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
        self.init(uiImage: platformImage)
        #else
        self.init(nsImage: platformImage)
        #endif
    }
}

// MARK: - Couleurs du système

extension Color {
    /// Fond de la bibliothèque, de l'inspecteur et des pages.
    static let groupedBackground: Color = {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }()

    /// Fond des cartes et des sections, posées sur `groupedBackground`.
    static let secondaryGroupedBackground: Color = {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color(nsColor: .controlBackgroundColor)
        #endif
    }()

    /// Remplissage discret (zones de saisie, pastilles).
    static let tertiaryFill: Color = {
        #if canImport(UIKit)
        Color(uiColor: .tertiarySystemFill)
        #else
        Color(nsColor: .tertiarySystemFill)
        #endif
    }()
}

// MARK: - Images dessinées par le code

enum DrawnImage {
    /// Image dessinée avec Core Graphics (identique sur iOS et macOS), en points ; `scale` pixels par point.
    /// L'origine est en bas à gauche.
    static func make(width: CGFloat, height: CGFloat, scale: CGFloat = 3, opaque: Bool = false,
                     draw: (CGContext) -> Void) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8, bytesPerRow: 0,
                space: space,
                bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : CGImageAlphaInfo.premultipliedLast).rawValue)
        else { return nil }
        context.scaleBy(x: scale, y: scale)
        draw(context)
        return context.makeImage()
    }
}

// MARK: - Images importées

nonisolated enum ImageData {
    /// Réduit une image (côté le plus long : `maxSide` pixels, JPEG) pour garder la base légère.
    /// Tient compte de l'orientation des photos. Renvoie les données d'origine si elles ne se lisent pas.
    static func downscaled(_ data: Data, maxSide: Int = 1024) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return data }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return data }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return data }
        CGImageDestinationAddImage(destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : data
    }
}

// MARK: - Modificateurs propres à iOS (sans effet sur Mac)

/// Mise en majuscules automatique d'un champ de texte (clavier virtuel).
enum TextCapitalization {
    case never
    case characters
}

extension View {
    /// Titre de navigation en petit, dans la barre.
    func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Masque la barre d'onglets (fiche ouverte sur iPhone).
    func hidesTabBar() -> some View {
        #if os(iOS)
        toolbar(.hidden, for: .tabBar)
        #else
        self
        #endif
    }

    func textCapitalization(_ capitalization: TextCapitalization) -> some View {
        #if os(iOS)
        textInputAutocapitalization(capitalization == .never ? .never : .characters)
        #else
        self
        #endif
    }

    /// Clavier numérique (entier ou décimal).
    func numericKeyboard(integer: Bool) -> some View {
        #if os(iOS)
        keyboardType(integer ? .numberPad : .decimalPad)
        #else
        self
        #endif
    }
}

#if os(macOS)
// Sur Mac, une fenêtre se redimensionne mais ne passe jamais en disposition « iPhone » :
// la largeur est toujours « normale ».
enum UserInterfaceSizeClass {
    case compact
    case regular
}

extension EnvironmentValues {
    var horizontalSizeClass: UserInterfaceSizeClass? { .regular }
}
#endif
