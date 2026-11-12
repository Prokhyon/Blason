import SwiftUI
import SwiftData
import SheetKit

@main
struct BlasonApp: App {
    let container: ModelContainer
    /// Ouverture de la base (avis si la base d'essai V2 a dû être recréée).
    let storeOpening: StoreOpening
    @State private var syncMonitor = SyncMonitor()

    init() {
        #if DEBUG
        // Repartir d'une base vide : -resetStore YES (jamais automatique, voir SheetStore.destroyStore).
        if UserDefaults.standard.bool(forKey: "resetStore") {
            SheetStore.destroyStore()
        }
        // Avant de déployer le schéma iCloud en production : -initCloudKitSchema YES (voir CloudSchema).
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
            // Base locale, sans iCloud (synchronisation en pause, SPEC §5.16). Une base qui ne s'ouvre
            // pas n'est jamais effacée : elle contient de vraies fiches.
            (container, storeOpening) = try SheetStore.openLocalStore()
        } catch {
            fatalError("Impossible d'ouvrir la base de données : \(error)")
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
                .storeOpeningNotice(storeOpening)
                #if os(macOS)
                .frame(minWidth: 760, minHeight: 520)
                #endif
        }
        .modelContainer(container)
        .commands { BlasonCommands() }
        #if os(macOS)
        .defaultSize(width: 1280, height: 860)
        #endif
    }
}
