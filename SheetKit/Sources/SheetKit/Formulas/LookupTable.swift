import Foundation

/// Table de correspondance telle que l'éditeur la présente : une valeur à chercher, des lignes
/// « jusqu'à … → résultat », et un résultat « au-delà » facultatif. Elle s'écrit en formule :
/// `=table(FOR+TAI; 12; "-1d6"; 16; "-1d4"; 24; "aucun")`.
public struct LookupTable: Equatable, Sendable {
    public struct Row: Equatable, Sendable {
        /// Seuil, compris (« jusqu'à 12 »).
        public var upTo: Double?
        /// Ce qu'affiche le champ : un nombre ou un texte (« +1d4 »).
        public var result: String

        public init(upTo: Double?, result: String) {
            self.upTo = upTo
            self.result = result
        }
    }

    /// Valeur cherchée, en formule sans `=` (« FOR+TAI »).
    public var input: String
    public var rows: [Row]
    /// Résultat au-delà du dernier seuil ; vide : rien.
    public var otherwise: String

    public init(input: String = "", rows: [Row] = [], otherwise: String = "") {
        self.input = input
        self.rows = rows
        self.otherwise = otherwise
    }

    /// Lit une formule `=table(…)` dont les seuils sont des nombres et les résultats des nombres
    /// ou des textes ; nil pour toute autre formule.
    public init?(formula: String) {
        guard case .call(let name, let arguments)? = try? FormulaExpression.parse(formula),
              ["table", "lookup"].contains(name.lowercased()), arguments.count >= 3 else { return nil }
        let rest = Array(arguments.dropFirst())
        var rows: [Row] = []
        for index in 0..<(rest.count / 2) {
            guard let threshold = Self.number(rest[2 * index]),
                  let result = Self.result(rest[2 * index + 1]) else { return nil }
            rows.append(Row(upTo: threshold, result: result))
        }
        var otherwise = ""
        if rest.count % 2 == 1 {
            guard let result = Self.result(rest[rest.count - 1]) else { return nil }
            otherwise = result
        }
        self.init(input: arguments[0].source, rows: rows, otherwise: otherwise)
    }

    /// Formule `=table(…)`, lignes sans seuil ignorées ; nil sans valeur cherchée ou sans ligne.
    public var formula: String? {
        let input = input.trimmingCharacters(in: .whitespaces)
        let rows = rows.filter { $0.upTo != nil }
        guard !input.isEmpty, !rows.isEmpty else { return nil }
        var parts = [input.hasPrefix("=") ? String(input.dropFirst()) : input]
        for row in rows {
            parts.append(FormulaExpression.number(row.upTo!).source)
            parts.append(Self.literal(row.result))
        }
        if !otherwise.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(Self.literal(otherwise))
        }
        return "=table(" + parts.joined(separator: "; ") + ")"
    }

    /// Un résultat qui se lit comme un nombre (« 0 », « 2 », « -1 ») s'écrit en nombre ; sinon en texte.
    private static func literal(_ result: String) -> String {
        let trimmed = result.trimmingCharacters(in: .whitespaces)
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "−", with: "-")
        if !trimmed.hasPrefix("+"), let number = Double(normalized) {
            return (number < 0 ? FormulaExpression.negate(.number(-number)) : .number(number)).source
        }
        return FormulaExpression.text(trimmed).source
    }

    private static func number(_ expression: FormulaExpression) -> Double? {
        switch expression {
        case .number(let value): value
        case .negate(.number(let value)): -value
        default: nil
        }
    }

    private static func result(_ expression: FormulaExpression) -> String? {
        switch expression {
        case .text(let text): text
        case .number, .negate(.number): number(expression).map(NumberText.string)
        default: nil
        }
    }
}
