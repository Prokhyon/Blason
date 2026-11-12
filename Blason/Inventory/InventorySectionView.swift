import SwiftUI
import SwiftData
import SheetKit

// Besace sur la fiche (SPEC §5.13) : emplacements, objets, contenants, argent et charge.
// Interface provisoire, en attendant la refonte de l'interface (après la V2).

/// Ouvre la fiche d'un objet dans le panneau latéral (feuille sur iPhone).
struct InventoryItemOpener {
    let open: @MainActor (InventoryItem) -> Void
}

extension EnvironmentValues {
    @Entry var inventoryItemOpener: InventoryItemOpener?
}

/// Section « Besace ».
struct InventorySectionView: View {
    let section: SheetSection

    @Environment(\.sheetMode) private var mode
    @Environment(\.modelContext) private var context
    @State private var showsSettings = false

    var body: some View {
        if let inventory = section.inventory {
            VStack(alignment: .leading, spacing: 14) {
                InventorySummary(inventory: inventory)
                ForEach(inventory.sortedSlots) { slot in
                    SlotView(slot: slot, inventory: inventory)
                }
                if inventory.sortedSlots.isEmpty {
                    Text("Aucun emplacement").font(.callout).foregroundStyle(.secondary)
                }
                if mode == .fill {
                    HStack(spacing: 16) {
                        Button {
                            inventory.addSlot(name: String(localized: "Nouvel emplacement"), in: context)
                        } label: {
                            Label("Emplacement", systemImage: "plus")
                        }
                        Button {
                            showsSettings = true
                        } label: {
                            Label("Réglages de la Besace", systemImage: "slider.horizontal.3")
                        }
                        Spacer(minLength: 0)
                    }
                    .font(.callout)
                    .buttonStyle(.borderless)
                }
            }
            // En Structure, toucher la Besace sélectionne la section.
            .allowsHitTesting(mode != .structure)
            .sheet(isPresented: $showsSettings) {
                InventorySettingsView(inventory: inventory)
            }
        } else {
            Text("Besace vide").font(.callout).foregroundStyle(.secondary)
        }
    }
}

/// Fortune et charge, en tête de la Besace.
private struct InventorySummary: View {
    let inventory: Inventory

    var body: some View {
        let engine = FormulaEngine(sheet: inventory.sheet)
        let hasMoney = inventory.allItems.contains(where: \.isMoney)
        if hasMoney || inventory.tracksWeight {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { content(engine, hasMoney: hasMoney) }
                VStack(alignment: .leading, spacing: 6) { content(engine, hasMoney: hasMoney) }
            }
            .font(.callout)
        }
    }

    @ViewBuilder
    private func content(_ engine: FormulaEngine, hasMoney: Bool) -> some View {
        if hasMoney {
            Label(inventory.formattedMoney, systemImage: "dollarsign.circle")
                .monospacedDigit()
                .accessibilityLabel("Fortune : \(inventory.formattedMoney)")
        }
        if inventory.tracksWeight {
            HStack(spacing: 6) {
                Label {
                    Text(weightText(engine)).monospacedDigit()
                } icon: {
                    Image(systemName: "scalemass")
                }
                if let level = engine.level(of: inventory) {
                    Text(levelText(level))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.18), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private func weightText(_ engine: FormulaEngine) -> String {
        let carried = SheetFormat.number(inventory.carriedWeight)
        if case .success(let limit?) = engine.limit(of: inventory) {
            return "\(carried) / \(SheetFormat.number(limit)) \(inventory.weightUnit)"
        }
        return "\(carried) \(inventory.weightUnit)"
    }

    private func levelText(_ level: EncumbranceLevel) -> String {
        var parts = [level.name]
        if inventory.appliesMalus, let malus = level.malus, malus != 0 { parts.append(SheetFormat.number(malus)) }
        if !level.effect.isEmpty { parts.append(level.effect) }
        return parts.joined(separator: " · ")
    }
}

/// Emplacement : en-tête (nom, poids, capacité, ajouts) et objets.
private struct SlotView: View {
    let slot: InventorySlot
    let inventory: Inventory

    @Environment(\.sheetMode) private var mode
    @Environment(\.sheetTheme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.inventoryItemOpener) private var opener

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            let items = slot.looseItems
            if items.isEmpty {
                Text("Vide").font(.callout).foregroundStyle(.tertiary)
            }
            ForEach(items) { item in
                ItemRow(item: item, inventory: inventory, indented: false)
                if item.isContainer {
                    ForEach(item.sortedContents) { content in
                        ItemRow(item: content, inventory: inventory, indented: true)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Label(slot.name.isEmpty ? String(localized: "Sans nom") : slot.name, systemImage: slot.icon)
                .font(.subheadline.weight(.semibold))
                .sheetHeading(theme)
            if inventory.tracksWeight && !slot.countsTowardEncumbrance {
                Image(systemName: "scalemass")
                    .symbolVariant(.slash)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Ne compte pas dans la charge")
                    .accessibilityLabel("Ne compte pas dans la charge")
            }
            Spacer(minLength: 8)
            if inventory.tracksWeight {
                Text(weightText)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(slot.isOverCapacity ? Color.red : Color.secondary)
            }
            if mode == .fill {
                addMenu
            }
        }
    }

    private var weightText: String {
        let total = SheetFormat.number(slot.totalWeight)
        guard let capacity = slot.capacity else { return "\(total) \(inventory.weightUnit)" }
        return "\(total) / \(SheetFormat.number(capacity)) \(inventory.weightUnit)"
    }

    /// Ajouter un objet (par type), de l'argent ou un contenant ; la fiche de l'objet s'ouvre.
    private var addMenu: some View {
        Menu {
            Section("Objet") {
                ForEach(inventory.sortedItemTypes.filter { $0.code != "argent" }) { type in
                    Button(type.name, systemImage: type.icon) { add(type: type) }
                }
                Button("Sans type", systemImage: "shippingbox") { add(type: nil) }
            }
            Button("Contenant (sac, bourse…)", systemImage: "bag") {
                let item = add(type: inventory.itemType(code: "equipement"))
                item.setContainer(true)
            }
            if !inventory.sortedCurrencies.isEmpty {
                Section("Argent") {
                    ForEach(inventory.sortedCurrencies) { currency in
                        Button(currency.name, systemImage: "dollarsign.circle") {
                            let item = slot.addMoney(currency, amount: 0, context: context)
                            opener?.open(item)
                        }
                    }
                }
            }
        } label: {
            Label("Ajouter dans \(slot.name)", systemImage: "plus.circle")
                .labelStyle(.iconOnly)
        }
        .menuIndicator(.hidden)
        .buttonStyle(.borderless)
        .fixedSize()
    }

    @discardableResult
    private func add(type: ItemType?) -> InventoryItem {
        let item = slot.addItem(named: "", type: type, context: context)
        opener?.open(item)
        return item
    }
}

/// Ligne d'un objet : icône, nom, quantité, poids ; −/+ en Jouer ; toucher ouvre sa fiche.
private struct ItemRow: View {
    @Bindable var item: InventoryItem
    let inventory: Inventory
    let indented: Bool

    @Environment(\.sheetMode) private var mode
    @Environment(\.sheetTheme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(\.inventoryItemOpener) private var opener
    @ScaledMetric(relativeTo: .body) private var indent: CGFloat = 22

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(item.name.isEmpty ? String(localized: "Sans nom") : item.name)
                .foregroundStyle(item.name.isEmpty ? .tertiary : .primary)
                .lineLimit(1)
            if item.isEquipped {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                    .accessibilityLabel("équipé")
            }
            Spacer(minLength: 8)
            quantity
            if inventory.tracksWeight, !item.isMoney, item.totalWeight > 0 {
                Text("\(SheetFormat.number(item.totalWeight)) \(inventory.weightUnit)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, alignment: .trailing)
            }
        }
        .padding(.leading, indented ? indent : 0)
        .opacity(item.quantity == 0 ? 0.45 : 1)
        .contentShape(Rectangle())
        .onTapGesture { opener?.open(item) }
        .accessibilityAction(named: "Ouvrir la fiche de l'objet") { opener?.open(item) }
        .contextMenu { menu }
    }

    /// −/+ en Jouer pour ce qui se compte : argent, consommables, objets en plusieurs exemplaires.
    /// Le reste s'ajuste depuis la fiche de l'objet.
    private var showsAdjusters: Bool {
        guard !item.isContainer else { return false }
        return item.isMoney || item.quantity != 1 || item.type?.code == "consommable"
    }

    private var symbol: String {
        if item.isContainer { return "bag" }
        return item.type?.icon ?? "shippingbox"
    }

    @ViewBuilder
    private var quantity: some View {
        let text = item.isMoney
            ? "\(SheetFormat.number(item.quantity)) \(item.currency?.abbreviation ?? "")"
            : "×\(SheetFormat.number(item.quantity))"
        if mode == .play && showsAdjusters {
            HStack(spacing: 6) {
                Button {
                    item.adjustQuantity(by: -1)
                } label: {
                    Label("Retirer un \(item.name)", systemImage: "minus.circle").labelStyle(.iconOnly)
                }
                .disabled(item.quantity <= 0)
                Text(text)
                    .monospacedDigit()
                    .frame(minWidth: 30)
                Button {
                    item.adjustQuantity(by: 1)
                } label: {
                    Label("Ajouter un \(item.name)", systemImage: "plus.circle").labelStyle(.iconOnly)
                }
            }
            .buttonStyle(.borderless)
        } else if item.isMoney || item.quantity != 1 {
            Text(text)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var menu: some View {
        if mode != .structure {
            Button("Ouvrir", systemImage: "info.circle") { opener?.open(item) }
            if !item.isMoney {
                Button(item.isEquipped ? "Déséquiper" : "Équiper",
                       systemImage: item.isEquipped ? "xmark.circle" : "checkmark.circle") {
                    item.isEquipped.toggle()
                }
            }
            StoreInMenu(item: item, inventory: inventory)
            if mode == .fill {
                Divider()
                Button("Supprimer", systemImage: "trash", role: .destructive) {
                    context.delete(item)
                }
            }
        }
    }
}

/// « Ranger dans… » : un emplacement, ou un contenant d'un emplacement.
struct StoreInMenu: View {
    let item: InventoryItem
    let inventory: Inventory

    var body: some View {
        Menu("Ranger dans…", systemImage: "arrow.right.circle") {
            ForEach(inventory.sortedSlots) { slot in
                Button(slot.name, systemImage: slot.icon) { item.place(in: slot) }
                    .disabled(item.slot === slot && item.container == nil)
                if !item.isContainer {
                    ForEach(slot.looseItems.filter { $0.isContainer && $0 !== item }) { container in
                        Button("\(slot.name) › \(container.name)", systemImage: "bag") {
                            item.place(in: slot, container: container)
                        }
                        .disabled(item.container === container)
                    }
                }
            }
        }
    }
}
