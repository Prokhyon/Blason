//
//  Untitled.swift
//  Character Sheet
//
//  Created by Loris Thomas on 10.04.2026.
//
import SwiftUI
import UniformTypeIdentifiers

struct CharacterView: View {
    @EnvironmentObject var characterModel: CharacterModel
    @StateObject var gridModel = GridModel()
    
    @State var character: Character
    @State var characterLayout: CharacterLayout
    
    @State var editValues: Bool = false
    @State var editLayout: Bool = false
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                CharacterGridView(
                    character: $character,
                    characterLayout: $characterLayout,
                    cellSize: (
                        geometry.size.width -
                        CGFloat(gridModel.spacing * (characterLayout.gridColumns - 1))
                    )
                    / CGFloat(characterLayout.gridColumns),
                    
                    spacing: CGFloat(gridModel.spacing)
                )
                .environmentObject(gridModel)
                .environmentObject(characterModel)
            }
            
            .toolbar {
                if editValues {
                    Button(action: {
                        editLayout.toggle()
                    }) {
//                        Image(systemName: editValues ? "square.and.pencil" : "square")
                        Text("Edit layout")
                    }
                }
                Button(action: {
                    withAnimation {
                        editValues.toggle()
                    }
                }) {
                    Image(systemName: editValues ? "square.and.pencil" : "square")
                }
            }
            .sheet(isPresented: $editLayout) {
                GridLayoutEditView(characterLayout: $characterLayout)
            }
            .padding(.horizontal)
            .navigationTitle(character.fullName)
        }
    }
}

struct CharacterGridView: View {
    @EnvironmentObject var characterModel: CharacterModel
    @EnvironmentObject var gridModel: GridModel
    
    @Binding var character: Character
    @Binding var characterLayout: CharacterLayout
    
//    @Namespace var animation
    @State private var draggedItem: UUID?
    @State private var dragOffset: CGSize = .zero
    
    var cellSize: CGFloat
    var spacing: CGFloat
    
    var body: some View {
            GeometryReader { geometry in
                VStack {
                    ScrollView {
                        SpanningGridLayout(columns: characterLayout.gridColumns, cellSize: cellSize, spacing: spacing) {
                            ForEach(characterLayout.sections.enumerated(), id: \.offset) { index, item in
                                itemView(item, index: index)
                                    .layoutValue(key: GridItemKey.self, value: characterLayout.sections[index])
                                    .onAppear {
                                    }
                            }
                        }
                    }
                }
        }
    }
    
    func gridPosition(from location: CGPoint) -> GridPosition {
        let col = Int(location.x / (cellSize + spacing))
        let row = Int(location.y / (cellSize + spacing))
        return GridPosition(x: col, y: row)
    }
    @State var x: Int = 0
    @State var y: Int = 0
    
    
    func itemView(_ section: Section, index: Int) -> some View {
        RoundedRectangle(cornerRadius: 15)
            .fill(Color.gray)
            .overlay(
                VStack {
                    Text(section.title)
            })
    }
}

struct GridLayoutEditView: View {
    @EnvironmentObject var characterModel: CharacterModel
    @EnvironmentObject var gridModel: GridModel
    
    @Binding var characterLayout: CharacterLayout
    @State var items = ["0", "1", "2"]
    var body: some View {
        GeometryReader { geometry in
            HStack {
                ScrollView {
                    SpanningGridLayout(columns: characterLayout.gridColumns, cellSize: (geometry.size.width / 2 - 15 * CGFloat(characterLayout.gridColumns)) / CGFloat(characterLayout.gridColumns), spacing: 15) {
                        ForEach(characterLayout.sections, id: \.id) { section in
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.gray)
                                .overlay {
                                    Text(section.title)
                                        .font(.title2)
                                }
                                .layoutValue(key: GridItemKey.self, value: section)
                                .onAppear {
                                    print(section.gridOrigin)
                                }
                        }
                    }
                    .padding()
                }
                List {
                    ForEach(characterLayout.sections, id: \.id) { section in
                        Text(section.title)
                    }
                    .onMove { previousOffset, newOffset in
                        characterLayout.sections.move(fromOffsets: previousOffset, toOffset: newOffset)
                        gridModel.calculateItems(characterLayout: $characterLayout)
                        
                    }
                    .onDelete { section in
                        characterLayout.sections.remove(atOffsets: section)
                        gridModel.calculateItems(characterLayout: $characterLayout)
                    }
                    
                }
                .environment(\.editMode, .constant(.active))
                
                
//                .moveDisabled(false)
            }
        }
    }
}

//struct CharacterView_Previews: PreviewProvider {
//    static var previews: some View {
#Preview {
    @Previewable @State var characterModel = CharacterModel()
    let id: UUID = UUID()
    CharacterView(character: Character(id: UUID(), firstName: "John", lastName: "Smith", age: 29, characterLayout: id, fieldValues: [], creationDate: Date(), lastEditedDate: Date()),
                  characterLayout: CharacterLayout(id: id, name: "Layout1", gameSystem: nil, template: false, gridColumns: 3, sections: [
                    Section(title: "Header", order: 1, width: 3, height: 1,gridOrigin: GridPosition(x: 0, y: 0), fields: [Field(order: 1, kind: .text)]),
                    Section(title: "Body", order: 2, width: 1, height: 2, gridOrigin: GridPosition(x: 0, y: 1), fields: []),
                    Section(title: "Skills", order: 3, width: 2, height: 2, gridOrigin: GridPosition(x: 1, y: 1), fields: [])
                  ]))
    .environmentObject(characterModel)
    }
