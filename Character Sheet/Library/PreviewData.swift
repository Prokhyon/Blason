import SwiftData
import SheetKit

/// Base en mémoire avec les données de démo, pour les aperçus Xcode.
enum PreviewData {
    static let container: ModelContainer = {
        do {
            let container = try SheetStore.makeContainer(inMemory: true)
            try DemoData.seedIfEmpty(in: container.mainContext)
            return container
        } catch {
            fatalError("Aperçu : \(error)")
        }
    }()
}
