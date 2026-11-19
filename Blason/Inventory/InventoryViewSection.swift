import SwiftUI
import SwiftData
import SheetKit

/// Vue de la Besace (SPEC §5.13) : objets équipés des types choisis, propriétés en colonnes.
/// Une valeur modifiée ici l'est dans l'objet ; la Besace reste la seule source.
struct InventoryViewSection: View {
    let section: SheetSection

    @Environment(\.sheetMode) private var mode
    @Environment(\.inventoryItemOpener) private var opener
    @ScaledMetric(relativeTo: .body) private var numberWidth: CGFloat = 60

    var body: some View {
        if section.viewedInventory == nil {
            Text("Ajoutez une Besace à la fiche : cette vue montre ses objets équipés.")
                .font(.callout).foregroundStyle(.secondary)
        } else if section.viewTypeCodes.isEmpty {
            Text(mode == .structure ? "Choisissez les types montrés dans l'inspecteur." : "Aucun type d'objet choisi.")
                .font(.callout).foregroundStyle(.secondary)
        } else {
            let items = section.viewedItems
            if items.isEmpty {
                Text("Aucun objet équipé").font(.callout).foregroundStyle(.secondary)
            } else {
                ViewThatFits(in: .horizontal) {
                    grid(items)
                    ScrollView(.horizontal) {
                        grid(items).padding(.bottom, 8)
                    }
                    .scrollIndicators(.visible)
                }
                .allowsHitTesting(mode != .structure)
            }
        }
    }

    /// Mis en page comme les tableaux de la fiche (`TableLayout`) : les colonnes de texte partagent
    /// la place avec les noms, les nombres et les cases restent à leur largeur.
    private func grid(_ items: [InventoryItem]) -> some View {
        let codes = section.viewPropertyCodes
        let engine = FormulaEngine(sheet: section.row?.page?.sheet)
        return TableLayout(columns: codes.map(layoutColumn)) {
            Group {
                Text("Objet")
                ForEach(codes, id: \.self) { code in
                    Text(label(for: code))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            ForEach(items) { item in
                Button {
                    opener?.open(item)
                } label: {
                    Label(item.name, systemImage: item.type?.icon ?? "shippingbox")
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                ForEach(codes, id: \.self) { code in
                    if let property = item.type?.property(code: code) {
                        ItemPropertyEditor(item: item, property: property, engine: engine,
                                           width: 60, textAlignment: .leading)
                    } else {
                        Color.clear.frame(width: 1, height: 1)
                    }
                }
            }
        }
    }

    private func layoutColumn(_ code: String) -> TableLayout.Column {
        switch property(for: code)?.kind {
        case .text: TableLayout.Column(flexible: true, trailing: false)
        case .checkbox: TableLayout.Column(flexible: false, trailing: true)
        default: TableLayout.Column(flexible: false, trailing: true, minimumWidth: numberWidth)
        }
    }

    /// Libellé d'une colonne : celui de la première propriété de ce code parmi les types montrés.
    private func property(for code: String) -> ItemProperty? {
        guard let inventory = section.viewedInventory else { return nil }
        return section.viewTypeCodes.lazy.compactMap { inventory.itemType(code: $0)?.property(code: code) }.first
    }

    private func label(for code: String) -> String {
        guard let property = property(for: code) else { return code }
        return property.label.isEmpty ? code : property.label
    }

}

/// Inspecteur d'une vue de la Besace : types montrés et propriétés en colonnes.
struct InventoryViewInspector: View {
    @Bindable var section: SheetSection

    var body: some View {
        if let inventory = section.viewedInventory {
            Section {
                ForEach(inventory.sortedItemTypes.filter { !$0.code.isEmpty && $0.code != "argent" }) { type in
                    Toggle(isOn: membership(type.code, in: \.viewTypeCodes)) {
                        Label(type.name, systemImage: type.icon)
                    }
                }
            } header: {
                Text("Objets équipés de type")
            } footer: {
                Text("Un objet s'équipe depuis la Besace. Déséquipé, il quitte la vue et garde ses valeurs.")
            }
            let properties = availableProperties(inventory)
            if !properties.isEmpty {
                Section {
                    ForEach(properties, id: \.code) { property in
                        Toggle(isOn: membership(property.code, in: \.viewPropertyCodes)) {
                            LabeledContent(property.label.isEmpty ? property.code : property.label, value: property.code)
                        }
                    }
                } header: {
                    Text("Colonnes")
                } footer: {
                    Text("Dans l'ordre où elles sont cochées.")
                }
            }
        } else {
            Section {
                Text("Ajoutez d'abord une section Besace à la fiche.")
            }
        }
    }

    /// Propriétés des types montrés, une par code.
    private func availableProperties(_ inventory: Inventory) -> [ItemProperty] {
        var seen: Set<String> = []
        var result: [ItemProperty] = []
        for code in section.viewTypeCodes {
            for property in inventory.itemType(code: code)?.sortedProperties ?? [] where !property.code.isEmpty {
                if seen.insert(property.code.lowercased()).inserted { result.append(property) }
            }
        }
        return result
    }

    private func membership(_ code: String, in keyPath: ReferenceWritableKeyPath<SheetSection, [String]>) -> Binding<Bool> {
        Binding(
            get: { section[keyPath: keyPath].contains { $0.caseInsensitiveCompare(code) == .orderedSame } },
            set: { isOn in
                section[keyPath: keyPath].removeAll { $0.caseInsensitiveCompare(code) == .orderedSame }
                if isOn { section[keyPath: keyPath].append(code) }
            }
        )
    }
}

/// Inspecteur d'une section Besace : résumé et accès aux réglages.
struct InventoryInspector: View {
    let inventory: Inventory
    @State private var showsSettings = false

    var body: some View {
        Section {
            LabeledContent("Code", value: inventory.code)
            LabeledContent("Types d'objets", value: "\(inventory.itemTypes?.count ?? 0)")
            LabeledContent("Emplacements", value: "\(inventory.slots?.count ?? 0)")
            LabeledContent("Poids", value: inventory.tracksWeight ? inventory.weightUnit : String(localized: "Non suivi"))
            Button("Réglages de la Besace…", systemImage: "slider.horizontal.3") { showsSettings = true }
        } header: {
            Text("Besace")
        } footer: {
            Text("Dans un template, les objets de la Besace sont l'équipement de départ de chaque nouveau personnage. Ils se saisissent en mode Remplir.")
        }
        .sheet(isPresented: $showsSettings) {
            InventorySettingsView(inventory: inventory)
        }
    }
}
