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
}
