import Foundation
import SwiftData

// Copie profonde d'une fiche. Chaque objet créé est inséré dans le contexte avant d'être
// rattaché à son parent (en affectant la relation côté enfant).

extension Sheet {
    /// Copie complète : pages, rangées, sections, champs, colonnes, groupes, lignes et cellules,
    /// valeurs comprises. La copie n'est rattachée à aucun template ni personnage.
    public func deepCopy(in context: ModelContext) -> Sheet {
        let copy = Sheet()
        context.insert(copy)
        copy.themeID = themeID
        copy.themeColor = themeColor
        for page in sortedPages {
            page.copy(into: copy, in: context)
        }
        return copy
    }
}

extension Page {
    @discardableResult
    func copy(into sheet: Sheet, in context: ModelContext) -> Page {
        let copy = Page(title: title, order: order)
        context.insert(copy)
        copy.sheet = sheet
        for row in sortedRows {
            let rowCopy = SheetRow(order: row.order)
            context.insert(rowCopy)
            rowCopy.page = copy
            rowCopy.columnWeights = row.columnWeights
            for section in row.sortedSections {
                section.copy(into: rowCopy, in: context)
            }
        }
        return copy
    }
}

extension SheetSection {
    /// Copie la section (champs, colonnes, groupes, lignes et cellules) dans `row`.
    @discardableResult
    public func copy(into row: SheetRow, in context: ModelContext) -> SheetSection {
        let copy = SheetSection(title: title, kind: kind, order: order)
        context.insert(copy)
        copy.row = row
        copy.columnIndex = columnIndex
        copy.arrangementRaw = arrangementRaw
        copy.columnCount = columnCount
        copy.labelColumnTitle = labelColumnTitle
        copy.viewTypeCodes = viewTypeCodes
        copy.viewPropertyCodes = viewPropertyCodes
        if let inventory {
            inventory.copy(into: copy, in: context)
        }

        for field in sortedFields {
            field.copy(into: copy, in: context)
        }

        var columnMap: [ObjectIdentifier: SheetTableColumn] = [:]
        for column in sortedColumns {
            let columnCopy = SheetTableColumn(title: column.title, kind: column.kind, code: column.code, order: column.order)
            context.insert(columnCopy)
            columnCopy.section = copy
            columnCopy.formula = column.formula
            columnCopy.isLive = column.isLive
            columnMap[ObjectIdentifier(column)] = columnCopy
        }

        for group in sortedGroups {
            let groupCopy = SheetTableGroup(title: group.title, order: group.order, hasValue: group.hasValue)
            context.insert(groupCopy)
            groupCopy.section = copy
            groupCopy.numberValue = group.numberValue
            for tableRow in group.sortedRows {
                let rowCopy = SheetTableRow(label: tableRow.label, order: tableRow.order)
                context.insert(rowCopy)
                rowCopy.group = groupCopy
                rowCopy.specialization = tableRow.specialization
                rowCopy.allowsSpecialization = tableRow.allowsSpecialization
                rowCopy.isFromTemplate = tableRow.isFromTemplate
                for cell in tableRow.cells ?? [] {
                    let cellCopy = SheetTableCell()
                    context.insert(cellCopy)
                    cellCopy.row = rowCopy
                    cellCopy.column = cell.column.flatMap { columnMap[ObjectIdentifier($0)] }
                    cellCopy.textValue = cell.textValue
                    cellCopy.numberValue = cell.numberValue
                    cellCopy.boolValue = cell.boolValue
                    cellCopy.formula = cell.formula
                }
            }
        }
        return copy
    }
}

extension SheetField {
    /// Copie le champ (configuration et valeur) dans `section`.
    @discardableResult
    public func copy(into section: SheetSection, in context: ModelContext) -> SheetField {
        let copy = SheetField(label: label, kind: kind, code: code, order: order)
        context.insert(copy)
        copy.section = section
        copy.copyAttributes(from: self)
        return copy
    }

    /// Recopie tous les attributs (hors relations). À tenir à jour quand le modèle évolue.
    public func copyAttributes(from other: SheetField) {
        label = other.label
        code = other.code
        order = other.order
        kindRaw = other.kindRaw
        labelPlacementRaw = other.labelPlacementRaw
        widthRaw = other.widthRaw
        listIndex = other.listIndex
        isLive = other.isLive
        isNameField = other.isNameField
        unit = other.unit
        hint = other.hint
        minimum = other.minimum
        maximum = other.maximum
        step = other.step
        options = other.options
        resourceStyleRaw = other.resourceStyleRaw
        formula = other.formula
        textValue = other.textValue
        numberValue = other.numberValue
        resourceMax = other.resourceMax
        boolValue = other.boolValue
        dateValue = other.dateValue
        imageData = other.imageData
    }
}

extension Inventory {
    /// Copie la Besace (réglages, types et propriétés, monnaies, paliers, emplacements et objets,
    /// valeurs comprises) dans `section`.
    @discardableResult
    func copy(into section: SheetSection, in context: ModelContext) -> Inventory {
        let copy = Inventory()
        context.insert(copy)
        copy.section = section
        copy.code = code
        copy.tracksWeight = tracksWeight
        copy.weightUnit = weightUnit
        copy.weightLimitFormula = weightLimitFormula
        copy.appliesMalus = appliesMalus

        var types: [ObjectIdentifier: ItemType] = [:]
        var properties: [ObjectIdentifier: ItemProperty] = [:]
        for type in sortedItemTypes {
            let typeCopy = ItemType(name: type.name, code: type.code, icon: type.icon, order: type.order)
            context.insert(typeCopy)
            typeCopy.inventory = copy
            types[ObjectIdentifier(type)] = typeCopy
            for property in type.sortedProperties {
                let propertyCopy = ItemProperty(label: property.label, kind: property.kind, code: property.code, order: property.order)
                context.insert(propertyCopy)
                propertyCopy.type = typeCopy
                propertyCopy.formula = property.formula
                propertyCopy.isLive = property.isLive
                propertyCopy.textValue = property.textValue
                propertyCopy.numberValue = property.numberValue
                propertyCopy.boolValue = property.boolValue
                properties[ObjectIdentifier(property)] = propertyCopy
            }
        }

        var currencies: [ObjectIdentifier: Currency] = [:]
        for currency in sortedCurrencies {
            let currencyCopy = Currency(name: currency.name, abbreviation: currency.abbreviation, rate: currency.rate, order: currency.order)
            context.insert(currencyCopy)
            currencyCopy.inventory = copy
            currencies[ObjectIdentifier(currency)] = currencyCopy
        }

        for level in sortedLevels {
            let levelCopy = EncumbranceLevel(name: level.name, thresholdFormula: level.thresholdFormula, order: level.order)
            context.insert(levelCopy)
            levelCopy.inventory = copy
            levelCopy.malus = level.malus
            levelCopy.effect = level.effect
        }

        func copyItem(_ item: InventoryItem, slot: InventorySlot, container: InventoryItem?) -> InventoryItem {
            let itemCopy = InventoryItem(name: item.name, quantity: item.quantity, order: item.order)
            context.insert(itemCopy)
            itemCopy.slot = slot
            itemCopy.container = container
            itemCopy.unitWeight = item.unitWeight
            itemCopy.price = item.price
            itemCopy.isEquipped = item.isEquipped
            itemCopy.isContainer = item.isContainer
            itemCopy.summary = item.summary
            itemCopy.notes = item.notes
            itemCopy.imageData = item.imageData
            itemCopy.type = item.type.flatMap { types[ObjectIdentifier($0)] }
            itemCopy.currency = item.currency.flatMap { currencies[ObjectIdentifier($0)] }
            for value in item.propertyValues ?? [] {
                guard let property = value.property.flatMap({ properties[ObjectIdentifier($0)] }) else { continue }
                let valueCopy = ItemPropertyValue()
                context.insert(valueCopy)
                valueCopy.item = itemCopy
                valueCopy.property = property
                valueCopy.textValue = value.textValue
                valueCopy.numberValue = value.numberValue
                valueCopy.boolValue = value.boolValue
                valueCopy.formula = value.formula
            }
            return itemCopy
        }

        for slot in sortedSlots {
            let slotCopy = InventorySlot(name: slot.name, icon: slot.icon, order: slot.order)
            context.insert(slotCopy)
            slotCopy.inventory = copy
            slotCopy.countsTowardEncumbrance = slot.countsTowardEncumbrance
            slotCopy.capacity = slot.capacity
            for item in slot.looseItems {
                let itemCopy = copyItem(item, slot: slotCopy, container: nil)
                for content in item.sortedContents {
                    _ = copyItem(content, slot: slotCopy, container: itemCopy)
                }
            }
        }
        return copy
    }
}

// MARK: - Bibliothèque

extension SheetTemplate {
    /// Crée un template et sa fiche, et les insère. `firstPage` ajoute une première page
    /// (avec une rangée vide) pour que la fiche ne soit pas vide à l'ouverture.
    @discardableResult
    public static func create(
        name: String,
        system: String = "",
        firstPage: String? = nil,
        in context: ModelContext
    ) -> SheetTemplate {
        let template = SheetTemplate(name: name, system: system)
        context.insert(template)
        let sheet = Sheet()
        context.insert(sheet)
        template.sheet = sheet
        if let firstPage {
            sheet.addPage(title: firstPage, in: context).addRow(in: context)
        }
        return template
    }

    /// Renomme le template et met à jour le nom d'origine affiché par ses personnages.
    public func rename(to newName: String, in context: ModelContext) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        name = trimmed
        updatedAt = Date()
        let templateUID: UUID? = uid
        let descriptor = FetchDescriptor<PlayerCharacter>(
            predicate: #Predicate { $0.sourceTemplateUID == templateUID }
        )
        for character in try context.fetch(descriptor) {
            character.sourceTemplateName = trimmed
        }
    }

    /// Crée un personnage à partir d'une **copie** du template. Les modifications ultérieures
    /// du template n'affectent pas le personnage.
    @discardableResult
    public func makeCharacter(named name: String, in context: ModelContext) -> PlayerCharacter {
        let character = PlayerCharacter(name: name)
        context.insert(character)
        character.sourceTemplateUID = uid
        character.sourceTemplateName = self.name
        character.sheet = (sheet ?? Sheet()).deepCopy(in: context)
        character.sheet?.nameField?.textValue = name
        // Le personnage suit l'apparence de son template, même si elle change ensuite.
        character.sheet?.ownAppearance = nil
        return character
    }

    /// Duplique le template (structure et valeurs par défaut).
    @discardableResult
    public func duplicate(in context: ModelContext) -> SheetTemplate {
        let copy = SheetTemplate(name: "\(name) (copie)", system: system)
        context.insert(copy)
        copy.notes = notes
        copy.sheet = (sheet ?? Sheet()).deepCopy(in: context)
        return copy
    }
}

extension PlayerCharacter {
    /// Nom affiché : le champ « nom » de la fiche s'il est rempli, sinon `name`.
    public var displayName: String {
        if let value = sheet?.nameField?.textValue?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }
        return name.isEmpty ? "Personnage sans nom" : name
    }

    /// Crée un personnage sans template, avec une fiche d'une page vide.
    @discardableResult
    public static func createBlank(named name: String, in context: ModelContext) -> PlayerCharacter {
        let character = PlayerCharacter(name: name)
        context.insert(character)
        let sheet = Sheet()
        context.insert(sheet)
        character.sheet = sheet
        sheet.addPage(title: "Fiche", in: context).addRow(in: context)
        return character
    }

    /// Renomme le personnage, y compris le champ « nom » de sa fiche.
    public func rename(to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        name = trimmed
        sheet?.nameField?.textValue = trimmed
        touch()
    }

    /// Image du premier champ image rempli (portrait), pour la bibliothèque.
    public var portraitData: Data? {
        sheet?.allFields.first { $0.kind == .image && $0.imageData != nil }?.imageData
    }

    /// Duplique le personnage (structure et valeurs).
    @discardableResult
    public func duplicate(in context: ModelContext) -> PlayerCharacter {
        let copy = PlayerCharacter(name: "\(displayName) (copie)")
        context.insert(copy)
        copy.sourceTemplateUID = sourceTemplateUID
        copy.sourceTemplateName = sourceTemplateName
        copy.sheet = (sheet ?? Sheet()).deepCopy(in: context)
        copy.sheet?.nameField?.textValue = copy.name
        return copy
    }

    /// Crée un **nouveau** template à partir de la fiche du personnage.
    /// Les valeurs sont conservées et deviennent les valeurs par défaut du template.
    @discardableResult
    public func makeTemplate(named templateName: String, system: String = "", in context: ModelContext) -> SheetTemplate {
        let template = SheetTemplate(name: templateName, system: system)
        context.insert(template)
        template.sheet = (sheet ?? Sheet()).deepCopy(in: context)
        return template
    }

    /// Marque le personnage comme modifié (tri de la bibliothèque).
    public func touch() {
        updatedAt = Date()
    }
}
