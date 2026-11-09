import SwiftUI
import SheetKit

/// « Coller une liste » : une ligne par champ ou par ligne de tableau (SPEC §4.1).
struct PasteListView: View {
    let request: PasteListRequest
    let editor: StructureEditor

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var kind: FieldKind = .integer
    @FocusState private var focused: Bool

    private var entries: [ListEntry] { ListImport.parse(text) }

    private var isFields: Bool {
        if case .fields = request.target { return true }
        return false
    }

    private var destination: String {
        switch request.target {
        case .fields(let section, _):
            section.title.isEmpty ? String(localized: "la section") : "« \(section.title) »"
        case .rows(let section, let group):
            if let group, !group.title.isEmpty { "« \(group.title) »" } else if section.title.isEmpty { String(localized: "le tableau") } else { "« \(section.title) »" }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if isFields {
                    Picker("Type des champs", selection: $kind) {
                        ForEach(FieldKind.allCases, id: \.self) { kind in
                            Label(kind.title, systemImage: kind.symbol).tag(kind)
                        }
                    }
                }
                Section {
                    TextEditor(text: $text)
                        .font(.body.monospaced())
                        .frame(minHeight: 220)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focused)
                } header: {
                    Text("Une ligne par élément")
                } footer: {
                    Text(help)
                }
                if !entries.isEmpty {
                    Section("Aperçu") {
                        ForEach(Array(entries.prefix(8).enumerated()), id: \.offset) { _, entry in
                            preview(entry)
                        }
                        if entries.count > 8 {
                            Text("… et \(entries.count - 8) autres").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Coller dans \(destination)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(addTitle) {
                        editor.importList(text, request: request, kind: kind)
                        dismiss()
                    }
                    .disabled(entries.isEmpty)
                }
            }
            .onAppear {
                if case .fields(let section, let after) = request.target {
                    kind = after?.kind ?? section.sortedFields.last?.kind ?? .integer
                }
                focused = true
            }
        }
    }

    private var addTitle: LocalizedStringKey {
        let count = entries.filter { !$0.isGroup }.count
        return count == 0 ? "Ajouter" : "Ajouter \(count)"
    }

    private var help: LocalizedStringKey {
        if isFields {
            "Valeurs séparées par « ; » ou une tabulation (copie depuis un tableur) : libellé;valeur;code. Exemple : Force;11;FOR. Une valeur commençant par « = » est une formule ; une ressource accepte 47/65."
        } else {
            "Libellé puis une valeur par colonne saisissable, séparées par « ; » ou une tabulation. Exemple : Marchander;5. « # Communication » crée un groupe (« # Communication;5 » avec sa valeur). « Langue (…) » : spécialisation à préciser ; « Monter (Navire) » : déjà précisée."
        }
    }

    @ViewBuilder
    private func preview(_ entry: ListEntry) -> some View {
        if entry.isGroup {
            Label {
                Text(entry.values.first.map { "\(entry.label) (\($0))" } ?? entry.label).bold()
            } icon: {
                Image(systemName: "folder")
            }
        } else {
            HStack {
                Text(entry.label.isEmpty ? String(localized: "Sans libellé") : entry.label)
                Spacer()
                Text(entry.values.joined(separator: " · "))
                    .foregroundStyle(.secondary)
                    .monospaced()
            }
        }
    }
}
