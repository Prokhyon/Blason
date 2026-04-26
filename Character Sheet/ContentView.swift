import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            CharacterListView()
                .tabItem {
                    Label("Characters", systemImage: "person.3")
                }

            TemplateListView()
                .tabItem {
                    Label("Templates", systemImage: "doc.text")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Character.self,
            CharacterLayout.self,
            LayoutSection.self,
            Field.self,
            CharacterFieldValue.self
        ], inMemory: true)
}
