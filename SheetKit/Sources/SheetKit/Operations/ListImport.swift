import Foundation
import SwiftData

// « Coller une liste » (SPEC §4.1) : une ligne par élément, valeurs séparées par une tabulation
// (copie depuis un tableur) ou un point-virgule.
//
// Champs   : `libellé;valeur;code`            ex. `Force;11;FOR`, `PV;=plafond((CON+TAI)/2)`
// Tableaux : `libellé;valeur colonne 1;…`     ex. `Marchander;5`, `Langue (…);=INT`
//            `# Groupe` ou `# Groupe;bonus`   crée un groupe de lignes
//            `Monter (Navire)`                libellé avec spécialisation ; `(…)` ou `()` : à préciser

/// Une ligne de liste collée.
public struct ListEntry: Equatable, Sendable {
    public var label: String
    public var values: [String]
    /// Ligne `# …` : titre de groupe (tableaux).
    public var isGroup: Bool

    public init(label: String, values: [String] = [], isGroup: Bool = false) {
        self.label = label
        self.values = values
        self.isGroup = isGroup
    }
}

public enum ListImport {
    /// Découpe le texte : lignes non vides, séparateur tabulation (prioritaire) ou point-virgule.
    public static func parse(_ text: String) -> [ListEntry] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            let separator: Character = line.contains("\t") ? "\t" : ";"
            var parts = line.split(separator: separator, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard var label = parts.first else { return nil }
            parts.removeFirst()
            while parts.last?.isEmpty == true { parts.removeLast() }
            var isGroup = false
            if label.hasPrefix("#") {
                isGroup = true
                label = label.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
            }
            guard !label.isEmpty || !parts.isEmpty else { return nil }
            return ListEntry(label: label, values: parts, isGroup: isGroup)
        }
    }

    /// Nombre saisi à la française ou non : `25`, `25%`, `1,5`, `−3`, `+2`. Nil si ce n'est pas un nombre.
    public static func number(from text: String) -> Double? {
        // Séparateurs de milliers : espaces (dont insécables, fr_FR) et apostrophes (fr_CH, « 1’234 »).
        var cleaned = String(text.unicodeScalars.filter {
            !CharacterSet.whitespaces.contains($0) && !["'", "’"].contains($0)
        })
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: ",", with: ".")
        if cleaned.hasSuffix("%") { cleaned.removeLast() }
        if cleaned.hasPrefix("+") { cleaned.removeFirst() }
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    /// Vrai pour `x`, `oui`, `1`, `vrai`, `true`, `✓`.
    public static func bool(from text: String) -> Bool {
        ["x", "oui", "o", "1", "vrai", "true", "yes", "✓", "✔"].contains(text.lowercased().trimmingCharacters(in: .whitespaces))
    }

    /// `Monter (Navire)` → (Monter, Navire, true) ; `Art (…)` / `Art ()` → (Art, nil, true).
    public static func splitSpecialization(_ label: String) -> (label: String, specialization: String?, allowsSpecialization: Bool) {
        guard label.hasSuffix(")"), let open = label.lastIndex(of: "("), open > label.startIndex else {
            return (label, nil, false)
        }
        let base = label[..<open].trimmingCharacters(in: .whitespaces)
        let inner = label[label.index(after: open)..<label.index(before: label.endIndex)]
            .trimmingCharacters(in: .whitespaces)
        guard !base.isEmpty else { return (label, nil, false) }
        let placeholders: Set<String> = ["", "…", "...", "?", "_", "__", "___"]
        return (base, placeholders.contains(inner) ? nil : inner, true)
    }
}

extension SheetField {
    /// Applique une valeur saisie en texte selon le type du champ (`=…` : formule).
    public func applyText(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        if text.hasPrefix("=") {
            formula = text
            return
        }
        switch kind {
        case .integer, .decimal, .percentage:
            numberValue = ListImport.number(from: text)
        case .modifier:
            if let number = ListImport.number(from: text) { numberValue = number } else { textValue = text }
        case .resource:
            let parts = text.split(separator: "/").map(String.init)
            if parts.count == 2 {
                numberValue = ListImport.number(from: parts[0])
                resourceMax = ListImport.number(from: parts[1])
            } else if let number = ListImport.number(from: text) {
                numberValue = number
                resourceMax = number
            }
        case .checkbox:
            boolValue = ListImport.bool(from: text)
        case .choice:
            options = text.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        case .formula:
            formula = "=" + text
        case .text, .longText:
            textValue = text
        case .date, .image, .spacer:
            break
        }
    }
}

extension SheetTableCell {
    /// Applique une valeur saisie en texte selon le type de la colonne (`=…` : formule).
    public func applyText(_ text: String, kind: ColumnKind) {
        let text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        if text.hasPrefix("=") {
            formula = text
            return
        }
        switch kind {
        case .number, .percentage: numberValue = ListImport.number(from: text)
        case .checkbox: boolValue = ListImport.bool(from: text)
        case .text: textValue = text
        case .formula: break
        }
    }
}

extension SheetSection {
    /// Ajoute un champ par ligne (`libellé;valeur;code`) après `previous` (ou à la fin).
    /// Choix : `libellé;option1|option2`. Les lignes `# …` sont ignorées.
    @discardableResult
    public func importFields(_ entries: [ListEntry], kind: FieldKind, after previous: SheetField? = nil, in context: ModelContext) -> [SheetField] {
        var created: [SheetField] = []
        var anchor = previous
        for entry in entries where !entry.isGroup {
            let field = insertField(label: entry.label, kind: kind, after: anchor, in: context)
            if let value = entry.values.first {
                field.applyText(value)
            }
            if entry.values.count > 1, let sheet {
                field.code = sheet.uniqueFieldCode(entry.values[1], excluding: field)
            }
            created.append(field)
            anchor = field
        }
        return created
    }

    /// Ajoute une ligne par élément ; les valeurs remplissent les colonnes saisissables dans l'ordre
    /// (les colonnes « formule » sont sautées). `# Groupe;bonus` ouvre un nouveau groupe.
    /// Sans groupe de départ, les lignes vont dans le premier groupe (créé au besoin).
    @discardableResult
    public func importRows(_ entries: [ListEntry], into group: SheetTableGroup? = nil, in context: ModelContext) -> [SheetTableRow] {
        let inputColumns = sortedColumns.filter { $0.kind != .formula }
        var current = group
        var created: [SheetTableRow] = []
        for entry in entries {
            if entry.isGroup {
                let newGroup = insertGroup(title: entry.label, after: current, in: context)
                if let value = entry.values.first.flatMap(ListImport.number(from:)) {
                    newGroup.hasValue = true
                    newGroup.numberValue = value
                }
                current = newGroup
                continue
            }
            let target = current ?? firstOrNewGroup(in: context)
            current = target
            let parts = ListImport.splitSpecialization(entry.label)
            let row = addRow(label: parts.label, to: target, allowsSpecialization: parts.allowsSpecialization, in: context)
            row.specialization = parts.specialization
            for (column, value) in zip(inputColumns, entry.values) {
                row.cell(for: column)?.applyText(value, kind: column.kind)
            }
            created.append(row)
        }
        return created
    }
}
