//
//  Character_SheetApp.swift
//  Character Sheet
//
//  Created by Loris Thomas on 08.04.2026.
//

import SwiftUI
import SwiftData

@main
struct Character_SheetApp: App {
    let id = UUID()
    @State var characterModel = CharacterModel()
//    var sharedModelContainer: ModelContainer = {
//        let schema = Schema([
//            Character.self,
//        ])
//        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
//
//        do {
//            return try ModelContainer(for: schema, configurations: [modelConfiguration])
//        } catch {
//            fatalError("Could not create ModelContainer: \(error)")
//        }
//    }()

    var body: some Scene {
        WindowGroup {
            CharacterView(character: Character(id: UUID(), firstName: "John", lastName: "Smith", age: 29, characterLayout: id, fieldValues: [], creationDate: Date(), lastEditedDate: Date()),
                          characterLayout: CharacterLayout(id: id, name: "Layout1", gameSystem: nil, template: false, gridColumns: 3, sections: [
                            Section(title: "Header", order: 1, width: 3, height: 1,gridOrigin: GridPosition(x: 0, y: 0), fields: [Field(order: 1, kind: .text)]),
                            Section(title: "Body", order: 2, width: 1, height: 2, gridOrigin: GridPosition(x: 0, y: 1), fields: []),
                            Section(title: "Skills", order: 3, width: 2, height: 2, gridOrigin: GridPosition(x: 1, y: 1), fields: [])
                          ]))
            .environmentObject(CharacterModel())
        }
//        .modelContainer(for: Character.self)
    }
}
