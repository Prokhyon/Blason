import SwiftUI
import SwiftData
import SheetKit

@main
struct Character_SheetApp: App {
    let container: ModelContainer
    @State private var syncMonitor = SyncMonitor()

    init() {
        #if DEBUG
        let revisionKey = "SheetStore.developmentRevision"
        if UserDefaults.standard.integer(forKey: revisionKey) != SheetStore.developmentRevision {
            SheetStore.destroyStore()
            UserDefaults.standard.set(SheetStore.developmentRevision, forKey: revisionKey)
        }
        #endif
        #if DEBUG
        // Avant de déployer le schéma iCloud en production : -initCloudKitSchema YES (voir SheetStore).
        if UserDefaults.standard.bool(forKey: "initCloudKitSchema") {
            do {
                try SheetStore.initializeCloudKitSchema()
                print("Schéma CloudKit initialisé.")
            } catch {
                print("Initialisation du schéma CloudKit impossible : \(error)")
            }
        }
        #endif
        do {
            container = try SheetStore.makeContainer(syncsWithICloud: true)
        } catch {
            #if DEBUG
            // Le schéma V1 évolue pendant le développement : une base incompatible est recréée.
            SheetStore.destroyStore()
            do {
                container = try SheetStore.makeContainer(syncsWithICloud: true)
            } catch {
                fatalError("Impossible d'ouvrir la base de données : \(error)")
            }
            #else
            fatalError("Impossible d'ouvrir la base de données : \(error)")
            #endif
        }
        #if DEBUG
        // Captures : -seedDemo YES crée le template BRP et Leo dans une base vide. Sinon, rien n'est
        // créé automatiquement : avec iCloud, chaque appareil créerait le sien (« Ajouter l'exemple BRP »).
        if UserDefaults.standard.bool(forKey: "seedDemo") {
            try? DemoData.seedIfEmpty(in: container.mainContext)
        }
        #endif
        // Annuler / Rétablir (⌘Z / ⇧⌘Z) sur toutes les modifications, après le remplissage de démo.
        container.mainContext.undoManager = UndoManager()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(syncMonitor)
        }
        .modelContainer(container)
    }
}
