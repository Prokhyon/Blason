import Foundation
import SwiftData

/// Une ligne affichée d'un groupe de tableau (modes Remplir et Jouer).
///
/// Les lignes à spécialiser qui portent le même libellé (« Connaissance », « Langue »…) forment
/// une famille : une ligne de catégorie, puis chaque spécialité en retrait, avec ses valeurs.
public enum TableLine: Identifiable {
    /// Ligne ordinaire, ou spécialité (en retrait) d'une famille.
    case row(SheetTableRow, indented: Bool)
    /// Libellé de la famille, sans valeurs (en Remplir, avec l'ajout d'une spécialité) ;
    /// porte la première ligne de la famille.
    case category(SheetTableRow)

    public struct ID: Hashable {
        let kind: Int
        let row: PersistentIdentifier
    }

    public var id: ID {
        switch self {
        case .row(let row, _): ID(kind: 0, row: row.persistentModelID)
        case .category(let row): ID(kind: 1, row: row.persistentModelID)
        }
    }
}

extension SheetTableGroup {
    /// Lignes à afficher. Une famille se place à sa première ligne et garde l'ordre de ses lignes.
    /// - En saisie : toujours catégorie, puis spécialités en retrait.
    /// - En lecture : une ligne seule encore sans précision reste sur une ligne (« Langue 0 0 ») ;
    ///   sinon catégorie et spécialités en retrait (« Connaissance », puis « Hautes sphères »).
    public func lines(editing: Bool) -> [TableLine] {
        let rows = sortedRows
        var families: [String: [SheetTableRow]] = [:]
        for row in rows where row.allowsSpecialization {
            families[row.label, default: []].append(row)
        }
        var placed = Set<String>()
        var lines: [TableLine] = []
        for row in rows {
            guard row.allowsSpecialization else {
                lines.append(.row(row, indented: false))
                continue
            }
            guard placed.insert(row.label).inserted, let family = families[row.label],
                  let first = family.first else { continue }
            if !editing, family.count == 1, !first.hasSpecialization {
                lines.append(.row(first, indented: false))
                continue
            }
            lines.append(.category(first))
            lines += family.map { .row($0, indented: true) }
        }
        return lines
    }
}

extension SheetTableRow {
    /// Précision saisie (non vide).
    public var hasSpecialization: Bool {
        !(specialization ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Lignes de la même famille (même libellé, à spécialiser), dans l'ordre.
    public var family: [SheetTableRow] {
        guard allowsSpecialization, let group else { return [self] }
        return group.sortedRows.filter { $0.allowsSpecialization && $0.label == label }
    }

    /// Ajoute une spécialité à la famille, après sa dernière ligne : même libellé, précision à saisir.
    /// Elle reprend les valeurs que donne le template (base, formules) mais pas ce que le joueur
    /// a saisi pour une autre spécialité : valeur d'une colonne calculée (qui remplace le calcul)
    /// ni colonne vivante (case « Exp. »).
    @discardableResult
    public func addSpecialty(in context: ModelContext) -> SheetTableRow? {
        guard allowsSpecialization, let group, let last = family.last else { return nil }
        for other in group.rows ?? [] where other.order > last.order {
            other.order += 1
        }
        let row = SheetTableRow(label: label, order: last.order + 1)
        context.insert(row)
        row.group = group
        row.allowsSpecialization = true
        row.isFromTemplate = false
        for cell in last.cells ?? [] {
            let copy = SheetTableCell()
            context.insert(copy)
            copy.row = row
            copy.column = cell.column
            copy.formula = cell.formula
            let isPlayerValue = cell.column.map { $0.isLive || $0.formula != nil } ?? true
            if !isPlayerValue {
                copy.textValue = cell.textValue
                copy.numberValue = cell.numberValue
                copy.boolValue = cell.boolValue
            }
        }
        return row
    }
}
