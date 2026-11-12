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

@MainActor
@Suite("Base d'essai V2", .serialized)
struct DraftStoreTests {

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "DraftStore-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Base V1 sur disque, avec un template, sa fiche et une image en stockage externe.
    private func writeV1Store(in directory: URL) throws {
        let schema = Schema(versionedSchema: SheetSchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, url: directory.appending(path: "Blason.store"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        let template = SheetSchemaV1.SheetTemplate(name: "BRP", system: "Basic Roleplaying")
        context.insert(template)
        let sheet = SheetSchemaV1.Sheet()
        context.insert(sheet)
        template.sheet = sheet
        let page = SheetSchemaV1.Page(title: "Fiche")
        context.insert(page)
        page.sheet = sheet
        let row = SheetSchemaV1.SheetRow()
        context.insert(row)
        row.page = page
        let section = SheetSchemaV1.SheetSection(title: "Personnel")
        context.insert(section)
        section.row = row
        let portrait = SheetSchemaV1.SheetField(label: "Portrait", kind: .image)
        context.insert(portrait)
        portrait.section = section
        portrait.imageData = Data((0..<200_000).map { UInt8($0 % 251) })
        try context.save()
    }

    private func modificationDate(_ url: URL) throws -> Date? {
        try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date
    }

    /// Attend que la date de modification ne change plus pendant 0,3 s (3 s au plus).
    private func waitUntilUnchanged(_ url: URL) throws {
        var last = try modificationDate(url)
        var stableSteps = 0
        for _ in 0..<30 where stableSteps < 3 {
            Thread.sleep(forTimeInterval: 0.1)
            let current = try modificationDate(url)
            stableSteps = current == last ? stableSteps + 1 : 0
            last = current
        }
    }

    @Test("La base d'essai est une copie migrée de la base V1, qui reste intacte")
    func draftIsCopiedFromV1() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeV1Store(in: directory)
        let v1 = directory.appending(path: "Blason.store")
        // Le conteneur qui a écrit la base V1 se referme en arrière-plan et touche encore le fichier
        // (même contenu, nouvelle date) : on attend qu'il soit stable avant de mesurer.
        try waitUntilUnchanged(v1)
        let v1Date = try modificationDate(v1)
        let v1Data = try Data(contentsOf: v1)

        do {
            let (container, opening) = try SheetStore.openDraftStore(in: directory)
            #expect(opening == .createdFromV1)
            let context = ModelContext(container)
            let templates = try context.fetch(FetchDescriptor<SheetTemplate>())
            #expect(templates.map(\.name) == ["BRP"])
            let portrait = try #require(templates.first?.sheet?.allFields.first)
            #expect(portrait.imageData?.count == 200_000)
            // Le modèle V2 est utilisable : une Besace s'ajoute et s'enregistre.
            let row = try #require(templates.first?.sheet?.sortedPages.first?.sortedRows.first)
            row.addInventorySection(in: context)
            try context.save()
        }

        #expect(try modificationDate(v1) == v1Date)
        #expect(try Data(contentsOf: v1) == v1Data)

        // Lancement suivant : la base d'essai s'ouvre telle quelle, Besace comprise.
        let (container, opening) = try SheetStore.openDraftStore(in: directory)
        #expect(opening == .opened)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<Inventory>()) == 1)
    }

    @Test("Sans base V1, la base d'essai est neuve")
    func draftWithoutV1() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (container, opening) = try SheetStore.openDraftStore(in: directory)
        #expect(opening == .createdFromV1)
        #expect(try ModelContext(container).fetchCount(FetchDescriptor<SheetTemplate>()) == 0)
        #expect(!FileManager.default.fileExists(atPath: directory.appending(path: "Blason.store").path))
    }

    @Test("Une base d'essai illisible est mise de côté, jamais effacée, puis recréée depuis V1")
    func unreadableDraftIsSetAside() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeV1Store(in: directory)
        let garbage = Data("pas une base".utf8)
        try garbage.write(to: directory.appending(path: "Blason-V2.store"))

        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let (container, opening) = try SheetStore.openDraftStore(in: directory, now: date)
        guard case .recreated(let setAside) = opening else {
            Issue.record("attendu : recréée, obtenu \(opening)"); return
        }
        #expect(try Data(contentsOf: directory.appending(path: setAside)) == garbage)
        #expect(try ModelContext(container).fetch(FetchDescriptor<SheetTemplate>()).map(\.name) == ["BRP"])
    }
}
