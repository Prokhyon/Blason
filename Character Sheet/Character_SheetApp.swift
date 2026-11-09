import SwiftUI
import SwiftData
import SheetKit

@main
struct Character_SheetApp: App {
    let container: ModelContainer

    init() {
        #if DEBUG
        let revisionKey = "SheetStore.developmentRevision"
        if UserDefaults.standard.integer(forKey: revisionKey) != SheetStore.developmentRevision {
            SheetStore.destroyStore()
            UserDefaults.standard.set(SheetStore.developmentRevision, forKey: revisionKey)
        }
        #endif
        do {
            container = try SheetStore.makeContainer()
        } catch {
            #if DEBUG
            // Le schéma V1 évolue pendant le développement : une base incompatible est recréée.
            SheetStore.destroyStore()
            do {
                container = try SheetStore.makeContainer()
            } catch {
                fatalError("Impossible d'ouvrir la base de données : \(error)")
            }
            #else
            fatalError("Impossible d'ouvrir la base de données : \(error)")
            #endif
        }
        #if DEBUG
        // Template BRP et Leo, pour tester l'app sans tout saisir (jalon M1).
        try? DemoData.seedIfEmpty(in: container.mainContext)
        #endif
        // Annuler / Rétablir (⌘Z / ⇧⌘Z) sur toutes les modifications, après le remplissage de démo.
        container.mainContext.undoManager = UndoManager()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
        }
        .modelContainer(container)
    }
}
