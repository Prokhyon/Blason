import SwiftUI
import SwiftData

@main
struct Character_SheetApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Character.self,
            CharacterLayout.self,
            LayoutSection.self,
            Field.self,
            CharacterFieldValue.self
        ])
    }
}
