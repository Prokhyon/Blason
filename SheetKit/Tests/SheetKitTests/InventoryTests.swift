import Foundation
import SwiftData
import Testing
@testable import SheetKit

@MainActor
@Suite("Besace")
struct InventoryTests {

    /// Fiche d'une page avec un champ FOR et une Besace de départ.
    private func sheetWithInventory(_ context: ModelContext) throws -> (SheetTemplate, Inventory) {
        let template = SheetTemplate.create(name: "Pirates", firstPage: "Fiche", in: context)
        let row = try #require(template.sheet?.sortedPages.first?.sortedRows.first)
        let stats = row.addSection(title: "Caractéristiques", kind: .fields, in: context)
        stats.addField(label: "Force", kind: .integer, code: "FOR", in: context).numberValue = 10
        let section = row.addInventorySection(in: context)
        return (template, try #require(section.inventory))
    }

    @Test("Une nouvelle Besace a ses types, une monnaie et l'emplacement « Sur soi »")
    func starterContent() throws {
        let context = try makeContext()
        let (_, inventory) = try sheetWithInventory(context)
        #expect(inventory.section?.kind == .inventory)
        #expect(inventory.code == "BESACE")
        #expect(inventory.sortedItemTypes.map(\.name) == ["Argent", "Arme", "Armure", "Habits", "Équipement", "Consommable", "Divers"])
        #expect(inventory.itemType(code: "ARME")?.sortedProperties.map(\.code) == ["degats", "portee"])
        #expect(inventory.sortedCurrencies.map(\.abbreviation) == ["po"])
        #expect(inventory.sortedSlots.map(\.name) == ["Sur soi"])
        #expect(!inventory.tracksWeight)
    }

    @Test("Besace de la fiche : créée à la demande, une seule, absente des pages dessinées")
    func sheetInventory() throws {
        let context = try makeContext()
        let template = SheetTemplate.create(name: "Pirates", firstPage: "Fiche", in: context)
        let sheet = try #require(template.sheet)
        #expect(sheet.inventory == nil)
        let inventory = sheet.ensureInventory(in: context)
        #expect(sheet.ensureInventory(in: context) === inventory)
        #expect(sheet.inventories.count == 1)
        let row = try #require(inventory.section?.row)
        #expect(row.page === sheet.sortedPages.first)
        #expect(row.sections(inColumn: 0).map(\.kind) == [.inventory])
        #expect(row.displayedSections(inColumn: 0).isEmpty)
        // Une fiche sans page en reçoit une.
        let blank = PlayerCharacter.createBlank(named: "Mira", in: context)
        blank.sheet?.pages = []
        #expect(blank.sheet?.ensureInventory(in: context).section?.row?.page?.title == "Fiche")
    }

    @Test("Poids : quantité × poids, contenants, emplacements hors encombrement, capacité ; l'argent ne pèse rien")
    func weights() throws {
        let context = try makeContext()
        let (_, inventory) = try sheetWithInventory(context)
        let onSelf = try #require(inventory.sortedSlots.first)
        let ship = inventory.addSlot(name: "Bateau", icon: "sailboat", in: context)
        ship.countsTowardEncumbrance = false
        ship.capacity = 100

        let sword = onSelf.addItem(named: "Sabre", type: inventory.itemType(code: "arme"), context: context)
        sword.unitWeight = 1.5
        let bag = onSelf.addItem(named: "Sac à dos", context: context)
        bag.setContainer(true)
        bag.unitWeight = 1
        let rations = onSelf.addItem(named: "Rations", quantity: 4, in: bag, context: context)
        rations.unitWeight = 0.5
        let gold = try #require(inventory.sortedCurrencies.first)
        onSelf.addMoney(gold, amount: 500, context: context)
        let barrels = ship.addItem(named: "Tonneau de rhum", quantity: 12, context: context)
        barrels.unitWeight = 10

        #expect(bag.totalWeight == 3)
        #expect(onSelf.totalWeight == 4.5)
        #expect(onSelf.looseItems.map(\.name) == ["Sabre", "Sac à dos", "Pièce d'or"])
        #expect(ship.totalWeight == 120)
        #expect(ship.isOverCapacity)
        #expect(!onSelf.isOverCapacity)
        #expect(inventory.carriedWeight == 4.5)
    }

    @Test("Argent : fortune dans la plus petite monnaie, affichée convertie sans toucher aux pièces")
    func money() throws {
        let context = try makeContext()
        let (template, inventory) = try sheetWithInventory(context)
        let gold = try #require(inventory.sortedCurrencies.first)
        gold.rate = 100
        let silver = inventory.addCurrency(name: "Pièce d'argent", abbreviation: "pa", rate: 10, in: context)
        let copper = inventory.addCurrency(name: "Pièce de cuivre", abbreviation: "pc", rate: 1, in: context)
        let slot = try #require(inventory.sortedSlots.first)
        let purse = slot.addItem(named: "Bourse", context: context)
        purse.setContainer(true)
        slot.addMoney(gold, amount: 3, in: purse, context: context)
        let silverCoins = slot.addMoney(silver, amount: 14, context: context)
        slot.addMoney(copper, amount: 23, context: context)

        #expect(inventory.totalMoney == 463)
        #expect(inventory.formattedMoney == "4 po 6 pa 3 pc")
        #expect(silverCoins.quantity == 14)
        #expect(silverCoins.type?.code == "argent")
        let engine = FormulaEngine(sheet: template.sheet)
        let field = try #require(inventory.section?.row?.addSection(title: "Calculs", kind: .fields, in: context)
            .addField(label: "Fortune", kind: .formula, in: context))
        field.formula = "=BESACE.argent/100"
        #expect(engine.value(of: field) == .success(4.63))

        // Une seule monnaie : son total, même nul.
        let (_, simple) = try sheetWithInventory(try makeContext())
        #expect(simple.formattedMoney == "0 po")
    }

    @Test("Encombrement : limite et paliers par formule, malus dans les formules (0 sans palier ou sans malus)")
    func encumbrance() throws {
        let context = try makeContext()
        let (template, inventory) = try sheetWithInventory(context)
        inventory.tracksWeight = true
        inventory.weightLimitFormula = "=FOR*2"
        inventory.addLevel(name: "Chargé", threshold: "=BESACE.limite", malus: -10, effect: "Mouvement −2", in: context)
        inventory.addLevel(name: "Surchargé", threshold: "=BESACE.limite*1.5", malus: -20, in: context)
        let stats = try #require(template.sheet?.field(code: "FOR")?.section)
        let dodge = stats.addField(label: "Esquive", kind: .formula, code: "ESQ", in: context)
        dodge.formula = "=50+BESACE.malus"
        let slot = try #require(inventory.sortedSlots.first)
        let chest = slot.addItem(named: "Coffre", context: context)
        chest.unitWeight = 20

        func check(level: String?, malus: Double, dodgeValue: Double, file: String = #filePath, line: Int = #line) {
            let engine = FormulaEngine(sheet: template.sheet)
            let location = SourceLocation(fileID: #fileID, filePath: file, line: line, column: 1)
            #expect(engine.level(of: inventory)?.name == level, sourceLocation: location)
            #expect(engine.malus(of: inventory) == malus, sourceLocation: location)
            #expect(engine.value(of: dodge) == .success(dodgeValue), sourceLocation: location)
        }

        #expect(FormulaEngine(sheet: template.sheet).limit(of: inventory) == .success(20))
        // Poids égal à la limite : pas encore chargé.
        check(level: nil, malus: 0, dodgeValue: 50)
        chest.quantity = 2
        // Malus non appliqué : le palier s'affiche, le malus vaut 0.
        check(level: "Surchargé", malus: 0, dodgeValue: 50)
        inventory.appliesMalus = true
        check(level: "Surchargé", malus: -20, dodgeValue: 30)
        chest.unitWeight = 12
        check(level: "Chargé", malus: -10, dodgeValue: 40)
        // Sans poids ni encombrement : aucun palier.
        inventory.tracksWeight = false
        check(level: nil, malus: 0, dodgeValue: 50)
    }

    @Test("Propriétés d'objet : défaut du type, valeur propre, formules sur l'objet et la fiche")
    func properties() throws {
        let context = try makeContext()
        let (template, inventory) = try sheetWithInventory(context)
        let weapon = try #require(inventory.itemType(code: "arme"))
        let percent = weapon.addProperty(label: "%", kind: .percentage, code: "pct", in: context)
        percent.numberValue = 25
        let half = weapon.addProperty(label: "Moitié", kind: .formula, code: "moitie", in: context)
        half.formula = "=pct/2"
        let bonus = weapon.addProperty(label: "Bonus", kind: .number, code: "bonus", in: context)
        bonus.formula = "=FOR+quantite"
        let slot = try #require(inventory.sortedSlots.first)
        let pistol = slot.addItem(named: "Pistolet", type: weapon, context: context)
        let musket = slot.addItem(named: "Mousquet", type: weapon, quantity: 2, context: context)
        musket.editableValue(for: percent, in: context).apply(60)
        musket.editableValue(for: weapon.property(code: "degats")!, in: context).apply("1d10+2")

        let engine = FormulaEngine(sheet: template.sheet)
        #expect(engine.value(of: pistol, percent) == .success(25))
        #expect(engine.value(of: pistol, half) == .success(12.5))
        #expect(engine.value(of: musket, half) == .success(30))
        #expect(engine.value(of: pistol, bonus) == .success(11))
        #expect(engine.value(of: musket, bonus) == .success(12))
        #expect(musket.value(code: "degats")?.textValue == "1d10+2")

        // Changer de type retire les valeurs de l'ancien type.
        musket.changeType(to: inventory.itemType(code: "divers"), in: context)
        try context.save()
        #expect(musket.propertyValues?.isEmpty == true)
        #expect(try context.fetchCount(FetchDescriptor<ItemPropertyValue>()) == 0)
    }

    @Test("Rangement : un seul niveau de contenant, le contenu suit son contenant ; quantité jamais négative")
    func placement() throws {
        let context = try makeContext()
        let (_, inventory) = try sheetWithInventory(context)
        let onSelf = try #require(inventory.sortedSlots.first)
        let horse = inventory.addSlot(name: "Monture", icon: "hare", in: context)
        let bag = onSelf.addItem(named: "Sac", context: context)
        bag.setContainer(true)
        let pouch = onSelf.addItem(named: "Bourse", context: context)
        pouch.setContainer(true)
        let rope = onSelf.addItem(named: "Corde", in: bag, context: context)

        // Un contenant ne va pas dans un autre : il reste dans l'emplacement.
        pouch.place(in: onSelf, container: bag)
        #expect(pouch.container == nil)
        // Le contenant change d'emplacement avec son contenu.
        bag.place(in: horse)
        #expect(rope.slot === horse && rope.container === bag)
        #expect(horse.totalWeight == 0)
        #expect(onSelf.looseItems.map(\.name) == ["Bourse"])
        // Un objet rangé dans un contenant d'un autre emplacement reste à la racine.
        let torch = onSelf.addItem(named: "Torche", in: bag, context: context)
        #expect(torch.container == nil && torch.slot === onSelf)
        // Cesser d'être un contenant vide le contenu dans l'emplacement.
        bag.setContainer(false)
        #expect(rope.container == nil && rope.slot === horse)
        #expect(horse.looseItems.map(\.name) == ["Sac", "Corde"])

        rope.adjustQuantity(by: -3)
        #expect(rope.quantity == 0)
        rope.adjustQuantity(by: 2)
        #expect(rope.quantity == 2)

        // Supprimer un contenant laisse son contenu dans l'emplacement.
        let quiver = onSelf.addItem(named: "Carquois", context: context)
        quiver.setContainer(true)
        let arrows = onSelf.addItem(named: "Flèches", quantity: 20, in: quiver, context: context)
        context.delete(quiver)
        try context.save()
        #expect(arrows.container == nil && arrows.slot === onSelf)
    }

    @Test("Vue de la Besace : objets équipés des types choisis, dans l'ordre de la Besace")
    func inventoryView() throws {
        let context = try makeContext()
        let (template, inventory) = try sheetWithInventory(context)
        let page = try #require(template.sheet?.addPage(title: "Combat", in: context))
        let view = page.addRow(in: context).addSection(title: "Armes", kind: .inventoryView, in: context)
        view.viewTypeCodes = ["arme", "armure"]
        view.viewPropertyCodes = ["degats", "portee"]
        let slot = try #require(inventory.sortedSlots.first)
        let bag = slot.addItem(named: "Sac", context: context)
        bag.setContainer(true)
        let sword = slot.addItem(named: "Sabre", type: inventory.itemType(code: "arme"), context: context)
        let dagger = slot.addItem(named: "Dague", type: inventory.itemType(code: "arme"), in: bag, context: context)
        let spare = slot.addItem(named: "Épée de rechange", type: inventory.itemType(code: "arme"), context: context)
        let coat = slot.addItem(named: "Manteau", type: inventory.itemType(code: "habits"), context: context)
        for item in [sword, dagger, coat] { item.isEquipped = true }
        _ = spare

        #expect(view.viewedInventory === inventory)
        #expect(view.viewedItems.map(\.name) == ["Dague", "Sabre"])
        sword.isEquipped = false
        #expect(view.viewedItems.map(\.name) == ["Dague"])
    }

    /// Template de pirate complet : poids, paliers, monnaies, types, objets, contenant, valeurs, vue.
    private func pirateTemplate(_ context: ModelContext) throws -> SheetTemplate {
        let (template, inventory) = try sheetWithInventory(context)
        inventory.tracksWeight = true
        inventory.weightUnit = "lb"
        inventory.weightLimitFormula = "=FOR*3"
        inventory.appliesMalus = true
        inventory.addLevel(name: "Chargé", threshold: "=BESACE.limite", malus: -10, effect: "Nage impossible", in: context)
        let silver = inventory.addCurrency(name: "Réal", abbreviation: "r", rate: 8, in: context)
        let weapon = try #require(inventory.itemType(code: "arme"))
        weapon.addProperty(label: "%", kind: .percentage, code: "pct", in: context).numberValue = 25
        weapon.addProperty(label: "Exp.", kind: .checkbox, code: "exp", in: context).isLive = true
        let onSelf = try #require(inventory.sortedSlots.first)
        let ship = inventory.addSlot(name: "Bateau", icon: "sailboat", in: context)
        ship.countsTowardEncumbrance = false
        ship.capacity = 2000
        let pistol = onSelf.addItem(named: "Pistolet", type: weapon, context: context)
        pistol.isEquipped = true
        pistol.unitWeight = 3
        pistol.price = "15 r"
        pistol.summary = "Un coup, puis à recharger."
        pistol.imageData = Data([1, 2, 3])
        pistol.editableValue(for: try #require(weapon.property(code: "pct")), in: context).apply(45)
        pistol.editableValue(for: try #require(weapon.property(code: "degats")), in: context).apply("1d10")
        let purse = onSelf.addItem(named: "Bourse", context: context)
        purse.setContainer(true)
        onSelf.addMoney(silver, amount: 12, in: purse, context: context)
        ship.addItem(named: "Canon", quantity: 6, context: context).unitWeight = 300
        let view = try #require(template.sheet?.addPage(title: "Combat", in: context)).addRow(in: context)
            .addSection(title: "Armes", kind: .inventoryView, in: context)
        view.viewTypeCodes = ["arme"]
        view.viewPropertyCodes = ["pct", "degats"]
        return template
    }

    @Test("Un personnage reçoit une copie de la Besace du template : l'équipement de départ")
    func characterCopiesInventory() throws {
        let context = try makeContext()
        let template = try pirateTemplate(context)
        let before = try EntityCounts(context)
        let character = template.makeCharacter(named: "Anne", in: context)
        let after = try EntityCounts(context)

        for key in ["Inventory", "ItemType", "ItemProperty", "InventoryItem", "ItemPropertyValue",
                    "Currency", "InventorySlot", "EncumbranceLevel"] {
            #expect(after[key] == before[key] * 2, "\(key) : \(before[key]) → \(after[key])")
        }
        #expect(signature(of: character.sheet) == signature(of: template.sheet))
        let copy = try #require(character.sheet?.inventories.first)
        #expect(copy.formattedMoney == "12 r")
        #expect(FormulaEngine(sheet: character.sheet).level(of: copy)?.name == nil)

        // Le personnage vit sa vie : le template ne bouge pas.
        copy.allItems.first { $0.name == "Pistolet" }?.quantity = 2
        #expect(template.sheet?.inventories.first?.allItems.first { $0.name == "Pistolet" }?.quantity == 1)
    }

    @Test("Export / import : la Besace fait l'aller-retour sans perte")
    func exportRoundTrip() throws {
        let context = try makeContext()
        let template = try pirateTemplate(context)
        let character = template.makeCharacter(named: "Anne", in: context)
        let data = try SheetDocument(character: character, exportedAt: Date(timeIntervalSince1970: 0)).jsonData()
        let decoded = try SheetDocument.decode(data)
        #expect(decoded.version == 2)
        #expect(try decoded.jsonData() == data)

        let other = try makeContext()
        guard case .character(let imported) = try decoded.insert(into: other) else {
            Issue.record("pas un personnage"); return
        }
        #expect(signature(of: imported.sheet) == signature(of: character.sheet))
        #expect(try SheetDocument(character: imported, exportedAt: Date(timeIntervalSince1970: 0)).jsonData() == data)
    }

    @Test("Ordre des types, monnaies et emplacements : glisser, monter, descendre")
    func reordering() throws {
        let context = try makeContext()
        let (_, inventory) = try sheetWithInventory(context)
        inventory.addSlot(name: "Monture", in: context)
        inventory.addSlot(name: "Bateau", in: context)
        #expect(inventory.sortedSlots.map(\.name) == ["Sur soi", "Monture", "Bateau"])

        // Glisser « Bateau » en tête.
        InventoryOrder.move(inventory.sortedSlots, fromOffsets: [2], toOffset: 0)
        #expect(inventory.sortedSlots.map(\.name) == ["Bateau", "Sur soi", "Monture"])
        // Glisser « Bateau » à la fin (décalage SwiftUI : position après le dernier).
        InventoryOrder.move(inventory.sortedSlots, fromOffsets: [0], toOffset: 3)
        #expect(inventory.sortedSlots.map(\.name) == ["Sur soi", "Monture", "Bateau"])
        #expect(inventory.sortedSlots.map(\.order) == [0, 1, 2])

        let types = inventory.sortedItemTypes
        let weapon = try #require(inventory.itemType(code: "arme"))
        #expect(!InventoryOrder.canMove(types[0], by: -1, in: types))
        InventoryOrder.move(weapon, by: -1, in: types)
        #expect(inventory.sortedItemTypes.prefix(2).map(\.code) == ["arme", "argent"])
        InventoryOrder.move(weapon, by: 1, in: inventory.sortedItemTypes)
        InventoryOrder.move(weapon, by: 1, in: inventory.sortedItemTypes)
        #expect(inventory.sortedItemTypes.prefix(3).map(\.code) == ["argent", "armure", "arme"])

        let silver = inventory.addCurrency(name: "Pièce d'argent", abbreviation: "pa", rate: 10, in: context)
        InventoryOrder.move(silver, by: -1, in: inventory.sortedCurrencies)
        #expect(inventory.sortedCurrencies.map(\.abbreviation) == ["pa", "po"])
        #expect(!InventoryOrder.canMove(silver, by: -1, in: inventory.sortedCurrencies))
    }
}
