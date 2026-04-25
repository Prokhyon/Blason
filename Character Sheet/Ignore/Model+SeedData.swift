//
//  Model+SeedData.swift
//  Character Sheet
//
//  Created by Loris Thomas on 08.04.2026.
//

//import Foundation
//import SwiftData
//
//struct SeedData {
//    static func fantasyTemplate() -> CharacterTemplate {
//        let fields: [TemplateField] = [
//            TemplateField(label: "Race", kind: .text, order: 0, hint: "Elf, Human, Dwarf...", defaultValue: "Human", layoutWeight: 1),
//            TemplateField(label: "Class", kind: .text, order: 1, hint: "Warrior, Mage...", defaultValue: "Warrior", layoutWeight: 1),
//            TemplateField(label: "Level", kind: .integer, order: 2, minValue: 1, maxValue: 20, step: 1, defaultValue: "1", layoutWeight: 0.5),
//            TemplateField(label: "Strength", kind: .integer, order: 3, section: "Attributes", minValue: 1, maxValue: 20, step: 1, defaultValue: "10", layoutWeight: 0.5),
//            TemplateField(label: "Dexterity", kind: .integer, order: 4, section: "Attributes", minValue: 1, maxValue: 20, step: 1, defaultValue: "10", layoutWeight: 0.5),
//            TemplateField(label: "Intelligence", kind: .integer, order: 5, section: "Attributes", minValue: 1, maxValue: 20, step: 1, defaultValue: "10", layoutWeight: 0.5),
//            TemplateField(label: "Skills", kind: .multiOption, order: 6, section: "Skills", defaultValue: "Athletics,Stealth", options: ["Athletics","Stealth","Arcana","Persuasion"]),
//            TemplateField(label: "Biography", kind: .note, order: 7, hint: "Background story", section: "Notes")
//        ]
//        return CharacterTemplate(name: "Fantasy (Generic)", gameSystem: "Generic", fields: fields)
//    }
//}
