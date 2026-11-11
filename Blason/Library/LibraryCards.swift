import SwiftUI
import SheetKit

/// Carte d'un personnage : portrait (ou initiales), nom, template d'origine, dernière modification.
/// Hauteur fixe : le nom a toujours la place de deux lignes, puis il est coupé.
struct CharacterCard: View {
    let character: PlayerCharacter

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            portrait
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(character.displayName)
                    .font(.headline)
                    .lineLimit(2, reservesSpace: true)
                Text(character.sourceTemplateName.isEmpty ? "Fiche libre" : character.sourceTemplateName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("Modifié \(character.updatedAt, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var portrait: some View {
        if let data = character.portraitData, let image = PlatformImage(data: data) {
            Image(platformImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.accentColor.opacity(0.12)
                Text(initials)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var initials: String {
        let words = character.displayName.split(separator: " ").prefix(2)
        return words.compactMap(\.first).map(String.init).joined().uppercased()
    }
}

/// Carte d'un template : nom, système, nombre de personnages créés.
/// Hauteur fixe : deux lignes pour le nom, une pour le système (même vide), puis coupé.
struct TemplateCard: View {
    let template: SheetTemplate
    let characterCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Color.tertiaryFill
                Image(systemName: "doc.text")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.headline)
                    .lineLimit(2, reservesSpace: true)
                // Ligne gardée même sans système : toutes les cartes ont la même hauteur.
                Text(template.system)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1, reservesSpace: true)
                Text(characterCount == 0 ? "Aucun personnage"
                     : characterCount == 1 ? "1 personnage" : "\(characterCount) personnages")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.secondaryGroupedBackground, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

/// Colonnes des grilles de la bibliothèque : deux cartes par ligne sur iPhone, plus larges sur iPad.
enum LibraryGridLayout {
    static func columns(for sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        let minimum: CGFloat = sizeClass == .compact ? 150 : 200
        return [GridItem(.adaptive(minimum: minimum, maximum: 280), spacing: 16)]
    }
}
