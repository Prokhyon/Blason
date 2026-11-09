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
