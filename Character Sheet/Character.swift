import Foundation
import SwiftData

@Model
class Character: Identifiable {
    var id: UUID
    var firstName: String?
    var lastName: String?
    var age: Int?

    var layout: CharacterLayout?

    @Relationship(deleteRule: .cascade)
    var fieldValues: [CharacterFieldValue] = []

    var creationDate: Date
    var lastEditedDate: Date

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

    init(id: UUID = UUID(), firstName: String? = nil, lastName: String? = nil, age: Int? = nil, layout: CharacterLayout? = nil, creationDate: Date = Date(), lastEditedDate: Date = Date()) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.age = age
        self.layout = layout
        self.creationDate = creationDate
        self.lastEditedDate = lastEditedDate
    }

    func ensureFieldValues() {
        guard let layout else { return }
        for section in layout.sections {
            for field in section.fields {
                if !fieldValues.contains(where: { $0.fieldID == field.id }) {
                    fieldValues.append(CharacterFieldValue(fieldID: field.id, value: field.defaultValue))
                }
            }
        }
    }

    func value(for field: Field) -> CharacterFieldValue? {
        fieldValues.first { $0.fieldID == field.id }
    }
}

@Model
class CharacterLayout: Identifiable {
    var id: UUID
    var name: String
    var gameSystem: String?
    var isTemplate: Bool
    var gridColumns: Int

    @Relationship(deleteRule: .cascade)
    var sections: [LayoutSection] = []

    @Relationship(inverse: \Character.layout)
    var characters: [Character] = []

    var sortedSections: [LayoutSection] {
        sections.sorted { $0.order < $1.order }
    }

    init(id: UUID = UUID(), name: String = "New Layout", gameSystem: String? = nil, isTemplate: Bool = false, gridColumns: Int = 3, sections: [LayoutSection] = []) {
        self.id = id
        self.name = name
        self.gameSystem = gameSystem
        self.isTemplate = isTemplate
        self.gridColumns = gridColumns
        self.sections = sections
    }

    func recalculateGrid() {
        let sorted = sortedSections
        var occupied: [GridPosition: Bool] = [:]
        var currentRow = 0
        var currentColumn = 0

        func advance() {
            currentColumn = (currentColumn + 1) % gridColumns
            if currentColumn == 0 { currentRow += 1 }
            while occupied[GridPosition(x: currentColumn, y: currentRow)] == true {
                currentColumn = (currentColumn + 1) % gridColumns
                if currentColumn == 0 { currentRow += 1 }
            }
        }

        func canPlace(width: Int, height: Int) -> Bool {
            for dx in 0..<width {
                for dy in 0..<height {
                    if currentColumn + dx >= gridColumns { return false }
                    if occupied[GridPosition(x: currentColumn + dx, y: currentRow + dy)] == true {
                        return false
                    }
                }
            }
            return true
        }

        func place(section: LayoutSection) {
            for dx in 0..<section.width {
                for dy in 0..<section.height {
                    occupied[GridPosition(x: currentColumn + dx, y: currentRow + dy)] = true
                }
            }
            section.gridOrigin = GridPosition(x: currentColumn, y: currentRow)
        }

        for (index, section) in sorted.enumerated() {
            while !canPlace(width: section.width, height: section.height) {
                advance()
            }
            place(section: section)
            if index < sorted.count - 1 {
                advance()
            }
        }
    }

    func renumberSections() {
        for (idx, section) in sortedSections.enumerated() {
            section.order = idx
        }
    }
}

@Model
class LayoutSection: Identifiable {
    var id: UUID
    var title: String
    var order: Int
    var width: Int
    var height: Int
    var gridOrigin: GridPosition
    var sectionLayout: SectionLayout
    var columnCount: Int?

    @Relationship(deleteRule: .cascade)
    var fields: [Field] = []

    var sortedFields: [Field] {
        fields.sorted { $0.order < $1.order }
    }

    var gridPlacement: GridPlacement {
        GridPlacement(gridOrigin: gridOrigin, width: width, height: height)
    }

    init(id: UUID = UUID(), title: String = "New Section", order: Int = 0, width: Int = 1, height: Int = 1, gridOrigin: GridPosition = GridPosition(x: 0, y: 0), sectionLayout: SectionLayout = .list, fields: [Field] = []) {
        self.id = id
        self.title = title
        self.order = order
        self.width = width
        self.height = height
        self.gridOrigin = gridOrigin
        self.sectionLayout = sectionLayout
        self.fields = fields
    }

    func renumberFields() {
        if sectionLayout == .multiList {
            let listCount = max(1, columnCount ?? 2)
            for col in 0..<listCount {
                let colFields = fields.filter { $0.multilistColumn == col }.sorted { $0.order < $1.order }
                for (idx, field) in colFields.enumerated() {
                    field.order = idx
                }
            }
        } else {
            for (idx, field) in sortedFields.enumerated() {
                field.order = idx
            }
        }
    }
}

nonisolated enum SectionLayout: String, Codable, CaseIterable {
    case list
    case grid
    case multiList

    var displayName: String {
        switch self {
        case .list: return "List"
        case .grid: return "Grid"
        case .multiList: return "Multi-List"
        }
    }
}

@Model
class Field: Identifiable {
    var id: UUID
    var label: String
    var order: Int
    var kind: FieldKind
    var unit: String?
    var fieldLayout: FieldLayout
    var minValue: Int?
    var maxValue: Int?
    var displayMaxValue: Bool = false
    var step: Int?
    var defaultValue: String?
    var hint: String?
    var options: [String]?
    var liveValue: Bool
    var multilistColumn: Int = 0

    init(id: UUID = UUID(), label: String = "New Field", order: Int = 0, kind: FieldKind = .text, unit: String? = nil, fieldLayout: FieldLayout = .horizontal, minValue: Int? = nil, maxValue: Int? = nil, displayMaxValue: Bool = false, step: Int? = nil, defaultValue: String? = nil, hint: String? = nil, options: [String]? = nil, liveValue: Bool = false, column: Int = 0) {
        self.id = id
        self.label = label
        self.order = order
        self.kind = kind
        self.unit = unit
        self.fieldLayout = fieldLayout
        self.minValue = minValue
        self.maxValue = maxValue
        self.displayMaxValue = displayMaxValue
        self.step = step
        self.defaultValue = defaultValue
        self.hint = hint
        self.options = options
        self.liveValue = liveValue
        self.multilistColumn = column
    }
}

nonisolated enum FieldKind: String, Codable, CaseIterable {
    case text
    case integer
    case decimal
    case modifier
    case boolean
    case date
    case note
}

nonisolated enum FieldLayout: String, Codable, CaseIterable {
    case horizontal
    case vertical
}

@Model
class CharacterFieldValue: Identifiable {
    var id: UUID
    var fieldID: UUID
    var value: String?

    init(id: UUID = UUID(), fieldID: UUID, value: String? = nil) {
        self.id = id
        self.fieldID = fieldID
        self.value = value
    }
}

nonisolated struct GridPosition: Codable, Hashable {
    var x: Int
    var y: Int

    init(x: Int = 0, y: Int = 0) {
        self.x = x
        self.y = y
    }
}
