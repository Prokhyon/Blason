import SwiftUI
import SwiftData
import SheetKit

/// Création d'un personnage : nom et template (ou fiche vierge).
struct NewCharacterView: View {
    let templates: [SheetTemplate]
    let onCreate: (PlayerCharacter) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var templateID: PersistentIdentifier?
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom du personnage", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(create)
                }
                Section {
                    Picker("Template", selection: $templateID) {
                        ForEach(templates) { template in
                            Text(template.system.isEmpty ? template.name : "\(template.name) · \(template.system)")
                                .tag(Optional(template.persistentModelID))
                        }
                        Text("Fiche vierge").tag(PersistentIdentifier?.none)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Fiche")
                } footer: {
                    Text("Le personnage reçoit une copie du template : modifier le template plus tard ne changera pas ce personnage.")
                }
            }
            .navigationTitle("Nouveau personnage")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer", action: create)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                templateID = templateID ?? templates.first?.persistentModelID
                nameFocused = true
            }
        }
    }

    private func create() {
        guard !trimmedName.isEmpty else { return }
        let character: PlayerCharacter
        if let template = templates.first(where: { $0.persistentModelID == templateID }) {
            character = template.makeCharacter(named: trimmedName, in: context)
        } else {
            character = PlayerCharacter.createBlank(named: trimmedName, in: context)
        }
        dismiss()
        onCreate(character)
    }
}

/// Création d'un template : nom et système.
struct NewTemplateView: View {
    let onCreate: (SheetTemplate) -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var system = ""
    @FocusState private var nameFocused: Bool

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom du template", text: $name)
                        .focused($nameFocused)
                    TextField("Système de jeu", text: $system, prompt: Text("Système (ex. L'Appel de Cthulhu)"))
                } footer: {
                    Text("Le template s'ouvre ensuite en mode Structure pour construire la fiche.")
                }
            }
            .navigationTitle("Nouveau template")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer", action: create)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear { nameFocused = true }
        }
    }

    private func create() {
        guard !trimmedName.isEmpty else { return }
        let template = SheetTemplate.create(
            name: trimmedName,
            system: system.trimmingCharacters(in: .whitespacesAndNewlines),
            firstPage: "Fiche",
            in: context
        )
        dismiss()
        onCreate(template)
    }
}
