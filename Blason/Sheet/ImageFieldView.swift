import SwiftUI
import PhotosUI
import SheetKit

/// Champ image (portrait) : affichage, et choix depuis la photothèque en mode modifiable.
struct ImageFieldView: View {
    @Bindable var field: SheetField
    let editable: Bool

    @State private var selection: PhotosPickerItem?
    @Environment(\.sheetTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let data = field.imageData, let image = PlatformImage(data: data) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel(field.label.isEmpty ? "Image" : field.label)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.inputFill)
                    .frame(height: 140)
                    .overlay {
                        Image(systemName: "person.crop.square")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement()
                    .accessibilityLabel("\(field.label.isEmpty ? "Image" : field.label), aucune image")
            }
            if editable {
                HStack(spacing: 16) {
                    PhotosPicker(field.imageData == nil ? "Choisir une image" : "Changer d'image",
                                 selection: $selection, matching: .images)
                    if field.imageData != nil {
                        Button("Retirer", role: .destructive) { field.imageData = nil }
                    }
                }
                .font(.callout)
            }
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    field.imageData = Self.downscaled(data)
                }
                selection = nil
            }
        }
    }

    /// Réduit l'image (1024 px max, JPEG) pour garder la base légère.
    static func downscaled(_ data: Data) -> Data {
        ImageData.downscaled(data)
    }
}
