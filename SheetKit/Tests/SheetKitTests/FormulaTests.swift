import Foundation
import SwiftData
import Testing
@testable import SheetKit

/// Évalue une formule sans référence (ou avec des références fixes).
private func evaluate(_ formula: String, _ values: [String: Double?] = [:]) -> FormulaResult {
    do {
        return try FormulaExpression.parse(formula).evaluate { name, member in
            let key = member.map { "\(name).\($0)" } ?? name
            guard let value = values[key] else { return .failure(.unknownReference(key)) }
            return .success(value)
        }
    } catch {
        return .failure(error)
    }
}

@Suite("Formules : analyse et calcul")
struct FormulaParserTests {

    @Test("Priorités, parenthèses, signes, opérateurs typographiques")
    func arithmetic() {
        #expect(evaluate("=2+3*4") == .success(14))
        #expect(evaluate("(2+3)*4") == .success(20))
        #expect(evaluate("=10-4-3") == .success(3))
        #expect(evaluate("=12/4/3") == .success(1))
        #expect(evaluate("=-3+5") == .success(2))
        #expect(evaluate("=2*-3") == .success(-6))
        #expect(evaluate("= 6 × 2 ÷ 4 − 1") == .success(2))
        #expect(evaluate("=1,5*2") == .success(3))
        #expect(evaluate("=.5+1.25") == .success(1.75))
    }

    @Test("Fonctions : plafond, plancher, arrondi, min, max, alias")
    func functions() {
        #expect(evaluate("=plafond(27/2)") == .success(14))
        #expect(evaluate("=plancher(27/2)") == .success(13))
        #expect(evaluate("=arrondi(2.5)") == .success(3))
        #expect(evaluate("=arrondi(-2.5)") == .success(-3))
        #expect(evaluate("=arrondi(3.14159; 2)") == .success(3.14))
        #expect(evaluate("=min(4; 2; 9)") == .success(2))
        #expect(evaluate("=MAX(4, 2, 9)") == .success(9))
        #expect(evaluate("=Plafond(1.1)") == .success(2))
        #expect(evaluate("=ceil(1.1) + floor(1.9) + abs(-2)") == .success(5))
    }

    @Test("Références : codes, membre .max, accents et casse indifférents")
    func references() throws {
        #expect(evaluate("=FOR*5", ["FOR": 11]) == .success(55))
        #expect(evaluate("=plafond(PV.max/2)", ["PV.max": 13]) == .success(7))
        #expect(try FormulaExpression.parse("=plafond((CON+TAI)/2) + PV.max").references == ["CON", "TAI", "PV.max"])
    }

    @Test("Valeur manquante : résultat vide, sans erreur")
    func missingValues() {
        #expect(evaluate("=EDU*5", ["EDU": Double?.none]) == .success(nil))
        #expect(evaluate("=max(FOR; EDU)", ["FOR": 3, "EDU": Double?.none]) == .success(nil))
        #expect(evaluate("=plafond(EDU)", ["EDU": Double?.none]) == .success(nil))
    }

    @Test("Erreurs : syntaxe, fonction inconnue, arguments, division par zéro")
    func errors() {
        #expect(evaluate("=") == .failure(.syntax("formule vide")))
        #expect(evaluate("=2+") == .failure(.syntax("formule incomplète")))
        #expect(evaluate("=(2+3") == .failure(.syntax("« ) » manquante")))
        #expect(evaluate("=2 3") == .failure(.syntax("« 3 » inattendu")))
        #expect(evaluate("=2 $ 3") == .failure(.syntax("caractère « $ »")))
        #expect(evaluate("=racine(4)") == .failure(.unknownFunction("racine")))
        #expect(evaluate("=plafond(1; 2)") == .failure(.argumentCount(function: "plafond", expected: "1 valeur")))
        #expect(evaluate("=4/(2-2)") == .failure(.divisionByZero))
        #expect(evaluate("=FOO") == .failure(.unknownReference("FOO")))
        #expect(FormulaError.circularReference.message == "Référence circulaire")
    }

    @Test("Vérification sans évaluer")
    func check() {
        #expect(FormulaEngine.check("=FOR*5") == nil)
        #expect(FormulaEngine.check("=X/0") == nil)
        #expect(FormulaEngine.check("=racine(FOR)") == .unknownFunction("racine"))
        #expect(FormulaEngine.check("=FOR*") == .syntax("formule incomplète"))
    }
}

@MainActor
@Suite("Formules : calcul d'une fiche")
struct FormulaEngineTests {

    @Test("Leo : jets ×5, PV, blessure grave, bases et valeurs des compétences")
    func leo() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let leo = DemoData.leo(from: template, in: context)
        let sheet = try #require(leo.sheet)
        let engine = FormulaEngine(sheet: sheet)
        func field(_ code: String) throws -> SheetField { try #require(sheet.field(code: code)) }

        #expect(engine.value(of: try field("EFFORT")) == .success(55))
        #expect(engine.value(of: try field("ENDURANCE")) == .success(60))
        #expect(engine.value(of: try field("IDEE")) == .success(75))
        #expect(engine.value(of: try field("CHANCE")) == .success(65))
        #expect(engine.value(of: try field("AGILITE")) == .success(80))
        #expect(engine.value(of: try field("CHARME")) == .success(65))
        // ÉDU non saisie : pas de valeur, pas d'erreur.
        #expect(engine.value(of: try field("SAVOIR")) == .success(nil))

        // PV saisis (14/14), et le calcul donne le même maximum.
        let pv = try field("PV")
        #expect(engine.maximum(of: pv) == .success(14))
        #expect(engine.computed(pv) == .success(14))
        #expect(engine.value(of: try field("BLESSURE")) == .success(7))

        let skills = try #require(sheet.section(titled: "Compétences"))
        func cell(_ label: String, _ code: String) throws -> SheetTableCell {
            try #require(skills.tableRow(label: label)?.cell(code: code))
        }
        #expect(engine.value(of: try cell("Esquive", "base")) == .success(32))
        #expect(engine.value(of: try cell("Jeu", "base")) == .success(28))
        #expect(engine.value(of: try cell("Voler", "base")) == .success(64))
        #expect(engine.value(of: try cell("Langue natale", "base")) == .success(nil))
        // Valeur par défaut = base + bonus de groupe ; une valeur saisie la remplace.
        #expect(engine.value(of: try cell("Esquive", "valeur")) == .success(32))
        let monter = try #require(skills.tableRow(label: "Monter", specialization: "Navire"))
        #expect(engine.value(of: try #require(monter.cell(code: "valeur"))) == .success(80))
    }

    @Test("Template vide : tout est vide, rien n'est en erreur")
    func emptyTemplate() throws {
        let context = try makeContext()
        let template = DemoData.brpTemplate(in: context)
        let sheet = try #require(template.sheet)
        let engine = FormulaEngine(sheet: sheet)
        for field in sheet.allFields where field.formula != nil {
            if case .failure(let error) = engine.value(of: field) {
                Issue.record("\(field.label) : \(error.message)")
            }
        }
        for section in sheet.allSections {
            for row in section.allTableRows {
                for cell in row.cells ?? [] {
                    if case .failure(let error) = engine.value(of: cell) {
                        Issue.record("\(row.label) : \(error.message)")
                    }
                }
            }
        }
        #expect(engine.value(of: try #require(sheet.field(code: "EFFORT"))) == .success(nil))
        // Base fixe (5) + bonus de groupe non saisi (0).
        let marchander = try #require(sheet.section(titled: "Compétences")?.tableRow(label: "Marchander"))
        #expect(engine.value(of: try #require(marchander.cell(code: "valeur"))) == .success(5))
    }

    @Test("Bonus de groupe, colonne calculée, priorité des colonnes sur les champs")
    func tableFormulas() throws {
        let context = try makeContext()
        let template = SheetTemplate.create(name: "T", firstPage: "P", in: context)
        let sheet = try #require(template.sheet)
        let row = sheet.sortedPages[0].sortedRows[0]
        let caracs = row.addSection(title: "Caracs", kind: .fields, in: context)
        caracs.addField(label: "Dextérité", kind: .integer, code: "DEX", in: context).numberValue = 16
        caracs.addField(label: "Valeur", kind: .integer, code: "valeur", in: context).numberValue = 999

        let table = row.addSection(title: "Compétences", kind: .table, in: context)
        table.addColumn(title: "Base", kind: .number, code: "base", in: context)
        table.addColumn(title: "Valeur", kind: .percentage, code: "valeur", in: context).formula = "=base+groupe"
        table.addColumn(title: "Moitié", kind: .formula, code: "demi", in: context).formula = "=plancher(valeur/2)"
        let group = table.addGroup(title: "Physique", hasValue: true, in: context)
        group.numberValue = 5
        let esquive = table.addRow(label: "Esquive", to: group, in: context)
        esquive.cell(code: "base")?.formula = "=DEX*2"

        var engine = FormulaEngine(sheet: sheet)
        #expect(engine.value(of: try #require(esquive.cell(code: "valeur"))) == .success(37))
        // `valeur` désigne la colonne de la ligne, pas le champ de même code.
        #expect(engine.value(of: try #require(esquive.cell(code: "demi"))) == .success(18))

        esquive.cell(code: "valeur")?.numberValue = 60
        engine = FormulaEngine(sheet: sheet)
        #expect(engine.value(of: try #require(esquive.cell(code: "demi"))) == .success(30))
        #expect(engine.computed(try #require(esquive.cell(code: "valeur"))) == .success(37))
    }

    @Test("Valeur saisie prioritaire, cycles et codes inconnus en erreur sans bloquer le reste")
    func overridesAndErrors() throws {
        let context = try makeContext()
        let template = SheetTemplate.create(name: "T", firstPage: "P", in: context)
        let sheet = try #require(template.sheet)
        let section = sheet.sortedPages[0].sortedRows[0].addSection(title: "S", kind: .fields, in: context)
        let pou = section.addField(label: "POU", kind: .integer, code: "POU", in: context)
        pou.numberValue = 13
        let san = section.addField(label: "SAN", kind: .resource, code: "SAN", in: context)
        san.formula = "=POU*5"
        let a = section.addField(label: "A", kind: .formula, code: "A", in: context)
        a.formula = "=B+1"
        let b = section.addField(label: "B", kind: .formula, code: "B", in: context)
        b.formula = "=A+1"
        let selfRef = section.addField(label: "C", kind: .integer, code: "C", in: context)
        selfRef.formula = "=C+1"
        let unknown = section.addField(label: "D", kind: .formula, code: "D", in: context)
        unknown.formula = "=XYZ*2"
        let badMember = section.addField(label: "E", kind: .formula, code: "E", in: context)
        badMember.formula = "=POU.max"

        var engine = FormulaEngine(sheet: sheet)
        #expect(engine.maximum(of: san) == .success(65))
        #expect(engine.value(of: san) == .success(65))
        #expect(engine.value(of: a) == .failure(.circularReference))
        #expect(engine.value(of: b) == .failure(.circularReference))
        #expect(engine.value(of: selfRef) == .failure(.circularReference))
        #expect(engine.value(of: unknown) == .failure(.unknownReference("XYZ")))
        #expect(engine.value(of: badMember) == .failure(.unknownReference("POU.max")))
        #expect(engine.value(of: pou) == .success(13))

        // Valeur saisie : elle remplace le calcul (et casse le cycle).
        san.numberValue = 47
        selfRef.numberValue = 4
        engine = FormulaEngine(sheet: sheet)
        #expect(engine.value(of: san) == .success(47))
        #expect(engine.maximum(of: san) == .success(65))
        #expect(engine.value(of: selfRef) == .success(4))
    }
}
