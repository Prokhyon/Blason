import Foundation
import SwiftData
import Testing
@testable import SheetKit

@MainActor
@Suite("Base de données")
struct StoreTests {

    @Test("La notification d'enregistrement liste les objets modifiés")
    func didSaveListsChangedObjects() throws {
        let context = try makeContext()
        let leo = DemoData.leo(from: DemoData.brpTemplate(in: context), in: context)
        try context.save()
        let strength = try #require(leo.sheet?.field(code: "FOR"))

        var received: [PersistentIdentifier] = []
        let observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: context, queue: nil
        ) { notification in
            let identifiers = SheetStore.savedIdentifiers(in: notification)
            MainActor.assumeIsolated {
                received = identifiers
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        strength.numberValue = 12
        try context.save()

        #expect(received.contains(strength.persistentModelID))
        #expect(!received.contains(leo.persistentModelID))
    }

    @Test("Une base CharacterSheet.store est renommée en Blason.store, avec ses fichiers associés")
    func legacyStoreIsMoved() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appending(path: "LegacyStore-\(UUID())")
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        for name in ["CharacterSheet.store", "CharacterSheet.store-wal", "CharacterSheet.store-shm"] {
            try Data(name.utf8).write(to: directory.appending(path: name))
        }
        for folder in [".CharacterSheet_SUPPORT/_EXTERNAL_DATA", "CharacterSheet_ckAssets"] {
            try fileManager.createDirectory(at: directory.appending(path: folder), withIntermediateDirectories: true)
        }

        SheetStore.moveLegacyStore(in: directory)

        let contents = Set(try fileManager.contentsOfDirectory(atPath: directory.path))
        #expect(contents == ["Blason.store", "Blason.store-wal", "Blason.store-shm", ".Blason_SUPPORT", "Blason_ckAssets"])
        #expect(try Data(contentsOf: directory.appending(path: "Blason.store-wal")) == Data("CharacterSheet.store-wal".utf8))
        #expect(fileManager.fileExists(atPath: directory.appending(path: ".Blason_SUPPORT/_EXTERNAL_DATA").path))
    }

    @Test("Une base Blason.store existante n'est jamais remplacée par l'ancienne")
    func existingStoreIsKept() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appending(path: "LegacyStore-\(UUID())")
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }
        try Data("ancienne".utf8).write(to: directory.appending(path: "CharacterSheet.store"))
        try Data("nouvelle".utf8).write(to: directory.appending(path: "Blason.store"))

        SheetStore.moveLegacyStore(in: directory)

        #expect(try Data(contentsOf: directory.appending(path: "Blason.store")) == Data("nouvelle".utf8))
        #expect(fileManager.fileExists(atPath: directory.appending(path: "CharacterSheet.store").path))
    }
}
