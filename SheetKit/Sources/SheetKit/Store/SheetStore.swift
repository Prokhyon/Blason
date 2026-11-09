import Foundation
import SwiftData

/// Plan de migration : une seule version pour l'instant. Chaque évolution du modèle
/// ajoutera un `SheetSchemaV2` et une étape ici.
public enum SheetMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [SheetSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}

public enum SheetStore {
    /// Révision du modèle pendant le développement. **À incrémenter à chaque modification
    /// du modèle** tant que la V1 n'est pas utilisée pour de vrai : l'app de développement
    /// recrée alors la base. Sans cela, SwiftData migre silencieusement l'ancienne base
    /// (constaté en M2 : tableaux perdus, colonnes ignorées).
    public static let developmentRevision = 4

    public static var schema: Schema { Schema(versionedSchema: SheetSchemaV1.self) }

    /// Conteneur de l'app. Stockage local uniquement (iCloud prévu en V1.2).
    /// Le fichier s'appelle `CharacterSheet.store` : l'ancien `default.store` (modèle v0) est ignoré.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration("CharacterSheet", schema: schema, cloudKitDatabase: .none)
        return try ModelContainer(
            for: schema,
            migrationPlan: SheetMigrationPlan.self,
            configurations: configuration
        )
    }

    /// Identifiants des objets insérés, modifiés ou supprimés lors d'un enregistrement
    /// (notification `ModelContext.didSave`).
    public static func savedIdentifiers(in notification: Notification) -> [PersistentIdentifier] {
        let keys: [ModelContext.NotificationKey] = [.insertedIdentifiers, .updatedIdentifiers, .deletedIdentifiers]
        return keys.flatMap { key in
            notification.userInfo?[key.rawValue] as? [PersistentIdentifier] ?? []
        }
    }

    /// Supprime le fichier de la base locale. Réservé au développement : tant que la V1
    /// n'est pas utilisée pour de vrai, le schéma V1 évolue sans migration.
    public static func destroyStore() {
        let url = ModelConfiguration("CharacterSheet", schema: schema, cloudKitDatabase: .none).url
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
    }
}
