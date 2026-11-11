import SwiftUI
import SwiftData
import SheetKit

/// Choix du thème et de sa couleur, dans le menu « Affichage » de la fiche.
/// Un template choisit pour lui et ses personnages ; un personnage suit son template
/// (« Comme le template ») ou choisit le sien.
struct ThemeMenu: View {
    let sheet: Sheet

    @Environment(\.modelContext) private var context

    var body: some View {
        let effective = sheet.appearance(in: context)
        Picker(selection: themeSelection) {
            if isCharacter {
                Label("Comme le template", systemImage: "arrow.turn.up.left").tag(String?.none)
            }
            ForEach(SheetThemes.all) { theme in
                Label(theme.name, systemImage: theme.symbol).tag(Optional(theme.id))
            }
        } label: {
            Label("Thème", systemImage: "paintbrush")
        }
        .pickerStyle(.menu)

        if SheetThemes.descriptor(effective.themeID)?.usesColor == true {
            Picker(selection: colorSelection) {
                ForEach(ThemePalette.all) { color in
                    Label { Text(color.name) } icon: { ThemePalette.swatch(color.color) }
                        .tag(color.id)
                }
            } label: {
                Label("Couleur", systemImage: "paintpalette")
            }
            .pickerStyle(.menu)
        }
    }

    private var isCharacter: Bool { sheet.character != nil }

    /// nil : comme le template (personnage) ; un template sans choix affiche le thème natif.
    private var themeSelection: Binding<String?> {
        Binding(
            get: { isCharacter ? sheet.themeID : (sheet.themeID ?? SheetAppearance.defaultThemeID) },
            set: { id in
                if let id {
                    sheet.ownAppearance = SheetAppearance(themeID: id, colorID: sheet.appearance(in: context).colorID)
                } else {
                    sheet.ownAppearance = nil
                }
            }
        )
    }

    /// Changer la couleur d'un personnage qui suit son template lui donne sa propre apparence.
    private var colorSelection: Binding<String> {
        Binding(
            get: { sheet.appearance(in: context).colorID },
            set: { colorID in
                sheet.ownAppearance = SheetAppearance(themeID: sheet.appearance(in: context).themeID, colorID: colorID)
            }
        )
    }
}
