//
//  CharacterModel.swift
//  Character Sheet
//
//  Created by Loris Thomas on 11.04.2026.
//

import Foundation
import Combine

class CharacterModel: ObservableObject {
    @Published var characters: [Character] = []
    @Published var characterLayoutList: [CharacterLayout] = []
    
    init() {
        let uuid = UUID()
        characterLayoutList = [CharacterLayout(id: uuid, name: "Default")]
        characters = [Character(id: UUID(), firstName: "John", lastName: "Smith", characterLayout: uuid)]
    }
}
