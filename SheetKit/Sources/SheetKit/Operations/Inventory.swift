import Foundation
import SwiftData

// Besace (SPEC §5.13) : création, rangement, quantités, poids, argent, valeurs des propriétés.
// Les calculs qui passent par les formules (limite, paliers, malus) sont dans `FormulaEngine`.

// MARK: - Listes triées

extension Inventory {
    public var sortedItemTypes: [ItemType] { (itemTypes ?? []).sorted { $0.order < $1.order } }
    public var sortedCurrencies: [Currency] { (currencies ?? []).sorted { $0.order < $1.order } }
    public var sortedSlots: [InventorySlot] { (slots ?? []).sorted { $0.order < $1.order } }
    public var sortedLevels: [EncumbranceLevel] { (levels ?? []).sorted { $0.order < $1.order } }

    /// Tous les objets, emplacement par emplacement.
    public var allItems: [InventoryItem] { sortedSlots.flatMap { $0.items ?? [] } }

    public func itemType(code: String) -> ItemType? {
        guard !code.isEmpty else { return nil }
        return (itemTypes ?? []).first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }
}

extension ItemType {
    public var sortedProperties: [ItemProperty] { (properties ?? []).sorted { $0.order < $1.order } }

    public func property(code: String) -> ItemProperty? {
        guard !code.isEmpty else { return nil }
        return (properties ?? []).first { $0.code.caseInsensitiveCompare(code) == .orderedSame }
    }
}

extension ItemProperty {
    public var kind: ColumnKind {
        get { ColumnKind(rawValue: kindRaw) ?? .text }
        set { kindRaw = newValue.rawValue }
    }
}

extension InventorySlot {
    /// Objets rangés directement dans l'emplacement (hors contenants), dans l'ordre.
    public var looseItems: [InventoryItem] {
        (items ?? []).filter { $0.container == nil }.sorted { $0.order < $1.order }
    }
}

extension InventoryItem {
    /// Contenu d'un contenant, dans l'ordre.
    public var sortedContents: [InventoryItem] { (contents ?? []).sorted { $0.order < $1.order } }

    /// Compteur d'argent (objet lié à une monnaie).
    public var isMoney: Bool { currency != nil }

    /// Besace de l'objet.
    public var inventory: Inventory? { slot?.inventory }

    /// Position dans la Besace : emplacement, place à la racine, puis dans le contenant.
    var besaceOrder: (Int, Int, Int, Int) {
        (slot?.order ?? 0, container?.order ?? order, container == nil ? 0 : 1, order)
    }
}

extension Sheet {
    /// Besaces de la fiche, page par page (en général une seule).
    public var inventories: [Inventory] {
        sortedPages.flatMap(\.sortedRows).flatMap(\.sortedSections).compactMap(\.inventory)
    }
}

extension SheetSection {
    /// Besace montrée par une vue de la Besace : la première de la fiche.
    public var viewedInventory: Inventory? {
        guard kind == .inventoryView else { return nil }
        return row?.page?.sheet?.inventories.first
    }

    /// Objets d'une vue de la Besace : équipés, des types choisis, dans l'ordre de la Besace.
    public var viewedItems: [InventoryItem] {
        guard let inventory = viewedInventory else { return [] }
        let codes = Set(viewTypeCodes.map { $0.lowercased() })
        return inventory.allItems
            .filter { item in
                guard item.isEquipped, let code = item.type?.code, !code.isEmpty else { return false }
                return codes.contains(code.lowercased())
            }
            .sorted { $0.besaceOrder < $1.besaceOrder }
    }
}

// MARK: - Création

extension SheetRow {
    /// Ajoute une section Besace, avec ses types, sa monnaie et son emplacement de départ.
    @discardableResult
    public func addInventorySection(title: String = "Besace", column: Int = 0, in context: ModelContext) -> SheetSection {
        let section = addSection(title: title, kind: .inventory, column: column, in: context)
        let inventory = Inventory()
        context.insert(inventory)
        inventory.section = section
        inventory.addStarterContent(in: context)
        return section
    }
}

extension Inventory {
    /// Types de départ (Argent, Arme, Armure, Habits, Équipement, Consommable, Divers),
    /// une monnaie et l'emplacement « Sur soi ».
    func addStarterContent(in context: ModelContext) {
        let types: [(String, String, String)] = [
            ("Argent", "argent", "dollarsign.circle"),
            ("Arme", "arme", "shield.lefthalf.filled"),
            ("Armure", "armure", "shield"),
            ("Habits", "habits", "tshirt"),
            ("Équipement", "equipement", "backpack"),
            ("Consommable", "consommable", "flask"),
            ("Divers", "divers", "shippingbox"),
        ]
        for (name, code, icon) in types {
            addItemType(name: name, code: code, icon: icon, in: context)
        }
        if let weapon = itemType(code: "arme") {
            weapon.addProperty(label: "Dégâts", kind: .text, code: "degats", in: context)
            weapon.addProperty(label: "Portée", kind: .text, code: "portee", in: context)
        }
        if let armor = itemType(code: "armure") {
            armor.addProperty(label: "Protection", kind: .number, code: "protection", in: context)
        }
        addCurrency(name: "Pièce d'or", abbreviation: "po", rate: 1, in: context)
        addSlot(name: "Sur soi", icon: "figure.stand", in: context)
    }

    @discardableResult
    public func addItemType(name: String, code: String = "", icon: String = "shippingbox", in context: ModelContext) -> ItemType {
        let type = ItemType(name: name, code: code, icon: icon, order: ((itemTypes ?? []).map(\.order).max() ?? -1) + 1)
        context.insert(type)
        type.inventory = self
        return type
    }

    @discardableResult
    public func addCurrency(name: String, abbreviation: String, rate: Double, in context: ModelContext) -> Currency {
        let currency = Currency(name: name, abbreviation: abbreviation, rate: rate,
                                order: ((currencies ?? []).map(\.order).max() ?? -1) + 1)
        context.insert(currency)
        currency.inventory = self
        return currency
    }

    @discardableResult
    public func addSlot(name: String, icon: String = "shippingbox", in context: ModelContext) -> InventorySlot {
        let slot = InventorySlot(name: name, icon: icon, order: ((slots ?? []).map(\.order).max() ?? -1) + 1)
        context.insert(slot)
        slot.inventory = self
        return slot
    }

    @discardableResult
    public func addLevel(name: String, threshold: String?, malus: Double? = nil, effect: String = "",
                         in context: ModelContext) -> EncumbranceLevel {
        let level = EncumbranceLevel(name: name, thresholdFormula: threshold,
                                     order: ((levels ?? []).map(\.order).max() ?? -1) + 1)
        context.insert(level)
        level.inventory = self
        level.malus = malus
        level.effect = effect
        return level
    }
}

extension ItemType {
    @discardableResult
    public func addProperty(label: String, kind: ColumnKind, code: String, in context: ModelContext) -> ItemProperty {
        let property = ItemProperty(label: label, kind: kind, code: code,
                                    order: ((properties ?? []).map(\.order).max() ?? -1) + 1)
        context.insert(property)
        property.type = self
        return property
    }
}

extension InventorySlot {
    /// Ajoute un objet dans l'emplacement, ou dans `container` (qui doit être dans cet emplacement).
    @discardableResult
    public func addItem(named name: String, type: ItemType? = nil, quantity: Double = 1,
                        in container: InventoryItem? = nil, context: ModelContext) -> InventoryItem {
        let item = InventoryItem(name: name, quantity: quantity)
        context.insert(item)
        item.type = type
        item.place(in: self, container: container)
        return item
    }

    /// Ajoute un compteur d'argent.
    @discardableResult
    public func addMoney(_ currency: Currency, amount: Double, in container: InventoryItem? = nil,
                         context: ModelContext) -> InventoryItem {
        let item = addItem(named: currency.name, type: currency.inventory?.itemType(code: "argent"),
                           quantity: amount, in: container, context: context)
        item.currency = currency
        return item
    }
}

// MARK: - Rangement et quantités

extension InventoryItem {
    /// Range l'objet dans un emplacement, ou dans un contenant de cet emplacement (à la fin).
    /// Un contenant ne va pas dans un autre contenant (un seul niveau) : il reste dans l'emplacement.
    public func place(in slot: InventorySlot, container: InventoryItem? = nil) {
        let target = (container?.slot === slot && container !== self && !isContainer) ? container : nil
        let siblings = target.map { $0.contents ?? [] } ?? (slot.items ?? []).filter { $0.container == nil }
        order = (siblings.filter { $0 !== self }.map(\.order).max() ?? -1) + 1
        self.slot = slot
        self.container = target
        // Le contenu d'un contenant le suit.
        for item in contents ?? [] where item !== self {
            item.slot = slot
        }
    }

    /// Ajoute `delta` à la quantité (mode Jouer), sans descendre sous 0.
    public func adjustQuantity(by delta: Double) {
        quantity = max(0, quantity + delta)
    }

    /// Devient (ou cesse d'être) un contenant. En cessant, son contenu revient dans l'emplacement.
    public func setContainer(_ isContainer: Bool) {
        if !isContainer, let slot {
            for item in sortedContents {
                item.place(in: slot)
            }
        }
        self.isContainer = isContainer
        if isContainer, let slot, container != nil {
            place(in: slot)
        }
    }
}

// MARK: - Poids

extension InventoryItem {
    /// Poids de l'objet (quantité × poids unitaire), contenu compris pour un contenant.
    /// L'argent ne pèse rien (SPEC §5.13).
    public var totalWeight: Double {
        let own = isMoney ? 0 : quantity * (unitWeight ?? 0)
        return own + (contents ?? []).reduce(0) { $0 + $1.totalWeight }
    }
}

extension InventorySlot {
    /// Poids de tout ce qui est dans l'emplacement.
    public var totalWeight: Double {
        looseItems.reduce(0) { $0 + $1.totalWeight }
    }

    /// Capacité dépassée.
    public var isOverCapacity: Bool {
        guard let capacity else { return false }
        return totalWeight > capacity
    }
}

extension Inventory {
    /// Poids porté : emplacements qui comptent dans l'encombrement (`BESACE.poids`).
    public var carriedWeight: Double {
        sortedSlots.filter(\.countsTowardEncumbrance).reduce(0) { $0 + $1.totalWeight }
    }
}

// MARK: - Argent

extension Inventory {
    /// Fortune dans la plus petite monnaie (`BESACE.argent`) : pièces × valeur relative.
    public var totalMoney: Double {
        allItems.reduce(0) { total, item in
            guard let currency = item.currency else { return total }
            return total + item.quantity * currency.rate
        }
    }

    /// Fortune convertie : « 12 po 4 pa 3 pc », de la plus grande monnaie à la plus petite.
    /// Affichage seulement : les pièces ne sont jamais converties.
    public var formattedMoney: String {
        let currencies = (currencies ?? []).filter { $0.rate > 0 }.sorted { $0.rate > $1.rate }
        guard !currencies.isEmpty else { return "" }
        var rest = totalMoney
        var parts: [String] = []
        for (index, currency) in currencies.enumerated() {
            let isLast = index == currencies.count - 1
            let count = isLast ? rest / currency.rate : (rest / currency.rate).rounded(.down)
            rest -= count * currency.rate
            if count != 0 || (isLast && parts.isEmpty) {
                let label = currency.abbreviation.isEmpty ? currency.name : currency.abbreviation
                parts.append("\(NumberText.string(count)) \(label)")
            }
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Propriétés des objets

extension InventoryItem {
    /// Valeur saisie pour une propriété (nil : défaut de la propriété).
    public func value(for property: ItemProperty) -> ItemPropertyValue? {
        (propertyValues ?? []).first { $0.property === property }
    }

    /// Valeur de la propriété de code `code` du type de l'objet.
    public func value(code: String) -> ItemPropertyValue? {
        guard let property = type?.property(code: code) else { return nil }
        return value(for: property)
    }

    /// Valeur modifiable de la propriété, créée au besoin.
    @discardableResult
    public func editableValue(for property: ItemProperty, in context: ModelContext) -> ItemPropertyValue {
        if let existing = value(for: property) { return existing }
        let value = ItemPropertyValue()
        context.insert(value)
        value.item = self
        value.property = property
        return value
    }

    /// Change le type de l'objet ; les valeurs des propriétés de l'ancien type sont retirées.
    public func changeType(to newType: ItemType?, in context: ModelContext) {
        guard newType !== type else { return }
        for value in propertyValues ?? [] where value.property?.type !== newType {
            context.delete(value)
        }
        type = newType
    }
}

extension ItemPropertyValue {
    public func apply(_ input: CellInput) {
        switch input {
        case .number(let value): numberValue = value
        case .text(let value): textValue = value
        case .bool(let value): boolValue = value
        case .formula(let value): formula = value
        }
    }
}
