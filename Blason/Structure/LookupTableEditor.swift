import SwiftUI
import SheetKit

/// Bouton de l'inspecteur qui ouvre l'éditeur de table de correspondance pour une formule.
struct LookupTableButton: View {
    @Binding var formula: String?

    @State private var isEditing = false

    var body: some View {
        Button {
            isEditing = true
        } label: {
            Label(LookupTable(formula: formula ?? "") == nil ? "Table de correspondance…" : "Modifier la table…",
                  systemImage: "tablecells")
        }
        .sheet(isPresented: $isEditing) {
            LookupTableEditor(formula: $formula)
        }
        #if DEBUG
        // Captures : -demoTableEditor YES ouvre l'éditeur du champ sélectionné (-demoSelect MODDEG).
        .onAppear {
            if UserDefaults.standard.bool(forKey: "demoTableEditor") { isEditing = true }
        }
        #endif
    }
}

/// Éditeur d'une table de correspondance (ex. modificateur de dégâts selon FOR+TAI) :
/// lignes « jusqu'à … → résultat », écrites dans la formule en `=table(…)`.
struct LookupTableEditor: View {
    @Binding var formula: String?

    @Environment(\.dismiss) private var dismiss
    @State private var table: LookupTable
    /// La formule actuelle est autre chose qu'une table : la valider la remplace.
    private let replacesFormula: Bool

    init(formula: Binding<String?>) {
        _formula = formula
        let existing = formula.wrappedValue.flatMap(LookupTable.init(formula:))
        _table = State(initialValue: existing ?? LookupTable(rows: [.init(upTo: nil, result: "")]))
        replacesFormula = existing == nil && !(formula.wrappedValue ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Valeur cherchée", text: $table.input, prompt: Text("ex. FOR+TAI"))
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Valeur cherchée")
                } footer: {
                    if let error = inputError {
                        FormulaErrorBadge(error: error, showsMessage: true)
                    } else {
                        Text("Une formule, sans « = » : un code (FOR), un calcul (FOR+TAI)…")
                    }
                }

                Section {
                    ForEach(table.rows.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            Text("Jusqu'à")
                                .foregroundStyle(.secondary)
                            NumberField(value: $table.rows[index].upTo, integer: false, prompt: "seuil", width: 64,
                                        accessibilityName: "Seuil de la ligne \(index + 1)")
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                            TextField("Résultat", text: $table.rows[index].result, prompt: Text("ex. +1d4"))
                                .accessibilityLabel("Résultat de la ligne \(index + 1)")
                        }
                    }
                    .onDelete { table.rows.remove(atOffsets: $0) }
                    .onMove { table.rows.move(fromOffsets: $0, toOffset: $1) }
                    Button("Ajouter une ligne", systemImage: "plus") {
                        table.rows.append(.init(upTo: nil, result: ""))
                    }
                    LabeledContent("Au-delà") {
                        TextField("Au-delà", text: $table.otherwise, prompt: Text("rien"))
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Correspondances")
                } footer: {
                    if !isAscending {
                        Text("Les seuils doivent aller croissant : la première ligne dont le seuil atteint la valeur l'emporte.")
                            .foregroundStyle(.red)
                    } else {
                        Text("Chaque ligne vaut jusqu'à son seuil compris. Un résultat est un nombre (2) ou un texte (+1d4). « Au-delà » : au-dessus du dernier seuil ; vide, le champ reste vide.")
                    }
                }

                Section {
                    Text(table.formula ?? "—")
                        .font(.callout.monospaced())
                        .foregroundStyle(table.formula == nil ? .tertiary : .secondary)
                        .textSelection(.enabled)
                } header: {
                    Text("Formule")
                } footer: {
                    if replacesFormula {
                        Text("Valider remplace la formule actuelle (\(formula ?? "")).")
                    }
                }
            }
            .navigationTitle("Table de correspondance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        formula = table.formula
                        dismiss()
                    }
                    .disabled(table.formula == nil || inputError != nil)
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
    }

    private var inputError: FormulaError? {
        let input = table.input.trimmingCharacters(in: .whitespaces)
        return input.isEmpty ? nil : FormulaEngine.check(input)
    }

    private var isAscending: Bool {
        let thresholds = table.rows.compactMap(\.upTo)
        return zip(thresholds, thresholds.dropFirst()).allSatisfy { $0 < $1 }
    }
}
