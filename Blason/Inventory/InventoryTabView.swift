import SwiftUI
import SwiftData
import SheetKit

/// Onglet Inventaire : la Besace de la fiche, en pleine page (SPEC §5.13, §5.17). Sa section reste
/// dans le modèle (code `BESACE` des formules, vues des objets équipés), mais n'est plus dessinée
/// sur la fiche. Sous les onglets, la rangée des emplacements (elle suit le défilement ; un toucher
/// y mène) et, à droite, fortune et charge.
struct InventoryTabView: View {
    let sheet: Sheet?
    /// Réglages de la Besace, ouverts depuis le menu « … » de la barre.
    @Binding var showsSettings: Bool

    @Environment(\.sheetMode) private var mode
    @Environment(\.structureEditor) private var editor
    @Environment(\.modelContext) private var context
    /// Position des emplacements dans le contenu.
    @State private var slotFrames: [PersistentIdentifier: CGRect] = [:]
    /// Défilement depuis le haut du contenu.
    @State private var scrolled: CGFloat = 0
    /// Emplacement choisi dans la rangée, le temps que le défilement l'amène en haut.
    @State private var target: PersistentIdentifier?

    var body: some View {
        Group {
            if let section = sheet?.inventory?.section, let inventory = section.inventory {
                ScrollViewReader { proxy in
                    ScrollView {
                        InventoryBoard(section: section) { id, frame in slotFrames[id] = frame }
                            .frame(maxWidth: 1100)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                    }
                    .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, offset in
                        scrolled = offset
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onScrollPhaseChange { _, phase in
                        if phase == .interacting { target = nil }
                    }
                    .safeAreaBar(edge: .top, spacing: 0) {
                        bar(inventory) { id in
                            target = id
                            withAnimation(.snappy) { proxy.scrollTo(id, anchor: .top) }
                        }
                    }
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

    private func bar(_ inventory: Inventory, select: @escaping (PersistentIdentifier) -> Void) -> some View {
        let slots = inventory.sortedSlots
        return HStack(spacing: 12) {
            if slots.count > 1 {
                SecondaryRow(
                    items: slots.map { .init(id: $0.persistentModelID, title: $0.name.isEmpty ? String(localized: "Sans nom") : $0.name) },
                    selection: target ?? currentSlot(slots),
                    select: select
                )
            } else {
                Spacer(minLength: 0)
            }
            InventorySummary(inventory: inventory, pills: true)
                .fixedSize()
        }
        .padding(.trailing)
        .padding(.vertical, 4)
    }

    /// Emplacement en haut de l'écran : le dernier dont le haut est passé sous la rangée (à hauteur
    /// égale, le premier dans l'ordre) ; le premier tant qu'on n'a pas défilé.
    private func currentSlot(_ slots: [InventorySlot]) -> PersistentIdentifier? {
        let passed = slots.filter { (slotFrames[$0.persistentModelID]?.minY ?? .infinity) <= scrolled + 24 }
        let top = passed.max { lhs, rhs in
            (slotFrames[lhs.persistentModelID]?.minY ?? 0) < (slotFrames[rhs.persistentModelID]?.minY ?? 0)
        }
        return (top ?? slots.first)?.persistentModelID
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
