import SwiftUI
import SwiftData
import SheetKit

@main
struct Character_SheetApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try SheetStore.makeContainer()
        } catch {
            fatalError("Impossible d'ouvrir la base de données : \(error)")
        }
        #if DEBUG
        // Template BRP et Leo, pour tester l'app sans tout saisir (jalon M1).
        try? DemoData.seedIfEmpty(in: container.mainContext)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
        .modelContainer(container)
    }
}
