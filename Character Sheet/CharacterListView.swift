import SwiftUI
import SwiftData

struct CharacterListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Character.lastEditedDate, order: .reverse) private var characters: [Character]

    @State private var showingCreateSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(characters) { character in
                    NavigationLink {
                        CharacterView(character: character)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(character.fullName)
                            if let layout = character.layout {
                                Text(layout.name)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteCharacters)
            }
            .overlay {
                if characters.isEmpty {
                    ContentUnavailableView("No Characters", systemImage: "person.slash", description: Text("Tap + to create a character."))
                }
            }
            .navigationTitle("Characters")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingCreateSheet = true } label: {
                        Label("New", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateCharacterView()
            }
        }
    }

    private func deleteCharacters(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(characters[index])
        }
    }
}

struct CreateCharacterView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<CharacterLayout> { $0.isTemplate == true }, sort: \CharacterLayout.name) private var templates: [CharacterLayout]

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedTemplate: CharacterLayout?

    var body: some View {
        NavigationStack {
            Form {
                Section("Character Info") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                }

                Section("Template") {
                    Picker("Template", selection: $selectedTemplate) {
                        Text("None").tag(nil as CharacterLayout?)
                        ForEach(templates) { template in
                            Text(template.name).tag(template as CharacterLayout?)
                        }
                    }
                }
            }
            .navigationTitle("New Character")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createCharacter() }
                }
            }
        }
    }

    private func createCharacter() {
        let character = Character(
            firstName: firstName.isEmpty ? nil : firstName,
            lastName: lastName.isEmpty ? nil : lastName,
            layout: selectedTemplate
        )
        modelContext.insert(character)
        character.ensureFieldValues()
        dismiss()
    }
}
