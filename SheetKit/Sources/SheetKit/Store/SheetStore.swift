import Foundation
import SwiftData

/// Plan de migration : V1 (figé) → V2 (brouillon, ajouts seulement).
public enum SheetMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SheetSchemaV1.self, SheetSchemaV2.self] }
    public static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SheetSchemaV1.self, toVersion: SheetSchemaV2.self)]
    }
}

/// Ouverture de la base locale.
public enum StoreOpening: Equatable, Sendable {
    /// Base d'essai V2 ouverte telle quelle.
    case opened
    /// Base d'essai créée : copie de la base V1, migrée vers V2 (ou base neuve sans base V1).
    case createdFromV1
    /// La base d'essai ne s'ouvrait plus (modèle trop changé) : mise de côté sous ce nom,
    /// puis recréée depuis la base V1. Les fiches modifiées depuis sont dans les exports.
    case recreated(setAside: String)
}

public enum SheetStore {
    /// Modèle utilisé par l'app : V2 (brouillon). Le schéma V1 est **figé** (test « Schéma V1 figé ») :
    /// de vraies fiches existent, sur l'appareil et dans iCloud.
    public static var schema: Schema { Schema(versionedSchema: SheetSchemaV2.self) }

    /// Conteneur iCloud de l'app (aussi déclaré dans `Blason.entitlements`).
    /// La synchronisation est en pause (SPEC §5.16) : rien n'utilise ce conteneur pour l'instant.
    public static let cloudContainerID = "iCloud.ch.loristhomas.blason"

    /// Base en mémoire (tests, aperçus).
    public static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    // MARK: Base locale (iCloud en pause)

    /// Base V1 : `Blason.store`, celle qu'iCloud synchronisait. Pendant la mise au point du modèle V2,
    /// l'app ne l'ouvre plus et ne la modifie jamais (SPEC §5.16).
    public static let storeName = "Blason"
    /// Base d'essai du modèle V2 : `Blason-V2.store`, à côté de la base V1.
    public static let draftStoreName = "Blason-V2"
    /// Nom de la base avant le renommage du projet (11 novembre 2026).
    static let legacyStoreName = "CharacterSheet"

    /// Dossier des bases (Application Support de l'app).
    static var storeDirectory: URL {
        ModelConfiguration(storeName, schema: schema, cloudKitDatabase: .none).url.deletingLastPathComponent()
    }

    /// Ouvre la base d'essai V2, locale (sans iCloud). À la première ouverture, elle est créée
    /// par **copie** de la base V1, migrée vers V2 : la base V1 reste intacte. Si elle ne s'ouvre
    /// plus (brouillon du modèle trop changé), elle est mise de côté, jamais effacée, puis recréée.
    public static func openLocalStore() throws -> (ModelContainer, StoreOpening) {
        let directory = storeDirectory
        moveLegacyStore(in: directory)
        return try openDraftStore(in: directory)
    }

    static func openDraftStore(in directory: URL, now: Date = Date()) throws -> (ModelContainer, StoreOpening) {
        let fileManager = FileManager.default
        let draft = directory.appending(path: "\(draftStoreName).store")
        if fileManager.fileExists(atPath: draft.path) {
            do {
                // Sans plan de migration : un brouillon modifié par ajouts s'ouvre par migration légère.
                return (try ModelContainer(for: schema, configurations: configuration(at: draft)), .opened)
            } catch {
                let setAside = "\(draftStoreName) mise de côté \(timestamp(now))"
                moveStoreFiles(named: draftStoreName, to: setAside, in: directory)
                let container = try createDraftFromV1(in: directory)
                return (container, .recreated(setAside: "\(setAside).store"))
            }
        }
        return (try createDraftFromV1(in: directory), .createdFromV1)
    }

    /// Copie la base V1 (s'il y en a une) en base d'essai et l'ouvre avec le plan V1 → V2.
    private static func createDraftFromV1(in directory: URL) throws -> ModelContainer {
        copyStoreFiles(named: storeName, to: draftStoreName, in: directory)
        let draft = directory.appending(path: "\(draftStoreName).store")
        return try ModelContainer(for: schema, migrationPlan: SheetMigrationPlan.self, configurations: configuration(at: draft))
    }

    private static func configuration(at url: URL) -> ModelConfiguration {
        ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
    }

    /// Fichiers d'une base : la base, son journal (`-wal`, `-shm`) et ses images (`.Nom_SUPPORT`).
    /// Le cache iCloud (`Nom_ckAssets`) n'est pas copié.
    private static func storeFiles(named name: String) -> [String] {
        ["\(name).store", "\(name).store-wal", "\(name).store-shm", ".\(name)_SUPPORT"]
    }

    static func copyStoreFiles(named source: String, to destination: String, in directory: URL) {
        let fileManager = FileManager.default
        // La base en dernier : sans elle, une copie interrompue est refaite au lancement suivant.
        for (from, to) in zip(storeFiles(named: source), storeFiles(named: destination)).reversed() {
            let target = directory.appending(path: to)
            try? fileManager.removeItem(at: target)
            try? fileManager.copyItem(at: directory.appending(path: from), to: target)
        }
    }

    static func moveStoreFiles(named source: String, to destination: String, in directory: URL) {
        let fileManager = FileManager.default
        for (from, to) in zip(storeFiles(named: source), storeFiles(named: destination)) {
            try? fileManager.moveItem(at: directory.appending(path: from), to: directory.appending(path: to))
        }
    }

    private static func timestamp(_ date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        return String(format: "%04d-%02d-%02d %02dh%02d%02d",
                      components.year ?? 0, components.month ?? 0, components.day ?? 0,
                      components.hour ?? 0, components.minute ?? 0, components.second ?? 0)
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

    /// Supprime les bases locales (V1 et essai V2), leurs images et le cache iCloud. Réservé au
    /// développement, à la demande (`-resetStore YES`) : jamais automatique.
    public static func destroyStore() {
        let directory = storeDirectory
        for name in [storeName, draftStoreName] {
            for item in storeFiles(named: name) + ["\(name)_ckAssets"] {
                try? FileManager.default.removeItem(at: directory.appending(path: item))
            }
        }
    }
}
