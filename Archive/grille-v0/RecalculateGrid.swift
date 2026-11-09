// Extrait de Character.swift (commit 6c6b2c9) : placement automatique des sections
// dans la grille à cellules carrées. Archivé pour référence, hors du build.

extension CharacterLayout {
    func recalculateGrid() {
        let sorted = sortedSections
        var occupied: [GridPosition: Bool] = [:]
        var currentRow = 0
        var currentColumn = 0

        func advance() {
            currentColumn = (currentColumn + 1) % gridColumns
            if currentColumn == 0 { currentRow += 1 }
            while occupied[GridPosition(x: currentColumn, y: currentRow)] == true {
                currentColumn = (currentColumn + 1) % gridColumns
                if currentColumn == 0 { currentRow += 1 }
            }
        }

        func canPlace(width: Int, height: Int) -> Bool {
            for dx in 0..<width {
                for dy in 0..<height {
                    if currentColumn + dx >= gridColumns { return false }
                    if occupied[GridPosition(x: currentColumn + dx, y: currentRow + dy)] == true {
                        return false
                    }
                }
            }
            return true
        }

        func place(section: LayoutSection) {
            for dx in 0..<section.width {
                for dy in 0..<section.height {
                    occupied[GridPosition(x: currentColumn + dx, y: currentRow + dy)] = true
                }
            }
            section.gridOrigin = GridPosition(x: currentColumn, y: currentRow)
        }

        for (index, section) in sorted.enumerated() {
            while !canPlace(width: section.width, height: section.height) {
                advance()
            }
            place(section: section)
            if index < sorted.count - 1 {
                advance()
            }
        }
    }
}

struct GridPosition: Codable, Hashable {
    var x: Int
    var y: Int

    init(x: Int = 0, y: Int = 0) {
        self.x = x
        self.y = y
    }
}
