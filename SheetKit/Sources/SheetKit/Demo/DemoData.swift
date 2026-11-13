import Foundation
import SwiftData

/// Données de démonstration : un template inspiré de la fiche Basic Roleplaying
/// et le personnage de référence « Leo » (voir SPEC.md, fiche de référence).
///
/// Les maximums des ressources de Leo sont saisis ; ils valent aussi ce que donnent les formules.
public enum DemoData {
    public static let templateName = "Basic Roleplaying (démo)"

    /// Modificateur de dégâts selon FOR + TAI (table BRP), +1d6 par tranche de 16 au-delà de 56.
    static let damageModifierTable = LookupTable(input: "FOR+TAI", rows: [
        .init(upTo: 12, result: "-1d6"), .init(upTo: 16, result: "-1d4"), .init(upTo: 24, result: "aucun"),
        .init(upTo: 32, result: "+1d4"), .init(upTo: 40, result: "+1d6"), .init(upTo: 56, result: "+2d6"),
        .init(upTo: 72, result: "+3d6"), .init(upTo: 88, result: "+4d6"), .init(upTo: 104, result: "+5d6"),
    ]).formula

    /// Ajoute l'exemple : le template BRP et Leo, à la demande (« Ajouter l'exemple BRP »).
    /// Rien n'est créé automatiquement : avec iCloud, chaque appareil vide créerait son exemple,
    /// en double après synchronisation (SPEC §5.10). Ajouter l'exemple deux fois donne deux copies.
    @discardableResult
    public static func addExample(in context: ModelContext) throws -> (template: SheetTemplate, character: PlayerCharacter) {
        let template = brpTemplate(in: context)
        let character = leo(from: template, in: context)
        try context.save()
        return (template, character)
    }

    /// Crée le template et Leo si la base ne contient aucun template (aperçus, captures).
    public static func seedIfEmpty(in context: ModelContext) throws {
        guard try context.fetchCount(FetchDescriptor<SheetTemplate>()) == 0 else { return }
        let template = brpTemplate(in: context)
        leo(from: template, in: context)
        try context.save()
    }

    // MARK: - Template BRP

    @discardableResult
    public static func brpTemplate(in context: ModelContext) -> SheetTemplate {
        let template = SheetTemplate.create(name: templateName, system: "BRP", in: context)
        template.notes = "Structure inspirée de la feuille de personnage Basic Roleplaying (Chaosium)."
        let builder = SheetBuilder(sheet: template.sheet!, context: context)

        builder.page("Personnage") { page in
            page.row(columns: [1, 1]) { row in
                row.fields("Personnel", column: 0, arrangement: .grid) { s in
                    s.field("Nom", code: "NOM", isName: true)
                    s.field("Joueur")
                    s.field("Culture")
                    s.field("Genre")
                    s.field("Latéralité", .choice, options: ["Droitier", "Gaucher", "Ambidextre"])
                    s.field("Profession")
                    s.field("Taille")
                    s.field("Poids")
                    s.field("Richesse")
                    s.field("Âge", .integer, code: "AGE")
                    s.field("Dieux / religion")
                    s.field("Mouvement", .integer, code: "MOUV", value: 10)
                    s.field("Traits distinctifs", .longText, placement: .top)
                    s.field("Description", .longText, placement: .top)
                }
                // Paires : chaque caractéristique en face de son jet ; TAI n'en a pas, le modificateur
                // de dégâts prend sa place.
                row.fields("Caractéristiques", column: 1, arrangement: .pairs, columns: 2) { s in
                    for code in ["FOR", "CON", "TAI", "INT", "POU", "DEX", "CHA", "EDU"] {
                        s.field(code == "EDU" ? "ÉDU" : code, .integer, code: code, min: 0, list: 0)
                    }
                    s.field("Effort", .formula, code: "EFFORT", formula: "=FOR*5", unit: "%", list: 1)
                    s.field("Endurance", .formula, code: "ENDURANCE", formula: "=CON*5", unit: "%", list: 1)
                    s.field("Modificateur de dégâts", .modifier, code: "MODDEG", formula: Self.damageModifierTable, list: 1)
                    s.field("Idée", .formula, code: "IDEE", formula: "=INT*5", unit: "%", list: 1)
                    s.field("Chance", .formula, code: "CHANCE", formula: "=POU*5", unit: "%", list: 1)
                    s.field("Agilité", .formula, code: "AGILITE", formula: "=DEX*5", unit: "%", list: 1)
                    s.field("Charme", .formula, code: "CHARME", formula: "=CHA*5", unit: "%", list: 1)
                    s.field("Connaissance", .formula, code: "SAVOIR", formula: "=EDU*5", unit: "%", list: 1)
                }
                row.fields("Points de vie", column: 1) { s in
                    s.field("Points de vie", .resource, code: "PV", formula: "=plafond((CON+TAI)/2)",
                            live: true, style: .track)
                    s.field("Blessure grave", .formula, code: "BLESSURE", formula: "=plafond(PV.max/2)")
                }
            }
        }

        builder.page("Compétences") { page in
            page.row { row in
                row.table("Compétences", labelTitle: "Compétence", displayColumns: 3) { t in
                    t.column("Base", .number, code: "base")
                    t.column("%", .percentage, code: "valeur", formula: "=base+groupe")
                    t.column("Exp.", .checkbox, code: "exp", live: true)

                    t.group("Communication", hasValue: true) { g in
                        g.row("Marchander", ["base": 5])
                        g.row("Commander", ["base": 5])
                        g.row("Déguisement", ["base": 1])
                        g.row("Étiquette", ["base": 5])
                        g.row("Baratin", ["base": 5])
                        g.row("Langue natale", specialization: true, ["base": "=EDU*5"])
                        g.row("Langue", specialization: true, ["base": 0])
                        g.row("Représentation", ["base": 5])
                        g.row("Persuasion", ["base": 15])
                        g.row("Statut", ["base": 15])
                        g.row("Enseigner", ["base": 10])
                    }
                    t.group("Manipulation", hasValue: true) { g in
                        g.row("Art", specialization: true, ["base": 5])
                        g.row("Artisanat", specialization: true, ["base": 5])
                        g.row("Démolition", ["base": 1])
                        g.row("Manipulation fine", ["base": 5])
                        g.row("Machinerie lourde", specialization: true, ["base": 1])
                        g.row("Réparer", specialization: true, ["base": 15])
                        g.row("Escamotage", ["base": 5])
                    }
                    t.group("Mental", hasValue: true) { g in
                        g.row("Évaluer", ["base": 15])
                        g.row("Premiers soins", ["base": 30])
                        g.row("Jeu", ["base": "=INT+POU"])
                        g.row("Connaissance", specialization: true, ["base": 5])
                        g.row("Lire / écrire", specialization: true, ["base": 0])
                        g.row("Médecine", ["base": 5])
                        g.row("Psychothérapie", ["base": 1])
                        g.row("Science", specialization: true, ["base": 1])
                        g.row("Stratégie", ["base": 1])
                        g.row("Technique", specialization: true, ["base": 5])
                    }
                    t.group("Perception", hasValue: true) { g in
                        g.row("Intuition", ["base": 5])
                        g.row("Écouter", ["base": 25])
                        g.row("S'orienter", ["base": 10])
                        g.row("Recherche", ["base": 25])
                        g.row("Sens", ["base": 10])
                        g.row("Repérer", ["base": 25])
                        g.row("Pister", ["base": 10])
                    }
                    t.group("Physique", hasValue: true) { g in
                        g.row("Grimper", ["base": 40])
                        g.row("Conduire", specialization: true, ["base": 20])
                        g.row("Voler", ["base": "=DEX*4"])
                        g.row("Se cacher", ["base": 10])
                        g.row("Sauter", ["base": 25])
                        g.row("Piloter", specialization: true, ["base": 1])
                        g.row("Projection", ["base": "=DEX*2"])
                        g.row("Monter", specialization: true, ["base": 5])
                        g.row("Discrétion", ["base": 10])
                        g.row("Nager", ["base": 25])
                        g.row("Lancer", ["base": 25])
                    }
                    t.group("Combat", hasValue: true) { g in
                        g.row("Esquive", ["base": "=DEX*2"])
                        g.row("Arts martiaux", ["base": 1])
                    }
                }
            }
            page.row { row in
                row.fields("Expérience") { s in
                    s.field("Bonus d'expérience", .percentage, code: "BONUSEXP")
                }
            }
        }

        builder.page("Combat") { page in
            page.row(columns: [2, 1]) { row in
                row.table("Armes", labelTitle: "Arme", column: 0) { t in
                    t.column("%", .percentage, code: "pct")
                    t.column("Dégâts", .text, code: "degats")
                    t.column("Portée", .text, code: "portee")
                    t.column("Attaques", .text, code: "attaques")
                    t.column("Longueur", .text, code: "longueur")
                    t.column("Mains", .text, code: "mains")
                    t.column("PV", .number, code: "pv")
                    t.column("Exp.", .checkbox, code: "exp", live: true)
                    t.group { g in
                        g.row("Bagarre", ["pct": 30, "degats": "1d3", "portee": "contact",
                                          "attaques": "1", "longueur": "courte", "mains": "1M"])
                        g.row("Lutte", ["pct": 25, "degats": "spécial", "portee": "contact",
                                        "attaques": "1", "longueur": "courte", "mains": "2M"])
                    }
                }
                row.fields("Notes de combat", column: 0) { s in
                    s.field("Notes de combat", .longText, placement: .top)
                }
                row.fields("Armure et bouclier", column: 1) { s in
                    s.field("Armure")
                    s.field("Valeur d'armure", .integer, code: "ARMURE")
                    s.field("Bouclier")
                    s.field("Bouclier %", .percentage, code: "BOUCLIER")
                    s.field("Dégâts du bouclier")
                    s.field("PV du bouclier", .integer)
                }
            }
        }

        builder.page("Pouvoirs et notes") { page in
            page.row(columns: [1, 1]) { row in
                row.fields("Points de personnage", column: 0) { s in
                    s.field("Niveau de puissance de la campagne")
                    s.field("Points de personnage", .integer, code: "PP_PERSO")
                }
                row.table("Défauts", labelTitle: "Défaut", column: 0) { t in
                    t.column("Points", .number, code: "points")
                    t.group()
                }
                row.fields("Points de pouvoir", column: 1) { s in
                    s.field("Points de pouvoir", .resource, code: "PM", formula: "=POU", live: true, style: .track)
                    s.field("Batterie", .integer, live: true)
                }
                row.fields("Fatigue", column: 1) { s in
                    s.field("Fatigue", .resource, code: "FATIGUE", formula: "=FOR+CON", live: true, style: .track)
                    s.field("Épuisé")
                }
                row.fields("Santé mentale", column: 1) { s in
                    s.field("Santé mentale", .resource, code: "SAN", formula: "=POU*5", live: true, style: .track)
                    s.field("Score de folie temporaire", .integer, code: "SFT")
                }
            }
            page.row { row in
                row.table("Pouvoirs", labelTitle: "Pouvoir") { t in
                    t.column("Énergie", .text, code: "energie")
                    t.column("Niv. actifs", .number, code: "actifs")
                    t.column("Niv. totaux", .number, code: "totaux")
                    t.column("Portée", .text, code: "portee")
                    t.column("Coût", .text, code: "cout")
                    t.column("Durée", .text, code: "duree")
                    t.column("Notes", .text, code: "notes")
                    t.column("Coût PP", .number, code: "coutpp")
                    t.group()
                }
            }
            page.row(columns: [2, 1]) { row in
                row.fields("Notes", column: 0) { s in
                    s.field("Notes", .longText, placement: .top)
                    s.field("Réputation", .percentage, code: "REPUTATION")
                }
                row.fields("Portrait", column: 1) { s in
                    s.field("Portrait", .image, placement: .top)
                }
            }
        }

        return template
    }

    // MARK: - Leo

    /// Personnage de référence, d'après « Leo character sheet.pdf ».
    @discardableResult
    public static func leo(from template: SheetTemplate, in context: ModelContext) -> PlayerCharacter {
        let leo = template.makeCharacter(named: "Leo", in: context)
        guard let sheet = leo.sheet else { return leo }

        let characteristics: [String: Double] = [
            "FOR": 11, "CON": 12, "TAI": 15, "INT": 15, "POU": 13, "DEX": 16, "CHA": 13,
        ]
        for (code, value) in characteristics {
            sheet.field(code: code)?.numberValue = value
        }

        func resource(_ code: String, _ current: Double, _ max: Double) {
            sheet.field(code: code)?.numberValue = current
            sheet.field(code: code)?.resourceMax = max
        }
        resource("PV", 14, 14)
        resource("PM", 13, 13)
        resource("FATIGUE", 27, 27)
        resource("SAN", 47, 65)

        if let skills = sheet.section(titled: "Compétences") {
            let values: [(String, String?, Double)] = [
                ("Commander", nil, 35), ("Étiquette", nil, 35), ("Persuasion", nil, 26),
                ("Statut", nil, 55), ("Évaluer", nil, 25), ("Connaissance", "Hautes sphères", 24),
                ("Lire / écrire", nil, 20), ("Stratégie", nil, 30), ("Écouter", nil, 50),
                ("S'orienter", nil, 35), ("Repérer", nil, 75), ("Pister", nil, 45),
                ("Grimper", nil, 65), ("Sauter", nil, 50), ("Monter", "Navire", 80),
                ("Nager", nil, 65), ("Esquive", nil, 32),
            ]
            for (label, specialization, value) in values {
                guard let row = skills.tableRow(label: label) else { continue }
                if let specialization { row.specialization = specialization }
                row.cell(code: "valeur")?.numberValue = value
            }
            if let combat = skills.group(titled: "Combat") {
                let fencing = skills.addRow(label: "Escrime", to: combat, isFromTemplate: false, in: context)
                fencing.cell(code: "valeur")?.numberValue = 70
            }
        }

        if let weapons = sheet.section(titled: "Armes"), let group = weapons.sortedGroups.first {
            let rows: [(String, [String: CellInput])] = [
                ("Fleuret", ["degats": "1d8"]),
                ("Pistolet", ["pct": 75, "degats": "1d12+2"]),
                ("Sabre d'officier", ["degats": "1d10+3"]),
                ("Poignard de main", ["degats": "1d8+4", "portee": "1d6+", "attaques": "2"]),
            ]
            for (label, cells) in rows {
                let row = weapons.addRow(label: label, to: group, isFromTemplate: false, in: context)
                for (code, input) in cells { row.cell(code: code)?.apply(input) }
            }
        }

        if let failings = sheet.section(titled: "Défauts"), let group = failings.sortedGroups.first {
            failings.addRow(label: "Impulsif", to: group, isFromTemplate: false, in: context)
        }

        return leo
    }
}
