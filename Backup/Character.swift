//
//  Character.swift
//  Character Sheet
//
//  Created by Loris Thomas on 11.04.2026.
//

import Foundation

class Character {
    var id : UUID
    var firstName: String?
    var lastName: String?
    var age: Int?
    
    // Template the character is based on (optional to allow free-form or legacy characters)
    var characterLayout: UUID?//CharacterLayout
    
    // Values for each field defined by the template (or ad‑hoc fields)
    var fieldValues: [CharacterFieldValue] = []
    
    var fullName: String {
        switch (firstName?.trimmingCharacters(in: .whitespacesAndNewlines),
                lastName?.trimmingCharacters(in: .whitespacesAndNewlines)) {
        case let (f?, l?) where !f.isEmpty && !l.isEmpty:
            return "\(f) \(l)"
        case let (f?, _) where !f.isEmpty:
            return f
        case let (_, l?) where !l.isEmpty:
            return l
        default:
            return "Unnamed Character"
        }
    }
    
    var creationDate: Date = Date()
    var lastEditedDate: Date = Date()
    
    init(id: UUID = UUID(), firstName: String? = nil, lastName: String? = nil, age: Int? = nil, characterLayout: UUID, fieldValues: [CharacterFieldValue] = [], creationDate: Date = Date(), lastEditedDate: Date = Date()) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
        self.characterLayout = characterLayout
        self.fieldValues = fieldValues
        self.creationDate = creationDate
        self.lastEditedDate = lastEditedDate
    }
    
}

class CharacterLayout {
    var id: UUID
    var name: String
    var gameSystem: String?
    var template: Bool
    
    var sections: [Section]
    
    init(id: UUID = UUID(), name: String = "New Template", gameSystem: String? = nil, template: Bool = false, sections: [Section] = []) {
        self.id = id
        self.name = name
        self.gameSystem = gameSystem
        self.template = template
        self.sections = sections
    }
}

class Section {
    var id = UUID()
    var title: String = "New Section"
    
    var order: Int
    var width: Int
    var height: Int
    
    var layout: SectionLayout
    var fields: [Field] = []
    
    init(id: UUID = UUID(), title: String, order: Int, width: Int, height: Int, layout: SectionLayout = .list, fields: [Field] = []) {
        self.id = id
        self.title = title
        self.order = order
        self.width = width
        self.height = height
        self.layout = layout
        self.fields = fields
    }
    
    func normalizeFieldOrder() {
        self.fields = self.fields.sorted { $0.order < $1.order }
        for (idx, field) in self.fields.enumerated() {
            field.order = idx
        }
    }
}

enum SectionLayout: String, Codable {
    case list
    case grid
}

class Field: Identifiable, Codable {
    var id = UUID()
    
    var label: String
    var order : Int
    
    var kind: FieldKind
    var minValue: Double?
    var maxValue: Double?
    var step: Double?
    
    var defaultValue: String?
    
    var options: [String]?
    
    var liveValue: Bool
    
    init(id: UUID = UUID(), label: String = "New Field", order: Int, kind: FieldKind, minValue: Double? = nil, maxValue: Double? = nil, step: Double? = nil, defaultValue: String? = nil, options: [String]? = nil, liveValue: Bool = false) {
        self.id = id
        self.label = label
        self.order = order
        self.kind = kind
        self.minValue = minValue
        self.maxValue = maxValue
        self.step = step
        self.defaultValue = defaultValue
        self.options = options
        self.liveValue = liveValue
    }
}

enum FieldKind: String, Codable {
    case text
    case integer
    case decimal
    case modifier
    case boolean
    case date
    case optional
    case multiOption
    case note
}

enum FieldLayout: String, Codable {
    case horizontal
    case vertical
}

class CharacterFieldValue {
    var id = UUID()
    
    var field: Field
    
    var value: String?
    
    init(field: Field, value: String? = nil) {
        self.field = field
        self.value = value
    }
}
