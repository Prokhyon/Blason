import SwiftUI
import SwiftData
import SheetKit

/// Fiche d'un objet (SPEC §5.13, panneau latéral §5.15) : tout se modifie en Remplir ; en Jouer,
/// seuls la quantité, l'état équipé, le rangement et les propriétés vivantes.
struct ItemDetailView: View {
    @Bindable var item: InventoryItem
    let onClose: () -> Void

    @Environment(\.sheetMode) private var mode
    @Environment(\.modelContext) private var context
    @FocusState private var nameFocused: Bool

    private var canEdit: Bool { mode == .fill }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.isMoney ? "Argent" : "Objet")
                    .font(.headline)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Label("Fermer la fiche de l'objet", systemImage: "xmark")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            Divider()
            if item.isDeleted || item.modelContext == nil {
                ContentUnavailableView("Objet supprimé", systemImage: "shippingbox")
            } else {
                form
            }
        }
        .background(Color.groupedBackground)
        .task(id: item.persistentModelID) {
            // Objet tout juste créé : le curseur va dans le nom.
            guard canEdit, item.name.isEmpty, !item.isMoney else { return }
            try? await Task.sleep(for: .milliseconds(200))
            nameFocused = true
        }
    }

    private var inventory: Inventory? { item.inventory }

    private var form: some View {
        Form {
            identity
            quantitySection
            placement
            if let inventory, inventory.tracksWeight, !item.isMoney {
                weight(inventory)
            }
            if let type = item.type, !type.sortedProperties.isEmpty {
                properties(type)
            }
            if !item.isMoney {
                details
            }
            if canEdit {
                Section {
                    Button("Supprimer l'objet", systemImage: "trash", role: .destructive) {
                        let deleted = item
                        onClose()
                        context.delete(deleted)
                    }
                }
            }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var identity: some View {
        Section {
            if item.isMoney {
                Picker("Monnaie", selection: currencyBinding) {
                    ForEach(inventory?.sortedCurrencies ?? []) { currency in
                        Text(currency.name).tag(Optional(currency))
                    }
                }
                .disabled(!canEdit)
            } else {
                TextField("Nom", text: $item.name, prompt: Text("Nom de l'objet"))
                    .font(.title3.weight(.semibold))
                    .focused($nameFocused)
                    .disabled(!canEdit)
                Picker("Type", selection: typeBinding) {
                    Text("Sans type").tag(ItemType?.none)
                    ForEach(inventory?.sortedItemTypes ?? []) { type in
                        Label(type.name, systemImage: type.icon).tag(Optional(type))
                    }
                }
                .disabled(!canEdit)
            }
        }
    }

    @ViewBuilder
    private var quantitySection: some View {
        Section {
            LabeledContent(item.isMoney ? "Pièces" : "Quantité") {
                HStack(spacing: 10) {
                    Button {
                        item.adjustQuantity(by: -1)
                    } label: {
                        Label("Moins", systemImage: "minus.circle").labelStyle(.iconOnly)
                    }
                    .disabled(item.quantity <= 0)
                    NumberField(value: quantityBinding, integer: false, width: 64, accessibilityName: "Quantité")
                    Button {
                        item.adjustQuantity(by: 1)
                    } label: {
                        Label("Plus", systemImage: "plus.circle").labelStyle(.iconOnly)
                    }
                }
                .buttonStyle(.borderless)
            }
            if !item.isMoney {
                Toggle("Équipé", isOn: $item.isEquipped)
                if item.container == nil {
                    Toggle("Contenant", isOn: Binding(get: { item.isContainer }, set: { item.setContainer($0) }))
                        .disabled(!canEdit)
                }
            }
        } footer: {
            if item.isContainer {
                Text("Un contenant reçoit d'autres objets (« Ranger dans… »), mais pas d'autre contenant.")
            }
        }
    }

    @ViewBuilder
    private var placement: some View {
        if let inventory {
            Section("Rangement") {
                Picker("Emplacement", selection: slotBinding) {
                    ForEach(inventory.sortedSlots) { slot in
                        Label(slot.name, systemImage: slot.icon).tag(Optional(slot))
                    }
                }
                if !item.isContainer, let slot = item.slot {
                    let containers = slot.looseItems.filter { $0.isContainer && $0 !== item }
                    if !containers.isEmpty {
                        Picker("Dans", selection: containerBinding) {
                            Text("Directement").tag(InventoryItem?.none)
                            ForEach(containers) { container in
                                Text(container.name).tag(Optional(container))
                            }
                        }
                    }
                }
            }
        }
    }

    private func weight(_ inventory: Inventory) -> some View {
        Section("Poids") {
            LabeledContent("Poids unitaire") {
                HStack(spacing: 4) {
                    NumberField(value: $item.unitWeight, integer: false, prompt: "0", width: 64, accessibilityName: "Poids unitaire")
                    Text(inventory.weightUnit).foregroundStyle(.secondary)
                }
            }
            .disabled(!canEdit)
            if item.quantity != 1 || item.isContainer {
                LabeledContent("Poids total", value: "\(SheetFormat.number(item.totalWeight)) \(inventory.weightUnit)")
            }
        }
    }

    private func properties(_ type: ItemType) -> some View {
        let engine = FormulaEngine(sheet: item.sheet)
        return Section(type.name) {
            ForEach(type.sortedProperties) { property in
                LabeledContent(property.label.isEmpty ? property.code : property.label) {
                    ItemPropertyEditor(item: item, property: property, engine: engine, width: 90)
                }
            }
        }
    }

    @ViewBuilder
    private var details: some View {
        Section("Valeur") {
            TextField("Valeur", text: $item.price, prompt: Text("ex. 25 po"))
                .disabled(!canEdit)
        }
        Section("Description") {
            TextField("Description", text: $item.summary, prompt: Text("Apparence, effets, histoire…"), axis: .vertical)
                .lineLimit(2...8)
                .disabled(!canEdit)
        }
        Section("Notes") {
            TextField("Notes", text: $item.notes, prompt: Text("Notes de partie"), axis: .vertical)
                .lineLimit(2...8)
        }
    }

    // MARK: Liaisons

    private var typeBinding: Binding<ItemType?> {
        Binding(get: { item.type }, set: { item.changeType(to: $0, in: context) })
    }

    private var currencyBinding: Binding<Currency?> {
        Binding(get: { item.currency }, set: { currency in
            item.currency = currency
            if let currency { item.name = currency.name }
        })
    }

    private var quantityBinding: Binding<Double?> {
        Binding(get: { item.quantity }, set: { item.quantity = max(0, $0 ?? 0) })
    }

    private var slotBinding: Binding<InventorySlot?> {
        Binding(get: { item.slot }, set: { if let slot = $0 { item.place(in: slot) } })
    }

    private var containerBinding: Binding<InventoryItem?> {
        Binding(get: { item.container }, set: { container in
            if let slot = item.slot { item.place(in: slot, container: container) }
        })
    }
}

/// Saisie d'une propriété d'objet, selon son genre : valeur propre de l'objet, défaut du type en invite.
struct ItemPropertyEditor: View {
    let item: InventoryItem
    let property: ItemProperty
    let engine: FormulaEngine
    var width: CGFloat = 60

    @Environment(\.sheetMode) private var mode
    @Environment(\.modelContext) private var context

    private var editable: Bool {
        property.kind != .formula && mode.canEdit(live: property.isLive)
    }

    private var value: ItemPropertyValue? { item.value(for: property) }

    var body: some View {
        switch property.kind {
        case .text:
            if editable {
                TextField("", text: Binding(
                    get: { value?.textValue ?? "" },
                    set: { item.editableValue(for: property, in: context).textValue = $0.isEmpty ? nil : $0 }
                ), prompt: property.textValue.map(Text.init))
                .multilineTextAlignment(.trailing)
                .frame(minWidth: width)
                .inputBackground()
                .accessibilityLabel(accessibilityName)
            } else {
                ValueText(value?.textValue ?? property.textValue)
            }
        case .number, .percentage:
            if editable {
                NumberField(value: Binding(
                    get: { value?.numberValue },
                    set: { item.editableValue(for: property, in: context).numberValue = $0 }
                ), integer: false, prompt: value?.numberValue == nil ? engine.content(of: item, property).promptText : nil,
                    width: width * 0.7, accessibilityName: accessibilityName)
            } else {
                ComputedValueText(result: engine.content(of: item, property))
            }
        case .checkbox:
            CheckboxButton(isOn: Binding(
                get: { (value?.boolValue ?? property.boolValue) == true },
                set: { item.editableValue(for: property, in: context).boolValue = $0 }
            ), enabled: editable, accessibilityName: accessibilityName)
        case .formula:
            ComputedValueText(result: engine.content(of: item, property))
        }
    }

    private var accessibilityName: String {
        [item.name, property.label].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}
