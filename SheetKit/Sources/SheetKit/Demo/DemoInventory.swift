import Foundation
import SwiftData

extension DemoData {
    /// Besace d'exemple ajoutée à une fiche BRP (captures, essais : `-demoBesace YES`) :
    /// armes avec propriétés, sac à dos, argent, monture, poids et paliers (onglet Inventaire) ; vue « Armes équipées »
    /// sur la page Combat. Ne fait rien si la fiche a déjà une Besace.
    @discardableResult
    public static func addDemoInventory(to sheet: Sheet, in context: ModelContext) -> Inventory? {
        guard sheet.inventories.isEmpty else { return nil }
        let inventory = sheet.ensureInventory(in: context)
        inventory.tracksWeight = true
        inventory.weightUnit = "kg"
        inventory.weightLimitFormula = "=FOR*2"
        inventory.appliesMalus = true
        inventory.addLevel(name: "Chargé", threshold: "=BESACE.limite", malus: -10, effect: "Mouvement −2", in: context)
        inventory.addLevel(name: "Surchargé", threshold: "=BESACE.limite*1.5", malus: -25, effect: "Mouvement −5", in: context)

        let gold = inventory.sortedCurrencies.first
        gold?.rate = 100
        let silver = inventory.addCurrency(name: "Pièce d'argent", abbreviation: "pa", rate: 10, in: context)
        let copper = inventory.addCurrency(name: "Pièce de cuivre", abbreviation: "pc", rate: 1, in: context)

        let weapon = inventory.itemType(code: "arme")
        let percent = weapon?.addProperty(label: "%", kind: .percentage, code: "pct", in: context)
        percent?.numberValue = 25
        let experience = weapon?.addProperty(label: "Exp.", kind: .checkbox, code: "exp", in: context)
        experience?.isLive = true

        guard let onSelf = inventory.sortedSlots.first else { return inventory }
        let horse = inventory.addSlot(name: "Monture", icon: "hare", in: context)
        horse.countsTowardEncumbrance = false
        horse.capacity = 80

        let sword = onSelf.addItem(named: "Épée longue", type: weapon, context: context)
        sword.isEquipped = true
        sword.unitWeight = 2
        sword.price = "25 po"
        if let percent { sword.editableValue(for: percent, in: context).numberValue = 45 }
        if let damage = weapon?.property(code: "degats") { sword.editableValue(for: damage, in: context).textValue = "1d8+1+BD" }
        if let range = weapon?.property(code: "portee") { sword.editableValue(for: range, in: context).textValue = "Contact" }
        let knife = onSelf.addItem(named: "Couteau", type: weapon, context: context)
        knife.isEquipped = true
        knife.unitWeight = 0.5
        if let damage = weapon?.property(code: "degats") { knife.editableValue(for: damage, in: context).textValue = "1d4+BD" }
        let leather = onSelf.addItem(named: "Cuir bouilli", type: inventory.itemType(code: "armure"), context: context)
        leather.isEquipped = true
        leather.unitWeight = 8
        if let protection = inventory.itemType(code: "armure")?.property(code: "protection") {
            leather.editableValue(for: protection, in: context).numberValue = 3
        }
        let backpack = onSelf.addItem(named: "Sac à dos", type: inventory.itemType(code: "equipement"), context: context)
        backpack.setContainer(true)
        backpack.unitWeight = 1
        onSelf.addItem(named: "Corde (15 m)", type: inventory.itemType(code: "equipement"), in: backpack, context: context).unitWeight = 2
        onSelf.addItem(named: "Rations", type: inventory.itemType(code: "consommable"), quantity: 4, in: backpack, context: context).unitWeight = 0.5
        onSelf.addItem(named: "Torches", type: inventory.itemType(code: "consommable"), quantity: 3, in: backpack, context: context).unitWeight = 0.5
        let purse = onSelf.addItem(named: "Bourse", type: inventory.itemType(code: "equipement"), context: context)
        purse.setContainer(true)
        if let gold { onSelf.addMoney(gold, amount: 12, in: purse, context: context) }
        onSelf.addMoney(silver, amount: 30, in: purse, context: context)
        onSelf.addMoney(copper, amount: 7, in: purse, context: context)
        horse.addItem(named: "Tente", type: inventory.itemType(code: "equipement"), context: context).unitWeight = 12
        horse.addItem(named: "Avoine", type: inventory.itemType(code: "consommable"), quantity: 6, context: context).unitWeight = 2

        if let combat = sheet.sortedPages.first(where: { $0.title == "Combat" }) {
            let view = combat.addRow(in: context).addSection(title: "Armes équipées", kind: .inventoryView, in: context)
            view.viewTypeCodes = ["arme"]
            view.viewPropertyCodes = ["pct", "degats", "portee", "exp"]
        }
        return inventory
    }
}
