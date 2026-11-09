import Foundation

// Formules de tableur (SPEC §5.6) : `=FOR*5`, `=plafond((CON+TAI)/2)`, `=PV.max/2`, `=valeur/2`,
// `=table(FOR+TAI; 12; "-1d6"; 16; "-1d4"; 24; "aucun")`.
//
// Grammaire :
//   expression := terme (("+" | "-") terme)*
//   terme      := unaire (("*" | "/") unaire)*
//   unaire     := ("-" | "+") unaire | primaire
//   primaire   := nombre | texte | référence | fonction "(" arguments ")" | "(" expression ")"
//   texte      := "…" (guillemets droits, “…” ou « … » ; "" pour un guillemet dans un texte droit)
//   référence  := identifiant ("." identifiant)?          ex. FOR, PV.max, valeur
//   arguments  := expression ((";" | ",") expression)*
//
// Les opérateurs typographiques × ÷ − sont acceptés. Décimales : `1.5`, ou `1,5` (une virgule
// suivie d'un chiffre fait partie du nombre ; séparer les arguments par « ; » pour lever le doute).

/// Erreur de formule, affichée dans le champ sans bloquer la fiche.
public enum FormulaError: Error, Equatable, Sendable {
    case syntax(String)
    case unknownReference(String)
    case unknownFunction(String)
    case argumentCount(function: String, expected: String)
    case circularReference
    case divisionByZero
    /// Texte utilisé dans un calcul (« +1d4 » × 2).
    case notANumber(String)

    /// Message court en français.
    public var message: String {
        switch self {
        case .syntax(let detail): "Formule invalide : \(detail)"
        case .unknownReference(let name): "Code inconnu : \(name)"
        case .unknownFunction(let name): "Fonction inconnue : \(name)"
        case .argumentCount(let function, let expected): "\(function) attend \(expected)"
        case .circularReference: "Référence circulaire"
        case .divisionByZero: "Division par zéro"
        case .notANumber(let text): "Valeur non numérique : \(text)"
        }
    }
}

/// Résultat d'un calcul : un nombre, rien (une valeur dont il dépend n'est pas saisie), ou une erreur.
public typealias FormulaResult = Result<Double?, FormulaError>

/// Valeur d'une formule : un nombre, ou un texte (résultat d'une table : « +1d4 »).
public enum FormulaValue: Equatable, Sendable {
    case number(Double)
    case text(String)
}

/// Résultat d'un calcul qui peut donner du texte.
public typealias FormulaValueResult = Result<FormulaValue?, FormulaError>

extension Result where Success == FormulaValue?, Failure == FormulaError {
    /// Résultat numérique : un texte qui se lit comme un nombre (« 2 », « +2 ») en est un ;
    /// un autre texte (« +1d4 ») est une erreur.
    public var numeric: FormulaResult {
        flatMap { value in
            switch value {
            case nil: .success(nil)
            case .number(let number)?: .success(number)
            case .text(let text)?:
                if let number = ListImport.number(from: text) { .success(number) } else { .failure(.notANumber(text)) }
            }
        }
    }
}

extension Result where Success == Double?, Failure == FormulaError {
    /// Le même résultat, en valeur de formule.
    public var asValue: FormulaValueResult { map { $0.map(FormulaValue.number) } }
}

/// Arbre d'une formule analysée.
public indirect enum FormulaExpression: Equatable, Sendable {
    case number(Double)
    case text(String)
    /// `FOR` (member nil) ou `PV.max` (member "max").
    case reference(String, member: String?)
    case negate(FormulaExpression)
    case binary(FormulaOperator, FormulaExpression, FormulaExpression)
    case call(String, [FormulaExpression])

    /// Analyse une formule ; le `=` initial est facultatif.
    public static func parse(_ text: String) throws(FormulaError) -> FormulaExpression {
        var parser = FormulaParser(tokens: try FormulaLexer.tokens(of: text))
        return try parser.parseFormula()
    }

    /// Références utilisées, dans l'ordre d'apparition.
    public var references: [String] {
        switch self {
        case .number, .text: []
        case .reference(let name, let member): [member.map { "\(name).\($0)" } ?? name]
        case .negate(let operand): operand.references
        case .binary(_, let left, let right): left.references + right.references
        case .call(_, let arguments): arguments.flatMap(\.references)
        }
    }
}

// MARK: - Écriture

extension FormulaExpression {
    /// Formule écrite (sans le `=`), relisible par `parse` : nombres avec un point décimal,
    /// arguments séparés par « ; », parenthèses seulement là où il en faut.
    public var source: String { written(minimumPrecedence: 0) }

    private func written(minimumPrecedence: Int) -> String {
        switch self {
        case .number(let value):
            return value.rounded() == value && abs(value) < 1e15 ? String(Int(value)) : String(value)
        case .text(let text):
            return "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        case .reference(let name, let member):
            return member.map { "\(name).\($0)" } ?? name
        case .negate(let operand):
            return "-" + operand.written(minimumPrecedence: 3)
        case .binary(let operation, let left, let right):
            let precedence = operation == .add || operation == .subtract ? 1 : 2
            let text = left.written(minimumPrecedence: precedence) + String(operation.rawValue)
                + right.written(minimumPrecedence: precedence + 1)
            return precedence < minimumPrecedence ? "(\(text))" : text
        case .call(let name, let arguments):
            return "\(name)(" + arguments.map { $0.written(minimumPrecedence: 0) }.joined(separator: "; ") + ")"
        }
    }
}

public enum FormulaOperator: Character, Sendable {
    case add = "+"
    case subtract = "-"
    case multiply = "*"
    case divide = "/"
}

// MARK: - Analyse lexicale

enum FormulaToken: Equatable {
    case number(Double)
    case identifier(String)
    case text(String)
    case symbol(Character)
}

enum FormulaLexer {
    static func tokens(of text: String) throws(FormulaError) -> [FormulaToken] {
        var characters = Array(text.trimmingCharacters(in: .whitespacesAndNewlines))
        if characters.first == "=" { characters.removeFirst() }
        guard characters.contains(where: { !$0.isWhitespace }) else { throw .syntax("formule vide") }

        var tokens: [FormulaToken] = []
        var index = 0
        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace {
                index += 1
            } else if character.isNumber || (character == "." && index + 1 < characters.count && characters[index + 1].isNumber) {
                var literal = ""
                while index < characters.count {
                    let current = characters[index]
                    let nextIsDigit = index + 1 < characters.count && characters[index + 1].isNumber
                    if current.isNumber {
                        literal.append(current)
                    } else if (current == "." || current == ","), nextIsDigit, !literal.contains(".") {
                        literal.append(".")
                    } else {
                        break
                    }
                    index += 1
                }
                guard let value = Double(literal) else { throw .syntax("nombre « \(literal) »") }
                tokens.append(.number(value))
            } else if let closing = Self.closingQuote[character] {
                // Texte : jusqu'au guillemet fermant ; "" dans un texte entre guillemets droits.
                var text = ""
                index += 1
                while true {
                    guard index < characters.count else { throw .syntax("guillemet fermant manquant") }
                    let current = characters[index]
                    index += 1
                    if current == closing {
                        if closing == "\"", index < characters.count, characters[index] == "\"" {
                            text.append("\"")
                            index += 1
                        } else {
                            break
                        }
                    } else {
                        text.append(current)
                    }
                }
                tokens.append(.text(text.trimmingCharacters(in: .whitespaces)))
            } else if character.isLetter || character == "_" {
                var name = ""
                while index < characters.count, characters[index].isLetter || characters[index].isNumber || characters[index] == "_" {
                    name.append(characters[index])
                    index += 1
                }
                tokens.append(.identifier(name))
            } else {
                let symbol: Character = switch character {
                case "×", "·": "*"
                case "÷", ":": "/"
                case "−", "–": "-"
                default: character
                }
                guard "+-*/().;,".contains(symbol) else { throw .syntax("caractère « \(character) »") }
                tokens.append(.symbol(symbol))
                index += 1
            }
        }
        return tokens
    }

    /// Guillemets ouvrants et leur fermant.
    static let closingQuote: [Character: Character] = ["\"": "\"", "“": "”", "«": "»"]
}

// MARK: - Analyse syntaxique

struct FormulaParser {
    let tokens: [FormulaToken]
    var position = 0

    init(tokens: [FormulaToken]) {
        self.tokens = tokens
    }

    private var current: FormulaToken? { position < tokens.count ? tokens[position] : nil }

    private mutating func take(_ symbol: Character) -> Bool {
        if current == .symbol(symbol) {
            position += 1
            return true
        }
        return false
    }

    mutating func parseFormula() throws(FormulaError) -> FormulaExpression {
        let expression = try parseExpression()
        if let token = current {
            throw .syntax("« \(Self.describe(token)) » inattendu")
        }
        return expression
    }

    private mutating func parseExpression() throws(FormulaError) -> FormulaExpression {
        var result = try parseTerm()
        while true {
            if take("+") {
                result = .binary(.add, result, try parseTerm())
            } else if take("-") {
                result = .binary(.subtract, result, try parseTerm())
            } else {
                return result
            }
        }
    }

    private mutating func parseTerm() throws(FormulaError) -> FormulaExpression {
        var result = try parseUnary()
        while true {
            if take("*") {
                result = .binary(.multiply, result, try parseUnary())
            } else if take("/") {
                result = .binary(.divide, result, try parseUnary())
            } else {
                return result
            }
        }
    }

    private mutating func parseUnary() throws(FormulaError) -> FormulaExpression {
        if take("-") { return .negate(try parseUnary()) }
        if take("+") { return try parseUnary() }
        return try parsePrimary()
    }

    private mutating func parsePrimary() throws(FormulaError) -> FormulaExpression {
        guard let token = current else { throw .syntax("formule incomplète") }
        position += 1
        switch token {
        case .number(let value):
            return .number(value)
        case .text(let text):
            return .text(text)
        case .identifier(let name):
            if take("(") {
                var arguments: [FormulaExpression] = []
                if !take(")") {
                    repeat {
                        arguments.append(try parseExpression())
                    } while take(";") || take(",")
                    guard take(")") else { throw .syntax("« ) » manquante après \(name)") }
                }
                return .call(name, arguments)
            }
            if take(".") {
                guard case .identifier(let member)? = current else { throw .syntax("nom attendu après « \(name). »") }
                position += 1
                return .reference(name, member: member)
            }
            return .reference(name, member: nil)
        case .symbol("("):
            let inner = try parseExpression()
            guard take(")") else { throw .syntax("« ) » manquante") }
            return inner
        case .symbol:
            throw .syntax("« \(Self.describe(token)) » inattendu")
        }
    }

    static func describe(_ token: FormulaToken) -> String {
        switch token {
        case .number(let value): NumberText.string(value)
        case .identifier(let name): name
        case .text(let text): "\"\(text)\""
        case .symbol(let symbol): String(symbol)
        }
    }
}

// MARK: - Évaluation

extension FormulaExpression {
    /// Évalue l'expression ; `resolve` fournit la valeur d'une référence (`nil` : non saisie).
    /// Une valeur manquante rend le résultat manquant, sans erreur.
    public func evaluate(resolve: (String, String?) -> FormulaResult) -> FormulaResult {
        evaluateValue { resolve($0, $1).asValue }.numeric
    }

    /// Évalue l'expression en gardant un résultat texte (table de correspondance).
    public func evaluateValue(resolve: (String, String?) -> FormulaValueResult) -> FormulaValueResult {
        switch self {
        case .number(let value):
            return .success(.number(value))
        case .text(let text):
            return .success(.text(text))
        case .reference(let name, let member):
            return resolve(name, member)
        case .negate(let operand):
            return operand.evaluateValue(resolve: resolve).numeric.map { $0.map { -$0 } }.asValue
        case .binary(let operation, let left, let right):
            let lhs = left.evaluateValue(resolve: resolve).numeric
            let rhs = right.evaluateValue(resolve: resolve).numeric
            switch (lhs, rhs) {
            case (.failure(let error), _), (_, .failure(let error)):
                return .failure(error)
            case (.success(let a?), .success(let b?)):
                switch operation {
                case .add: return .success(.number(a + b))
                case .subtract: return .success(.number(a - b))
                case .multiply: return .success(.number(a * b))
                case .divide: return b == 0 ? .failure(.divisionByZero) : .success(.number(a / b))
                }
            default:
                return .success(nil)
            }
        case .call(let name, let arguments):
            var values: [FormulaValue?] = []
            for argument in arguments {
                switch argument.evaluateValue(resolve: resolve) {
                case .failure(let error): return .failure(error)
                case .success(let value): values.append(value)
                }
            }
            return FormulaFunction.call(name, values)
        }
    }
}

/// Fonctions disponibles (noms français, alias anglais).
enum FormulaFunction {
    static func call(_ name: String, _ values: [FormulaValue?]) -> FormulaValueResult {
        let key = name.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        if key == "table" || key == "lookup" {
            return table(name, values)
        }
        // Les autres fonctions calculent sur des nombres.
        var numbers: [Double?] = []
        for value in values {
            switch numeric(value) {
            case .failure(let error): return .failure(error)
            case .success(let number): numbers.append(number)
            }
        }
        return numeric(name, key, numbers).asValue
    }

    /// `table(valeur; seuil1; résultat1; seuil2; résultat2; …; [au-delà])` : le résultat du premier
    /// seuil supérieur ou égal à la valeur (« jusqu'à »), sinon le résultat « au-delà » s'il est donné.
    private static func table(_ name: String, _ values: [FormulaValue?]) -> FormulaValueResult {
        guard values.count >= 3 else {
            return .failure(.argumentCount(function: name, expected: "une valeur, puis des paires seuil ; résultat"))
        }
        let number: Double
        switch numeric(values[0]) {
        case .failure(let error): return .failure(error)
        case .success(nil): return .success(nil)
        case .success(let value?): number = value
        }
        let rest = Array(values.dropFirst())
        let pairs = rest.count / 2
        for index in 0..<pairs {
            switch numeric(rest[2 * index]) {
            case .failure(let error):
                return .failure(error)
            case .success(nil):
                return .success(nil)
            case .success(let threshold?):
                if number <= threshold { return .success(rest[2 * index + 1]) }
            }
        }
        return .success(rest.count % 2 == 1 ? rest[rest.count - 1] : nil)
    }

    /// Une valeur en nombre (texte numérique accepté, autre texte en erreur).
    private static func numeric(_ value: FormulaValue?) -> FormulaResult {
        FormulaValueResult.success(value).numeric
    }

    private static func numeric(_ name: String, _ key: String, _ values: [Double?]) -> FormulaResult {
        func one(_ transform: (Double) -> Double) -> FormulaResult {
            guard values.count == 1 else { return .failure(.argumentCount(function: name, expected: "1 valeur")) }
            return .success(values[0].map(transform))
        }
        switch key {
        case "plafond", "ceil", "ceiling":
            return one { $0.rounded(.up) }
        case "plancher", "floor":
            return one { $0.rounded(.down) }
        case "abs":
            return one { abs($0) }
        case "arrondi", "round":
            guard (1...2).contains(values.count) else {
                return .failure(.argumentCount(function: name, expected: "1 ou 2 valeurs"))
            }
            guard let value = values[0] else { return .success(nil) }
            let digits = values.count == 2 ? (values[1] ?? 0) : 0
            let factor = pow(10, digits.rounded())
            return .success((value * factor).rounded(.toNearestOrAwayFromZero) / factor)
        case "min", "max":
            guard !values.isEmpty else { return .failure(.argumentCount(function: name, expected: "au moins 1 valeur")) }
            let numbers = values.compactMap { $0 }
            guard numbers.count == values.count else { return .success(nil) }
            return .success(key == "min" ? numbers.min() : numbers.max())
        default:
            return .failure(.unknownFunction(name))
        }
    }
}
