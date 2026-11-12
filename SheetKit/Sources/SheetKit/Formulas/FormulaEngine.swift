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
// - Besace : `BESACE.poids`, `BESACE.limite`, `BESACE.malus`, `BESACE.argent` (BESACE : code de
//   la Besace). Propriété d'objet : comme une cellule ; une référence désigne d'abord une autre
//   propriété du même objet, puis `quantite`, puis la fiche.
// - Une valeur non saisie rend le calcul vide (pas d'erreur) ; codes inconnus, cycles et
//   divisions par zéro sont des erreurs affichées dans le champ.
// - Une formule peut donner du texte (table de correspondance : « +1d4 ») ; `content` le garde
//   pour l'affichage, `value` donne un nombre (un texte non numérique y est une erreur).
//
// Un moteur mémorise ses résultats : en créer un nouveau après une modification de la fiche.

public final class FormulaEngine {
    private let sheet: Sheet?
    private var cache: [Key: FormulaValueResult] = [:]
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

    private lazy var inventoriesByCode: [String: Inventory] = {
        var index: [String: Inventory] = [:]
        for inventory in sheet?.inventories ?? [] where !inventory.code.isEmpty {
            let key = Self.normalize(inventory.code)
            if index[key] == nil { index[key] = inventory }
        }
        return index
    }()

    private struct Key: Hashable {
        enum Slot: Hashable {
            case value, maximum, formula
            /// Propriété d'un objet (valeur effective, ou résultat de sa formule).
            case property(ObjectIdentifier), propertyFormula(ObjectIdentifier)
        }
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
    private func memo(_ key: Key, _ compute: () -> FormulaValueResult) -> FormulaValueResult {
        if let cached = cache[key] { return cached }
        guard !inProgress.contains(key) else { return .failure(.circularReference) }
        inProgress.insert(key)
        let result = compute()
        inProgress.remove(key)
        cache[key] = result
        return result
    }

    private func evaluate(_ formula: String?, key: Key, resolve: @escaping (String, String?) -> FormulaValueResult) -> FormulaValueResult? {
        guard let parsed = expression(formula) else { return nil }
        return memo(key) {
            switch parsed {
            case .failure(let error): return .failure(error)
            case .success(let expression): return expression.evaluateValue(resolve: resolve)
            }
        }
    }

    // MARK: Champs

    /// Valeur numérique effective du champ : saisie, sinon calculée.
    public func value(of field: SheetField) -> FormulaResult {
        content(of: field).numeric
    }

    /// Valeur effective à afficher : nombre ou texte (un modificateur peut valoir « +1d4 »).
    public func content(of field: SheetField) -> FormulaValueResult {
        memo(Key(object: ObjectIdentifier(field), slot: .value)) {
            switch field.kind {
            case .formula:
                return computedContent(field) ?? .success(nil)
            case .resource:
                if let current = field.numberValue { return .success(.number(current)) }
                return maximum(of: field).asValue
            case .integer, .decimal, .percentage:
                if let number = field.numberValue { return .success(.number(number)) }
                return computedContent(field) ?? .success(nil)
            case .modifier:
                if let number = field.numberValue { return .success(.number(number)) }
                if let text = field.textValue, !text.isEmpty { return .success(.text(text)) }
                return computedContent(field) ?? .success(nil)
            case .checkbox:
                return .success(.number(field.boolValue == true ? 1 : 0))
            case .text, .longText, .choice:
                return .success(field.textValue.flatMap(ListImport.number(from:)).map(FormulaValue.number))
            case .date, .image:
                return .success(nil)
            }
        }
    }

    /// Maximum effectif d'une ressource : saisi, sinon calculé par sa formule.
    public func maximum(of field: SheetField) -> FormulaResult {
        memo(Key(object: ObjectIdentifier(field), slot: .maximum)) {
            if let maximum = field.resourceMax { return .success(.number(maximum)) }
            return computedContent(field) ?? .success(nil)
        }
        .numeric
    }

    /// Résultat numérique de la formule du champ (nil s'il n'en a pas), même si une valeur est saisie.
    public func computed(_ field: SheetField) -> FormulaResult? {
        computedContent(field)?.numeric
    }

    /// Résultat de la formule du champ, texte compris (nil s'il n'en a pas).
    public func computedContent(_ field: SheetField) -> FormulaValueResult? {
        evaluate(field.formula, key: Key(object: ObjectIdentifier(field), slot: .formula)) {
            self.resolve($0, member: $1)
        }
    }

    /// Référence par code de champ (`FOR`, `PV.max`) ou de Besace (`BESACE.poids`).
    private func resolve(_ name: String, member: String?) -> FormulaValueResult {
        let fullName = member.map { "\(name).\($0)" } ?? name
        if let member, let inventory = inventoriesByCode[Self.normalize(name)] {
            return resolve(inventory, member: member, fullName: fullName)
        }
        guard let field = fieldsByCode[Self.normalize(name)] else { return .failure(.unknownReference(fullName)) }
        switch member.map(Self.normalize) {
        case nil:
            return content(of: field)
        case "MAX"?:
            guard field.kind == .resource else { return .failure(.unknownReference(fullName)) }
            return maximum(of: field).asValue
        default:
            return .failure(.unknownReference(fullName))
        }
    }

    // MARK: Cellules

    /// Valeur numérique effective de la cellule : saisie, sinon calculée.
    public func value(of cell: SheetTableCell) -> FormulaResult {
        content(of: cell).numeric
    }

    /// Valeur effective à afficher : nombre ou texte.
    public func content(of cell: SheetTableCell) -> FormulaValueResult {
        memo(Key(object: ObjectIdentifier(cell), slot: .value)) {
            switch cell.column?.kind ?? .text {
            case .formula:
                return computedContent(cell) ?? .success(nil)
            case .number, .percentage:
                if let number = cell.numberValue { return .success(.number(number)) }
                return computedContent(cell) ?? .success(nil)
            case .checkbox:
                return .success(.number(cell.boolValue == true ? 1 : 0))
            case .text:
                return .success(cell.textValue.flatMap(ListImport.number(from:)).map(FormulaValue.number))
            }
        }
    }

    /// Résultat numérique de la formule de la cellule (ou de sa colonne), nil sans formule.
    public func computed(_ cell: SheetTableCell) -> FormulaResult? {
        computedContent(cell)?.numeric
    }

    /// Résultat de la formule de la cellule (ou de sa colonne), texte compris.
    public func computedContent(_ cell: SheetTableCell) -> FormulaValueResult? {
        evaluate(cell.formula ?? cell.column?.formula, key: Key(object: ObjectIdentifier(cell), slot: .formula)) {
            self.resolve($0, member: $1, in: cell)
        }
    }

    /// Référence depuis une cellule : colonne de la même ligne, `groupe`, puis champ de la fiche.
    private func resolve(_ name: String, member: String?, in cell: SheetTableCell) -> FormulaValueResult {
        if member == nil, let row = cell.row {
            let key = Self.normalize(name)
            let sibling = (row.cells ?? []).first { other in
                guard let code = other.column?.code, !code.isEmpty else { return false }
                return Self.normalize(code) == key
            }
            if let sibling {
                return content(of: sibling)
            }
            if key == "GROUPE" {
                // Bonus de groupe non saisi : 0.
                return .success(.number(row.group.flatMap { $0.hasValue ? $0.numberValue : nil } ?? 0))
            }
        }
        return resolve(name, member: member)
    }

    // MARK: Besace

    private func resolve(_ inventory: Inventory, member: String, fullName: String) -> FormulaValueResult {
        switch Self.normalize(member) {
        case "POIDS": .success(.number(inventory.carriedWeight))
        case "LIMITE": limit(of: inventory).asValue
        case "MALUS": .success(.number(malus(of: inventory)))
        case "ARGENT": .success(.number(inventory.totalMoney))
        default: .failure(.unknownReference(fullName))
        }
    }

    /// Charge maximale (`BESACE.limite`) : résultat de la formule de limite.
    public func limit(of inventory: Inventory) -> FormulaResult {
        evaluate(inventory.weightLimitFormula, key: Key(object: ObjectIdentifier(inventory), slot: .formula)) {
            self.resolve($0, member: $1)
        }?.numeric ?? .success(nil)
    }

    /// Seuil d'un palier (formule).
    public func threshold(of level: EncumbranceLevel) -> FormulaResult {
        evaluate(level.thresholdFormula, key: Key(object: ObjectIdentifier(level), slot: .formula)) {
            self.resolve($0, member: $1)
        }?.numeric ?? .success(nil)
    }

    /// Palier atteint : le plus haut dont le seuil est dépassé par le poids porté (nil : aucun,
    /// ou poids non suivi).
    public func level(of inventory: Inventory) -> EncumbranceLevel? {
        guard inventory.tracksWeight else { return nil }
        let weight = inventory.carriedWeight
        var reached: (level: EncumbranceLevel, threshold: Double)?
        for level in inventory.sortedLevels {
            guard case .success(let threshold?) = threshold(of: level), weight > threshold else { continue }
            if reached == nil || threshold >= reached!.threshold { reached = (level, threshold) }
        }
        return reached?.level
    }

    /// Malus du palier atteint (`BESACE.malus`) : 0 sans palier, ou si la Besace n'applique pas de malus.
    public func malus(of inventory: Inventory) -> Double {
        guard inventory.appliesMalus else { return 0 }
        return level(of: inventory)?.malus ?? 0
    }

    // MARK: Propriétés des objets

    /// Valeur numérique effective d'une propriété d'objet.
    public func value(of item: InventoryItem, _ property: ItemProperty) -> FormulaResult {
        content(of: item, property).numeric
    }

    /// Valeur effective d'une propriété d'objet : saisie pour l'objet, sinon défaut de la propriété,
    /// sinon calculée.
    public func content(of item: InventoryItem, _ property: ItemProperty) -> FormulaValueResult {
        memo(Key(object: ObjectIdentifier(item), slot: .property(ObjectIdentifier(property)))) {
            let value = item.value(for: property)
            switch property.kind {
            case .formula:
                return computedContent(of: item, property) ?? .success(nil)
            case .number, .percentage:
                if let number = value?.numberValue { return .success(.number(number)) }
                if value?.formula == nil, let number = property.numberValue { return .success(.number(number)) }
                return computedContent(of: item, property) ?? .success(nil)
            case .checkbox:
                return .success(.number((value?.boolValue ?? property.boolValue) == true ? 1 : 0))
            case .text:
                let text = value?.textValue ?? property.textValue
                return .success(text.flatMap(ListImport.number(from:)).map(FormulaValue.number))
            }
        }
    }

    /// Résultat de la formule d'une propriété d'objet (celle de l'objet, sinon celle de la propriété).
    public func computedContent(of item: InventoryItem, _ property: ItemProperty) -> FormulaValueResult? {
        let formula = item.value(for: property)?.formula ?? property.formula
        return evaluate(formula, key: Key(object: ObjectIdentifier(item), slot: .propertyFormula(ObjectIdentifier(property)))) {
            self.resolve($0, member: $1, in: item)
        }
    }

    /// Référence depuis un objet : propriété du même objet, `quantite`, puis la fiche.
    private func resolve(_ name: String, member: String?, in item: InventoryItem) -> FormulaValueResult {
        if member == nil {
            let key = Self.normalize(name)
            if let sibling = item.type?.sortedProperties.first(where: { !$0.code.isEmpty && Self.normalize($0.code) == key }) {
                return content(of: item, sibling)
            }
            if key == "QUANTITE" {
                return .success(.number(item.quantity))
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
            switch expression.evaluateValue(resolve: { _, _ in .success(.number(1)) }) {
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
