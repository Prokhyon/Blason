//
//  Interactivegrid.swift
//  Character Sheet
//
//  Created by Loris Thomas on 10.04.2026.
//

import SwiftUI
import Combine

struct Item2: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var width: Int
    var height: Int
    var origin: GridPosition = .init(x: 0, y: 0)
    var spacer: Bool = false
}

class GridModel: ObservableObject {
//    @Published var items: [Item2] = [
//        Item2(name: "A", width: 1, height: 1),
//        Item2(name: "B", width: 2, height: 1),
//        Item2(name: "C", width: 1, height: 2),
//        Item2(name: "D", width: 1, height: 1),
//        Item2(name: "E", width: 2, height: 1),
//        Item2(name: "F", width: 1, height: 1),
//        Item2(name: "G", width: 1, height: 1),
//        Item2(name: "H", width: 1, height: 1),
//    ]
//    var characterLayout: Binding<CharacterLayout>
    var spacing: Int = 15
    
    var gridPositions: [GridPosition:UUID] = [:] //pas forcément nécéssaire, mais gardé au cas ou pour l'instant
    var originsIndex: [GridPosition:Int] = [:]//ou triable depuis la liste des items.origin
    
    @Published var currentItem: Section?
    
//    init(characterLayout: Binding<CharacterLayout>) {
//        self.characterLayout = characterLayout
//    }
    
    func calculateItems(characterLayout: Binding<CharacterLayout>) {
        var currentRow: Int = 0
        var currentColumn: Int = 0
        var newGridPositions: [GridPosition:UUID] = [:]
        
        func gridIterate() {
            currentColumn = (currentColumn + 1)%characterLayout.wrappedValue.gridColumns
//            print("Current column: \(currentColumn)")
            if currentColumn == 0 {
                currentRow += 1
//                print("Current row: \(currentRow)")
            }
            while newGridPositions.contains(where: { $0.key == GridPosition(x: currentColumn, y: currentRow)}) {
                currentColumn = (currentColumn + 1)%characterLayout.wrappedValue.gridColumns
//                print("Current column: \(currentColumn)")
                if currentColumn == 0 {
                    currentRow += 1
//                    print("Current row: \(currentRow)")
                }
            }
        }
        
        func testPosition(width: Int, height: Int, id: UUID) -> Bool {
            var tempArray: [GridPosition:UUID] = [:]
            for i in 0..<width {
                for j in 0..<height {
//                    print("testing \(currentColumn + i);\(currentRow + j)")
                    if newGridPositions.contains(where: { $0.key == GridPosition(x: currentColumn + i, y: currentRow + j)}) || currentColumn + i >= characterLayout.wrappedValue.gridColumns {
//                        print("cell taken")
                        return false
                    } else {
//                        print("cell available, adding \(id): \(currentColumn + i);\(currentRow + j)")
                        tempArray[GridPosition(x: currentColumn + i, y: currentRow + j)] = id
                    }
                }
            }
//            print("position found")
            newGridPositions.merge(tempArray, uniquingKeysWith: { $1 })
            return true
        }
        
        func findPosition(index: Int) {
            let width = characterLayout.wrappedValue.sections[index].width
            let height = characterLayout.wrappedValue.sections[index].height
            while !testPosition(width: width, height: height, id: characterLayout.wrappedValue.sections[index].id) {
                gridIterate()
            }
            characterLayout.wrappedValue.sections[index].gridOrigin = GridPosition(x: currentColumn, y: currentRow)
            print(GridPosition(x: currentColumn, y: currentRow))
            originsIndex[GridPosition(x: currentColumn, y: currentRow)] = index
        }
        
        for i in characterLayout.wrappedValue.sections.indices {
            if i < characterLayout.wrappedValue.sections.count {
//                print("searching for \(items[i].name)")
                withAnimation {
                    findPosition(index: i)
                }
                gridIterate()
            }
        }
        
        //Probsblement plus nécéssaire
        withAnimation {
            gridPositions = newGridPositions
        }
    }
    
    func linearIndex(for pos: GridPosition, columns: Int) -> Int {
        pos.y * columns + pos.x
    }
    
//    func reorderGrid(item: Item2, index: Int, to newOrigin: GridPosition) {
//        guard item.origin != newOrigin else { return }
//        
//        let targetIndex = linearIndex(for: newOrigin, columns: characterLayout.wrappedValue.gridColumns)
//        print("targetIndex: ", targetIndex)
//        
////        let sortedItems = items.sorted {
////            ($0.origin.y, $0.origin.x) < ($1.origin.y, $1.origin.x)
////        }
//        
//        let insertAfter = characterLayout.wrappedValue.sections
//            .enumerated()
//            .filter {
//                linearIndex(for: $0.element.gridOrigin, columns: characterLayout.wrappedValue.gridColumns) < targetIndex
//            }
//            .max {
//                linearIndex(for: $0.element.gridOrigin, columns: characterLayout.wrappedValue.gridColumns) <
//                linearIndex(for: $1.element.gridOrigin, columns: characterLayout.wrappedValue.gridColumns)
//            }?.offset
//
////        var newPosition = items.first(where: { $0.origin == insertAfter })
//        // recompute your dictionary safely
////        let newItems = recomputeLayout(moving: item.id, to: newOrigin)
//        
//
//        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
//            characterLayout.wrappedValue.sections.move(fromOffsets: IndexSet(integer: index), toOffset: insertAfter ?? index)
//            calculateItems()
//        }
//    }
    
}
