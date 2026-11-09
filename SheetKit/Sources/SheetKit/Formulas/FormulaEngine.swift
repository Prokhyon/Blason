import Foundation

// Calcul des valeurs d'une fiche (SPEC §5.6).
//
// Règles :
// - Champ « Calcul » : sa formule donne sa valeur, en lecture seule.
// - Autre champ numérique avec formule : la formule est une valeur **par défaut** ; une valeur
//   saisie à la main la remplace (effacer la saisie revient au calcul).
// - Ressource : la formule calcule le **maximum** (sauf maximum saisi) ; la valeur actuelle vaut
//   le maximum tant qu'elle n'est pas saisie. `PV` = valeur actuelle, `PV.max` = maximum.
// - Cellule : formule de la cellule, sinon de la colonne. Dans un tableau, une référence désigne
//   d'abord une colonne de la même ligne (`=valeur/2`), puis `groupe` (valeur du groupe, 0 si non
//   saisie), puis un
//   code de champ de la fiche (`=DEX*2`).
// - Une valeur non saisie rend le calcul vide (pas d'erreur) ; codes inconnus, cycles et
//   divisions par zéro sont des erreurs affichées dans le champ.
//
// Un moteur mémorise ses résultats : en créer un nouveau après une modification de la fiche.

public final class FormulaEngine {
    private let sheet: Sheet?
    private var cache: [Key: FormulaResult] = [:]
    private var inProgress: Set<Key> = []
    private var parsed: [String: Result<FormulaExpression, FormulaError>] = [:]
    private lazy var fieldsByCode: [String: SheetField] = {
        var index: [String: SheetField] = [:]
        for field in sheet?.allFields ?? [] where !field.code.isEmpty {
            let key = Self.normalize(field.code)
            if index[key] == nil { index[key] = field }
        }
        return index
    }()

    private struct Key: Hashable {
        enum Slot { case value, maximum, formula }
        let object: ObjectIdentifier
        let slot: Slot
    }

    public init(sheet: Sheet?) {
        self.sheet = sheet
    }

    static func normalize(_ code: String) -> String {
        code.uppercased().folding(options: .diacriticInsensitive, locale: nil)
    }

    /// Analyse (avec cache) ; nil pour une formule vide.
    private func expression(_ formula: String?) -> Result<FormulaExpression, FormulaError>? {
        guard let formula, !formula.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        if let cached = parsed[formula] { return cached }
        let result: Result<FormulaExpression, FormulaError>
        do {
            result = .success(try FormulaExpression.parse(formula))
        } catch {
            result = .failure(error)
        }
        parsed[formula] = result
        return result
    }

    /// Calcul mémorisé, avec détection des cycles.
    private func memo(_ key: Key, _ compute: () -> FormulaResult) -> FormulaResult {
        if let cached = cache[key] { return cached }
        guard !inProgress.contains(key) else { return .failure(.circularReference) }
        inProgress.insert(key)
        let result = compute()
        inProgress.remove(key)
        cache[key] = result
        return result
    }

    // MARK: Champs

    /// Valeur numérique effective du champ : saisie, sinon calculée.
    public func value(of field: SheetField) -> FormulaResult {
        memo(Key(object: ObjectIdentifier(field), slot: .value)) {
            switch field.kind {
            case .formula:
                return computed(field) ?? .success(nil)
            case .resource:
                if let current = field.numberValue { return .success(current) }
                return maximum(of: field)
            case .integer, .decimal, .percentage, .modifier:
                if let number = field.numberValue { return .success(number) }
                return computed(field) ?? .success(nil)
            case .checkbox:
                return .success(field.boolValue == true ? 1 : 0)
            case .text, .longText, .choice:
                return .success(field.textValue.flatMap(ListImport.number(from:)))
            case .date, .image:
                return .success(nil)
            }
        }
    }

    /// Maximum effectif d'une ressource : saisi, sinon calculé par sa formule.
    public func maximum(of field: SheetField) -> FormulaResult {
        memo(Key(object: ObjectIdentifier(field), slot: .maximum)) {
            if let maximum = field.resourceMax { return .success(maximum) }
            return computed(field) ?? .success(nil)
        }
    }

    /// Résultat de la formule du champ (nil s'il n'en a pas), même si une valeur est saisie.
    public func computed(_ field: SheetField) -> FormulaResult? {
        guard let parsed = expression(field.formula) else { return nil }
        return memo(Key(object: ObjectIdentifier(field), slot: .formula)) {
            switch parsed {
            case .failure(let error): return .failure(error)
            case .success(let expression): return expression.evaluate { self.resolve($0, member: $1) }
            }
        }
    }

    /// Référence par code de champ (`FOR`, `PV.max`).
    private func resolve(_ name: String, member: String?) -> FormulaResult {
        let fullName = member.map { "\(name).\($0)" } ?? name
        guard let field = fieldsByCode[Self.normalize(name)] else { return .failure(.unknownReference(fullName)) }
        switch member.map(Self.normalize) {
        case nil:
            return value(of: field)
        case "MAX"?:
            guard field.kind == .resource else { return .failure(.unknownReference(fullName)) }
            return maximum(of: field)
        default:
            return .failure(.unknownReference(fullName))
        }
    }

    // MARK: Cellules

    /// Valeur numérique effective de la cellule : saisie, sinon calculée.
    public func value(of cell: SheetTableCell) -> FormulaResult {
        memo(Key(object: ObjectIdentifier(cell), slot: .value)) {
            switch cell.column?.kind ?? .text {
            case .formula:
                return computed(cell) ?? .success(nil)
            case .number, .percentage:
                if let number = cell.numberValue { return .success(number) }
                return computed(cell) ?? .success(nil)
            case .checkbox:
                return .success(cell.boolValue == true ? 1 : 0)
            case .text:
                return .success(cell.textValue.flatMap(ListImport.number(from:)))
            }
        }
    }

    /// Résultat de la formule de la cellule (ou de sa colonne), nil sans formule.
    public func computed(_ cell: SheetTableCell) -> FormulaResult? {
        guard let parsed = expression(cell.formula ?? cell.column?.formula) else { return nil }
        return memo(Key(object: ObjectIdentifier(cell), slot: .formula)) {
            switch parsed {
            case .failure(let error): return .failure(error)
            case .success(let expression): return expression.evaluate { self.resolve($0, member: $1, in: cell) }
            }
        }
    }

    /// Référence depuis une cellule : colonne de la même ligne, `groupe`, puis champ de la fiche.
    private func resolve(_ name: String, member: String?, in cell: SheetTableCell) -> FormulaResult {
        if member == nil, let row = cell.row {
            let key = Self.normalize(name)
            let sibling = (row.cells ?? []).first { other in
                guard let code = other.column?.code, !code.isEmpty else { return false }
                return Self.normalize(code) == key
            }
            if let sibling {
                return value(of: sibling)
            }
            if key == "GROUPE" {
                // Bonus de groupe non saisi : 0.
                return .success(row.group.flatMap { $0.hasValue ? $0.numberValue : nil } ?? 0)
            }
        }
        return resolve(name, member: member)
    }

    // MARK: Vérification

    /// Vérifie une formule sans l'évaluer (syntaxe, fonctions connues).
    public static func check(_ formula: String) -> FormulaError? {
        do {
            // Références remplacées par 1 : reste à vérifier les fonctions et leurs arguments.
            let expression = try FormulaExpression.parse(formula)
            switch expression.evaluate(resolve: { _, _ in .success(1) }) {
            case .failure(let error) where error != .divisionByZero: return error
            default: return nil
            }
        } catch {
            return error
        }
    }
}

// MARK: - Accès depuis les éléments

extension SheetField {
    /// Fiche qui contient le champ.
    public var sheet: Sheet? { section?.row?.page?.sheet }
}

extension SheetTableCell {
    /// Fiche qui contient la cellule.
    public var sheet: Sheet? { row?.group?.section?.row?.page?.sheet }
}
