import SwiftUI
import SwiftData
import SheetKit

/// Réglages d'une Besace : code, poids et encombrement, paliers, monnaies, types d'objets
/// et leurs propriétés, emplacements. Ouverts depuis la Besace (Remplir) ou l'inspecteur (Structure).
struct InventorySettingsView: View {
    @Bindable var inventory: Inventory

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                weightSection
                if inventory.tracksWeight {
                    levelsSection
                }
                currenciesSection
                typesSection
                slotsSection
                Section {
                    TextField("Code", text: $inventory.code, prompt: Text("BESACE"))
                        .font(.body.monospaced())
                        .textCapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Code dans les formules")
                } footer: {
                    Text("\(code).poids, \(code).limite, \(code).malus (palier atteint), \(code).argent (fortune dans la plus petite monnaie).")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Réglages de la Besace")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
                #if os(iOS)
                // Poignées pour changer l'ordre des monnaies, types et emplacements.
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                #endif
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .level(let level): LevelEditor(level: level, inventory: inventory)
                case .currency(let currency): CurrencyEditor(currency: currency)
                case .type(let type): ItemTypeEditor(type: type)
                case .property(let property): PropertyEditor(property: property)
                case .slot(let slot): SlotEditor(slot: slot, inventory: inventory)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 560)
        #endif
    }

    private var code: String { inventory.code.isEmpty ? "BESACE" : inventory.code }

    private var weightSection: some View {
        Section {
            Toggle("Poids et encombrement", isOn: $inventory.tracksWeight)
            if inventory.tracksWeight {
                LabeledContent("Unité") {
                    TextField("Unité", text: $inventory.weightUnit, prompt: Text("kg"))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Charge maximale") {
                    TextField("Charge maximale", text: optional($inventory.weightLimitFormula), prompt: Text("=FOR*2"))
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .textCapitalization(.never)
                }
                if case .success(let limit?) = FormulaEngine(sheet: inventory.sheet).limit(of: inventory) {
                    LabeledContent("Soit", value: "\(SheetFormat.number(limit)) \(inventory.weightUnit)")
                }
            }
        } footer: {
            Text(inventory.tracksWeight
                 ? "Le poids porté additionne les emplacements qui comptent dans la charge. L'argent ne pèse rien."
                 : "Sans poids ni encombrement, aucun poids n'est affiché.")
        }
    }

    private var levelsSection: some View {
        Section {
            Toggle("Les paliers appliquent un malus", isOn: $inventory.appliesMalus)
            ForEach(inventory.sortedLevels) { level in
                NavigationLink(value: SettingsRoute.level(level)) {
                    LabeledContent(level.name.isEmpty ? String(localized: "Sans nom") : level.name,
                                   value: level.thresholdFormula ?? "—")
                }
            }
            Button("Ajouter un palier", systemImage: "plus") {
                let level = inventory.addLevel(name: String(localized: "Chargé"), threshold: "=\(code).limite", in: context)
                level.malus = inventory.appliesMalus ? -10 : nil
            }
        } header: {
            Text("Paliers d'encombrement")
        } footer: {
            Text("Un palier est atteint quand le poids porté dépasse son seuil. Son malus est \(code).malus, à utiliser dans les formules concernées (=DEX*5+\(code).malus).")
        }
    }

    private var currenciesSection: some View {
        Section {
            ForEach(inventory.sortedCurrencies) { currency in
                NavigationLink(value: SettingsRoute.currency(currency)) {
                    LabeledContent(currency.name, value: "\(currency.abbreviation) · \(SheetFormat.number(currency.rate))")
                }
            }
            .onMove { InventoryOrder.move(inventory.sortedCurrencies, fromOffsets: $0, toOffset: $1) }
            Button("Ajouter une monnaie", systemImage: "plus") {
                inventory.addCurrency(name: String(localized: "Nouvelle monnaie"), abbreviation: "", rate: 1, in: context)
            }
        } header: {
            Text("Monnaies")
        } footer: {
            Text("La valeur est relative à la plus petite monnaie (cuivre = 1, argent = 10, or = 100). La fortune s'affiche convertie, sans changer les pièces.")
        }
    }

    private var typesSection: some View {
        Section("Types d'objets") {
            ForEach(inventory.sortedItemTypes) { type in
                NavigationLink(value: SettingsRoute.type(type)) {
                    Label {
                        LabeledContent(type.name, value: propertiesSummary(type))
                    } icon: {
                        Image(systemName: type.icon)
                    }
                }
            }
            .onMove { InventoryOrder.move(inventory.sortedItemTypes, fromOffsets: $0, toOffset: $1) }
            Button("Ajouter un type", systemImage: "plus") {
                inventory.addItemType(name: String(localized: "Nouveau type"), in: context)
            }
        }
    }

    private var slotsSection: some View {
        Section("Emplacements") {
            ForEach(inventory.sortedSlots) { slot in
                NavigationLink(value: SettingsRoute.slot(slot)) {
                    Label(slot.name, systemImage: slot.icon)
                }
            }
            .onMove { InventoryOrder.move(inventory.sortedSlots, fromOffsets: $0, toOffset: $1) }
            Button("Ajouter un emplacement", systemImage: "plus") {
                inventory.addSlot(name: String(localized: "Nouvel emplacement"), in: context)
            }
        }
    }

    private func propertiesSummary(_ type: ItemType) -> String {
        type.sortedProperties.map { $0.label.isEmpty ? $0.code : $0.label }.joined(separator: ", ")
    }
}

private enum SettingsRoute: Hashable {
    case level(EncumbranceLevel)
    case currency(Currency)
    case type(ItemType)
    case property(ItemProperty)
    case slot(InventorySlot)
}

/// Liaison texte vers une propriété optionnelle (vide ↔ nil).
private func optional(_ binding: Binding<String?>) -> Binding<String> {
    Binding(get: { binding.wrappedValue ?? "" }, set: { binding.wrappedValue = $0.isEmpty ? nil : $0 })
}

/// Monter / descendre l'élément dans sa liste.
private struct OrderSection<Item: InventoryOrdered>: View {
    let item: Item
    let sorted: [Item]

    var body: some View {
        Section {
            HStack {
                Button("Monter", systemImage: "arrow.up") { InventoryOrder.move(item, by: -1, in: sorted) }
                    .disabled(!InventoryOrder.canMove(item, by: -1, in: sorted))
                Spacer()
                Button("Descendre", systemImage: "arrow.down") { InventoryOrder.move(item, by: 1, in: sorted) }
                    .disabled(!InventoryOrder.canMove(item, by: 1, in: sorted))
            }
            .buttonStyle(.borderless)
        } header: {
            Text("Position dans la liste")
        }
    }
}

/// Bouton « Supprimer » d'un éditeur : supprime puis revient à la liste.
private struct DeleteSection: View {
    let title: LocalizedStringKey
    var message: LocalizedStringKey?
    let action: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirming = false

    var body: some View {
        Section {
            Button(title, systemImage: "trash", role: .destructive) {
                if message == nil { remove() } else { confirming = true }
            }
            .confirmationDialog(title, isPresented: $confirming, titleVisibility: .visible) {
                Button(title, role: .destructive) { remove() }
            } message: {
                if let message { Text(message) }
            }
        }
    }

    private func remove() {
        dismiss()
        action()
    }
}

// MARK: - Éditeurs

private struct LevelEditor: View {
    @Bindable var level: EncumbranceLevel
    let inventory: Inventory
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                TextField("Nom", text: $level.name, prompt: Text("Chargé"))
                LabeledContent("Seuil") {
                    TextField("Seuil", text: optional($level.thresholdFormula), prompt: Text("=BESACE.limite"))
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .textCapitalization(.never)
                }
                if case .success(let value?) = FormulaEngine(sheet: inventory.sheet).threshold(of: level) {
                    LabeledContent("Soit", value: "\(SheetFormat.number(value)) \(inventory.weightUnit)")
                }
            } footer: {
                Text("Atteint quand le poids porté dépasse le seuil.")
            }
            Section {
                if inventory.appliesMalus {
                    LabeledContent("Malus") {
                        NumberField(value: $level.malus, integer: false, prompt: "0", width: 70, accessibilityName: "Malus")
                    }
                }
                TextField("Effet", text: $level.effect, prompt: Text("ex. Mouvement −2"), axis: .vertical)
            }
            DeleteSection(title: "Supprimer le palier") { context.delete(level) }
        }
        .formStyle(.grouped)
        .navigationTitle(level.name.isEmpty ? String(localized: "Palier") : level.name)
    }
}

private struct CurrencyEditor: View {
    @Bindable var currency: Currency
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                TextField("Nom", text: $currency.name, prompt: Text("Pièce d'or"))
                LabeledContent("Abréviation") {
                    TextField("Abréviation", text: $currency.abbreviation, prompt: Text("po"))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Valeur") {
                    NumberField(value: Binding(get: { currency.rate }, set: { currency.rate = max(0, $0 ?? 1) }),
                                integer: false, width: 80, accessibilityName: "Valeur")
                }
            } footer: {
                Text("En pièces de la plus petite monnaie.")
            }
            if let inventory = currency.inventory {
                OrderSection(item: currency, sorted: inventory.sortedCurrencies)
            }
            DeleteSection(title: "Supprimer la monnaie",
                          message: "Les compteurs de cette monnaie restent dans la Besace, comme des objets ordinaires.") {
                context.delete(currency)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(currency.name)
    }
}

private struct ItemTypeEditor: View {
    @Bindable var type: ItemType
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                TextField("Nom", text: $type.name, prompt: Text("Arme"))
                LabeledContent("Code") {
                    TextField("Code", text: $type.code, prompt: Text("arme"))
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .textCapitalization(.never)
                }
                IconPicker(selection: $type.icon)
            } footer: {
                Text("Le code sert aux vues de la Besace (objets équipés de ce type).")
            }
            Section {
                ForEach(type.sortedProperties) { property in
                    NavigationLink(value: SettingsRoute.property(property)) {
                        Label {
                            LabeledContent(property.label.isEmpty ? String(localized: "Sans nom") : property.label,
                                           value: property.code)
                        } icon: {
                            Image(systemName: property.kind.symbol)
                        }
                    }
                }
                Menu {
                    ForEach(ColumnKind.allCases, id: \.self) { kind in
                        Button {
                            type.addProperty(label: "", kind: kind, code: "", in: context)
                        } label: {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                    }
                } label: {
                    Label("Ajouter une propriété", systemImage: "plus")
                }
            } header: {
                Text("Propriétés")
            } footer: {
                Text("Comme les colonnes d'un tableau : chaque objet du type a sa valeur. Dans une formule de propriété, une autre propriété se désigne par son code (=pct/2), la quantité par « quantite ».")
            }
            if let inventory = type.inventory {
                OrderSection(item: type, sorted: inventory.sortedItemTypes)
            }
            DeleteSection(title: "Supprimer le type",
                          message: "Les objets de ce type restent dans la Besace, sans type.") {
                context.delete(type)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(type.name)
    }
}

private struct PropertyEditor: View {
    @Bindable var property: ItemProperty
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                TextField("Libellé", text: $property.label, prompt: Text("Dégâts"))
                LabeledContent("Code") {
                    TextField("Code", text: $property.code, prompt: Text("degats"))
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .textCapitalization(.never)
                }
                Picker("Genre", selection: Binding(get: { property.kind }, set: { property.kind = $0 })) {
                    ForEach(ColumnKind.allCases, id: \.self) { kind in
                        Label(kind.title, systemImage: kind.symbol).tag(kind)
                    }
                }
                Toggle("Modifiable en Jouer", isOn: $property.isLive)
            }
            Section {
                LabeledContent(property.kind == .formula ? "Formule" : "Formule par défaut") {
                    TextField("Formule", text: optional($property.formula), prompt: Text("=pct/2"))
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospaced())
                        .autocorrectionDisabled()
                        .textCapitalization(.never)
                }
                switch property.kind {
                case .text:
                    LabeledContent("Valeur par défaut") {
                        TextField("Valeur par défaut", text: optional($property.textValue), prompt: Text("—"))
                            .multilineTextAlignment(.trailing)
                    }
                case .number, .percentage:
                    LabeledContent("Valeur par défaut") {
                        NumberField(value: $property.numberValue, integer: false, prompt: "—", width: 80,
                                    accessibilityName: "Valeur par défaut")
                    }
                case .checkbox:
                    Toggle("Cochée par défaut", isOn: Binding(get: { property.boolValue == true },
                                                               set: { property.boolValue = $0 }))
                case .formula:
                    EmptyView()
                }
            } footer: {
                Text("Un objet sans valeur propre prend la valeur par défaut, sinon le résultat de la formule.")
            }
            DeleteSection(title: "Supprimer la propriété",
                          message: "Les valeurs de cette propriété sont supprimées de tous les objets.") {
                context.delete(property)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(property.label.isEmpty ? String(localized: "Propriété") : property.label)
    }
}

private struct SlotEditor: View {
    @Bindable var slot: InventorySlot
    let inventory: Inventory
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                TextField("Nom", text: $slot.name, prompt: Text("Bateau"))
                IconPicker(selection: $slot.icon)
            }
            if inventory.tracksWeight {
                Section {
                    Toggle("Compte dans la charge", isOn: $slot.countsTowardEncumbrance)
                    LabeledContent("Capacité") {
                        HStack(spacing: 4) {
                            NumberField(value: $slot.capacity, integer: false, prompt: "—", width: 80, accessibilityName: "Capacité")
                            Text(inventory.weightUnit).foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    Text("Ce qui est sur soi compte dans la charge ; une monture, un bateau ou une planque, non. La capacité est facultative.")
                }
            }
            OrderSection(item: slot, sorted: inventory.sortedSlots)
            DeleteSection(title: "Supprimer l'emplacement",
                          message: (slot.items ?? []).isEmpty ? nil : "Les objets rangés dans cet emplacement sont supprimés aussi.") {
                context.delete(slot)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(slot.name)
    }
}

/// Choix d'une icône parmi une sélection de symboles.
private struct IconPicker: View {
    @Binding var selection: String

    static let symbols = [
        "figure.stand", "backpack", "bag", "shippingbox", "archivebox", "tray", "house", "building.columns",
        "tent", "hare", "sailboat", "car", "cart", "lock",
        "shield", "shield.lefthalf.filled", "tshirt", "crown", "flask", "pills", "bandage", "fork.knife",
        "flame", "leaf", "drop", "bolt", "sparkles", "wand.and.stars", "scroll", "book", "map", "key",
        "hammer", "wrench.and.screwdriver", "scope", "music.note", "hourglass", "gift", "puzzlepiece",
        "dollarsign.circle", "star", "die.face.5",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icône")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 6)], spacing: 6) {
                ForEach(Self.symbols, id: \.self) { symbol in
                    Button {
                        selection = symbol
                    } label: {
                        Image(systemName: symbol)
                            .frame(width: 36, height: 36)
                            .background(selection == symbol ? Color.accentColor.opacity(0.2) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(selection == symbol ? Color.accentColor : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                    .accessibilityAddTraits(selection == symbol ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}
