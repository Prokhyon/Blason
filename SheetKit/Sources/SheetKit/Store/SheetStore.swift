import Foundation
import SwiftData

/// Plan de migration : une seule version pour l'instant. Chaque évolution du modèle
/// ajoutera un `SheetSchemaV2` et une étape ici.
public enum SheetMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SheetSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum SheetStore {
    /// Le schéma V1 est **figé** depuis la synchronisation iCloud (test « Schéma V1 figé ») : de vraies
    /// fiches existent, sur l'appareil et dans iCloud. Tout changement du modèle passe par un
    /// `SheetSchemaV2`, une étape de `SheetMigrationPlan` et un test de migration ; côté iCloud,
    /// il ne fait qu'ajouter (SPEC §5.7). Sans nouvelle version, SwiftData migre silencieusement
    /// l'ancienne base (constaté en M2 : tableaux perdus, colonnes ignorées).
    public static var schema: Schema { Schema(versionedSchema: SheetSchemaV1.self) }

    /// Conteneur iCloud de l'app (aussi déclaré dans `Blason.entitlements`).
    public static let cloudContainerID = "iCloud.ch.loristhomas.blason"

    /// Conteneur de l'app. `syncsWithICloud` : la base se synchronise avec la base privée iCloud
    /// de l'utilisateur (SPEC §5.10) ; sans compte iCloud, elle reste locale et se synchronisera
    /// à la connexion. Les tests et les aperçus restent locaux.
    /// Le fichier s'appelle `Blason.store` ; une base `CharacterSheet.store` (ancien nom du projet)
    /// est d'abord renommée. L'ancien `default.store` (modèle v0) est ignoré.
    public static func makeContainer(inMemory: Bool = false, syncsWithICloud: Bool = false) throws -> ModelContainer {
        let cloud: ModelConfiguration.CloudKitDatabase = syncsWithICloud && !inMemory
            ? .private(cloudContainerID) : .none
        if !inMemory {
            moveLegacyStore(in: storeURL.deletingLastPathComponent())
        }
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(storeName, schema: schema, cloudKitDatabase: cloud)
        return try ModelContainer(
            for: schema,
            migrationPlan: SheetMigrationPlan.self,
            configurations: configuration
        )
    }

    /// Nom de la base : `Blason.store`.
    public static let storeName = "Blason"
    /// Nom de la base avant le renommage du projet (11 novembre 2026).
    static let legacyStoreName = "CharacterSheet"

    /// Emplacement de la base (dossier Application Support de l'app).
    static var storeURL: URL {
        ModelConfiguration(storeName, schema: schema, cloudKitDatabase: .none).url
    }

    /// Renomme une base `CharacterSheet.store` en `Blason.store`, avec ses fichiers associés :
    /// journal (`-wal`, `-shm`), images (`.CharacterSheet_SUPPORT`) et cache iCloud
    /// (`CharacterSheet_ckAssets`). L'état de la synchronisation est dans la base : il suit.
    /// Ne fait rien si `Blason.store` existe déjà. La base elle-même est déplacée en dernier :
    /// si un déplacement échoue, le suivant reprend au prochain lancement.
    static func moveLegacyStore(in directory: URL) {
        let fileManager = FileManager.default
        let old = directory.appending(path: "\(legacyStoreName).store")
        let new = directory.appending(path: "\(storeName).store")
        guard fileManager.fileExists(atPath: old.path), !fileManager.fileExists(atPath: new.path) else { return }
        let companions = [
            ("\(legacyStoreName).store-wal", "\(storeName).store-wal"),
            ("\(legacyStoreName).store-shm", "\(storeName).store-shm"),
            (".\(legacyStoreName)_SUPPORT", ".\(storeName)_SUPPORT"),
            ("\(legacyStoreName)_ckAssets", "\(storeName)_ckAssets"),
            ("\(legacyStoreName).store", "\(storeName).store"),
        ]
        for (from, to) in companions {
            let source = directory.appending(path: from)
            let destination = directory.appending(path: to)
            guard fileManager.fileExists(atPath: source.path), !fileManager.fileExists(atPath: destination.path) else { continue }
            try? fileManager.moveItem(at: source, to: destination)
        }
    }

    /// Identifiants des objets insérés, modifiés ou supprimés lors d'un enregistrement
    /// (notification `ModelContext.didSave`).
    public static func savedIdentifiers(in notification: Notification) -> [PersistentIdentifier] {
        let keys: [ModelContext.NotificationKey] = [.insertedIdentifiers, .updatedIdentifiers, .deletedIdentifiers]
        return keys.flatMap { key in
            notification.userInfo?[key.rawValue] as? [PersistentIdentifier] ?? []
        }
    }

    /// Supprime la base locale, ses images et son cache iCloud. Réservé au développement, à la
    /// demande (`-resetStore YES`) : jamais automatique. Avec iCloud, les données reviennent ensuite
    /// du cloud : pour repartir de zéro, réinitialiser aussi l'environnement de développement
    /// dans CloudKit Console.
    public static func destroyStore() {
        let url = storeURL
        let directory = url.deletingLastPathComponent()
        let items = ["", "-shm", "-wal"].map { URL(fileURLWithPath: url.path + $0) }
            + [directory.appending(path: ".\(storeName)_SUPPORT"), directory.appending(path: "\(storeName)_ckAssets")]
        for item in items {
            try? FileManager.default.removeItem(at: item)
        }
    }
}
