import SwiftUI
import SwiftData
import SheetKit

/// Onglet Inventaire : la Besace de la fiche, en pleine page (SPEC §5.13, §5.17). Sa section reste
/// dans le modèle (code `BESACE` des formules, vues des objets équipés), mais n'est plus dessinée
/// sur la fiche. Sous les onglets, à droite, fortune et charge.
struct InventoryTabView: View {
    let sheet: Sheet?
    /// Réglages de la Besace, ouverts depuis le menu « … » de la barre.
    @Binding var showsSettings: Bool

    @Environment(\.sheetMode) private var mode
    @Environment(\.structureEditor) private var editor
    @Environment(\.modelContext) private var context

    var body: some View {
        Group {
            if let section = sheet?.inventory?.section, let inventory = section.inventory {
                ScrollView {
                    InventoryBoard(section: section)
                        .frame(maxWidth: 1100)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaBar(edge: .top, spacing: 0) {
                    InventorySummary(inventory: inventory, pills: true)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }
                .task(id: mode) { selectInStructure(section) }
                .sheet(isPresented: $showsSettings) {
                    InventorySettingsView(inventory: inventory)
                }
            } else {
                ContentUnavailableView {
                    Label("Pas de Besace", systemImage: "backpack")
                } description: {
                    Text("Objets, argent, emplacements et contenants ; poids et encombrement en option.")
                } actions: {
                    Button("Créer la Besace") {
                        guard let sheet else { return }
                        let inventory = sheet.ensureInventory(in: context)
                        if let section = inventory.section { selectInStructure(section) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .background(SheetBackground())
    }

    /// En Structure, la Besace est sélectionnée : ses réglages s'ouvrent dans l'inspecteur.
    private func selectInStructure(_ section: SheetSection) {
        guard mode == .structure, let editor, editor.primary != .section(section) else { return }
        editor.select(.section(section))
    }
}

/// Fond de page du thème de la fiche.
private struct SheetBackground: View {
    @Environment(\.sheetTheme) private var theme

    var body: some View {
        theme.pageBackground().ignoresSafeArea()
    }
}
