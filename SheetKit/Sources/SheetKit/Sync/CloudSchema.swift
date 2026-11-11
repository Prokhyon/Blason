#if DEBUG
import CoreData
import SwiftData

extension SheetStore {
    /// Crée dans l'environnement de développement CloudKit **tous** les types d'enregistrement
    /// et tous leurs champs, même ceux qui n'ont encore jamais reçu de valeur (une image, par ex.).
    /// À lancer avant de déployer le schéma en production (CloudKit Console › Deploy Schema Changes) :
    /// sans cela, un champ absent du schéma de production fait échouer la synchronisation.
    ///
    /// Passe par une base temporaire : la vraie base n'est pas touchée. Nécessite un compte iCloud.
    public static func initializeCloudKitSchema() throws {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: SheetSchemaV1.models) else { return }
        let url = FileManager.default.temporaryDirectory.appending(path: "CloudKitSchema-\(UUID()).store")
        try autoreleasepool {
            let description = NSPersistentStoreDescription(url: url)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudContainerID)
            description.shouldAddStoreAsynchronously = false
            let container = NSPersistentCloudKitContainer(name: "CloudKitSchema", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            var loadError: Error?
            container.loadPersistentStores { _, error in loadError = error }
            if let loadError { throw loadError }
            try container.initializeCloudKitSchema()
            for store in container.persistentStoreCoordinator.persistentStores {
                try container.persistentStoreCoordinator.remove(store)
            }
        }
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }
}
#endif
