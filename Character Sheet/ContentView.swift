//
//  ContentView.swift
//  Character Sheet
//
//  Created by Loris Thomas on 08.04.2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
//    var characters: [Character]
    @StateObject var characterModel: CharacterModel = CharacterModel()
//    @Query var CharacterLayoutList: [CharacterLayout]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(characterModel.characters) { character in
                    NavigationLink {
                        Text(character.fullName)
                    } label: {
                        Text(character.fullName)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
//                ToolbarItem {
//                    Button(action: addSamples) {
//                        Text("Add samples")
//                    }
//                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
//            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
//                modelContext.delete(items[index])
            }
        }
    }
    
//    func addSamples() {
//        let sampleCharacter1 = Character(id: UUID(), firstName: "Loris", age: 24, characterLayout: UUID())
//        let sampleCharacter2 = Character(id: UUID(), firstName: "Lucas", age: 24, characterLayout: UUID())
//        
//        modelContext.insert(sampleCharacter1)
//        modelContext.insert(sampleCharacter2)
//    }
}

#Preview {
//    do {
//        let config = ModelConfiguration(isStoredInMemoryOnly: true)
//        let container = try ModelContainer(for: Character.self, configurations: config)
//        
//        let example = Character(id: UUID(), firstName: "Arthur", lastName: "Dent", characterLayout: UUID())
//        return ContentView
//    }
    ContentView()
//        .modelContainer(for: Character.self)
}
