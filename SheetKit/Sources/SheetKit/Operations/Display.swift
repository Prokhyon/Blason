import Foundation

// Mise en forme des valeurs pour l'affichage en lecture.
// Valeurs saisies seulement : les valeurs calculées passent par `FormulaEngine`.

enum NumberText {
    static func string(_ value: Double) -> String {
        if value.rounded() == value, abs(value) < 1e15 {
            return String(Int(value))
        }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func signed(_ value: Double) -> String {
        value > 0 ? "+\(string(value))" : string(value).replacingOccurrences(of: "-", with: "−")
    }
}

extension SheetField {
    /// Valeur lisible : « 14 / 14 », « 55 % », « +2 », « ☑ »…
    public var displayValue: String {
        switch kind {
        case .text, .longText, .choice:
            return textValue ?? ""
        case .integer, .decimal:
            return numberValue.map(NumberText.string) ?? ""
        case .percentage:
            return numberValue.map { "\(NumberText.string($0)) %" } ?? ""
        case .modifier:
            if let numberValue { return NumberText.signed(numberValue) }
            return textValue ?? ""
        case .resource:
            switch (numberValue, resourceMax) {
            case let (current?, max?): return "\(NumberText.string(current)) / \(NumberText.string(max))"
            case let (current?, nil): return NumberText.string(current)
            case let (nil, max?): return "– / \(NumberText.string(max))"
            case (nil, nil): return formula.map { "max \($0)" } ?? ""
            }
        case .checkbox:
            return boolValue == true ? "☑" : "☐"
        case .date:
            return dateValue?.formatted(date: .abbreviated, time: .omitted) ?? ""
        case .image:
            return imageData == nil ? "" : "Image"
        case .formula:
            return formula ?? ""
        }
    }
}

extension SheetTableCell {
    /// Valeur lisible selon le type de la colonne. Une formule s'affiche si aucune valeur n'est saisie.
    public var displayValue: String {
        switch column?.kind ?? .text {
        case .text:
            return textValue ?? formula ?? ""
        case .number:
            return numberValue.map(NumberText.string) ?? formula ?? ""
        case .percentage:
            return numberValue.map { "\(NumberText.string($0)) %" } ?? formula ?? ""
        case .checkbox:
            return boolValue == true ? "☑" : "☐"
        case .formula:
            return formula ?? column?.formula ?? ""
        }
    }
}
