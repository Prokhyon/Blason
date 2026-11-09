import SwiftUI
import PhotosUI
import SheetKit

/// Champ image (portrait) : affichage, et choix depuis la photothèque en mode modifiable.
struct ImageFieldView: View {
    @Bindable var field: SheetField
    let editable: Bool

    @State private var selection: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let data = field.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 140)
                    .overlay {
                        Image(systemName: "person.crop.square")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
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
        guard let image = UIImage(data: data),
              let thumbnail = image.preparingThumbnail(of: fittingSize(image.size, maxSide: 1024)),
              let jpeg = thumbnail.jpegData(compressionQuality: 0.85) else { return data }
        return jpeg
    }

    private static func fittingSize(_ size: CGSize, maxSide: CGFloat) -> CGSize {
        let scale = min(1, maxSide / max(size.width, size.height, 1))
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}
