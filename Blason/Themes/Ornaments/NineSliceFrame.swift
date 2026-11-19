import SwiftUI

/// Cadre en 9 parties : une image dessinée une fois, dont les coins restent fixes et les bords
/// s'étirent. Il tient à toutes les tailles de section, de l'iPhone au Mac.
struct NineSliceFrame: View {
    /// Image du cadre, à 3 pixels par point (`DrawnImage`).
    let image: CGImage?
    /// Taille des coins fixes, en points, sur chaque bord.
    let corner: CGFloat

    var body: some View {
        if let image {
            Image(decorative: image, scale: 3)
                .resizable(capInsets: EdgeInsets(top: corner, leading: corner, bottom: corner, trailing: corner),
                           resizingMode: .stretch)
                .accessibilityHidden(true)
        }
    }
}
