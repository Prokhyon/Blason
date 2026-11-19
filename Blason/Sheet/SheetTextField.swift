import SwiftUI

// Saisie au toucher (SPEC §5.17, fluidité) : en Remplir, une valeur s'affiche comme une case de
// saisie, et le vrai champ (`UITextField`) n'existe que pendant qu'on la modifie. SwiftUI remettait
// à jour chaque champ de la page à chaque changement de la fiche : avec les quelque 200 champs des
// Compétences, une frappe coûtait près de 200 ms, et le clavier tardait à s'ouvrir et à se fermer.
// Toucher la valeur crée le champ et lui donne le focus ; en le quittant, il redevient du texte.

/// Champ de texte de la fiche, créé au toucher.
///
/// Reçoit une valeur et non un `Binding` (voir `NumberField`). Le texte suit la frappe.
struct SheetTextField: View {
    let text: String
    private let setText: (String) -> Void
    let prompt: String?
    let axis: Axis
    /// Hauteur minimale en lignes (texte long).
    let minLines: Int

    init(text: Binding<String>, prompt: String? = nil, axis: Axis = .horizontal, minLines: Int = 1) {
        self.text = text.wrappedValue
        self.setText = { text.wrappedValue = $0 }
        self.prompt = prompt
        self.axis = axis
        self.minLines = minLines
    }

    @State private var id = UUID()
    @State private var isEditing = false
    @State private var draft = ""
    @FocusState private var isFocused: Bool
    @Environment(\.inputNavigator) private var navigator

    var body: some View {
        Group {
            if isEditing {
                EditingInputFrame(text: draft, multiline: axis == .vertical, minLines: minLines) {
                    TextField("", text: $draft, prompt: prompt.map(Text.init), axis: axis)
                        .focused($isFocused)
                        .tabNavigation(id: id)
                }
                .onAppear {
                    draft = text
                    isFocused = true
                }
                .onChange(of: draft) { _, newValue in
                    // Touche Tab du clavier à l'écran : elle insère une tabulation.
                    if newValue.contains("\t") {
                        draft = newValue.replacingOccurrences(of: "\t", with: "")
                        navigator?.move(from: id, forward: true)
                        return
                    }
                    if newValue != text { setText(newValue) }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused { isEditing = false }
                }
                .onSubmit { isFocused = false }
            } else {
                IdleInputLabel(text: text, prompt: prompt, multiline: axis == .vertical, minLines: minLines) {
                    isEditing = true
                }
            }
        }
        .inputNavigation(id: id) { isEditing = true }
    }
}

/// Valeur affichée comme le texte d'une case de saisie, en attendant qu'on la touche.
struct IdleInputLabel: View {
    let text: String
    let prompt: String?
    var multiline = false
    var minLines = 1
    let activate: () -> Void

    @Environment(\.multilineTextAlignment) private var alignment

    var body: some View {
        let isEmpty = text.isEmpty
        ZStack(alignment: frameAlignment) {
            if minLines > 1 {
                // Réserve la hauteur du champ vide (lignes minimales du texte long).
                Text(String(repeating: "\n", count: minLines - 1)).hidden()
            }
            Text(isEmpty ? (prompt ?? " ") : text)
                .foregroundStyle(isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .lineLimit(multiline ? nil : 1)
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .contentShape(Rectangle().inset(by: -6))
        .onTapGesture(perform: activate)
        .accessibilityElement(children: .ignore)
        .accessibilityValue(text)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Toucher deux fois pour modifier")
        .accessibilityAction { activate() }
        #if DEBUG
        // -demoEdit VALEUR : ouvre la saisie de la première case qui affiche cette valeur (mesures) ;
        // -demoEdit @multiline : celle du premier texte long.
        .task {
            guard let key = UserDefaults.standard.string(forKey: "demoEdit"),
                  key == text || (key == "@multiline" && multiline),
                  !Self.demoEditDone else { return }
            // La case a pu être recréée entre-temps (une mise en page qui change) : la nouvelle s'en charge.
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, !Self.demoEditDone else { return }
            Self.demoEditDone = true
            activate()
        }
        #endif
    }

    #if DEBUG
    nonisolated(unsafe) private static var demoEditDone = false
    #endif

    private var frameAlignment: Alignment {
        switch alignment {
        case .trailing: multiline ? .topTrailing : .trailing
        case .center: multiline ? .top : .center
        default: multiline ? .topLeading : .leading
        }
    }
}

/// Le champ ouvert prend la taille de la case au repos : un `UITextField` est un peu plus haut que
/// son texte, et la ligne (avec tout ce qui la suit) bougeait de 2 ou 3 points à l'ouverture.
/// Le texte invisible fixe la taille, le champ se pose dessus.
struct EditingInputFrame<Field: View>: View {
    let text: String
    var multiline = false
    var minLines = 1
    @ViewBuilder let field: () -> Field

    var body: some View {
        ZStack {
            if minLines > 1 {
                Text(String(repeating: "\n", count: minLines - 1))
            }
            Text(text.isEmpty ? " " : text)
                .lineLimit(multiline ? nil : 1)
        }
        .hidden()
        .frame(maxWidth: .infinity)
        .overlay(content: field)
    }
}

// MARK: - Tab : passer d'une case à l'autre

/// Ordre de saisie d'une page (Tab, Maj-Tab), dans l'ordre de lecture : les sections comme elles
/// se lisent (rangée, colonne, puis de haut en bas), puis dans chaque section ligne par ligne ;
/// un tableau réparti en colonnes se lit colonne après colonne.
///
/// Les cases s'inscrivent avec leur position dans la page ; Tab ouvre la saisie de la suivante.
@MainActor
final class InputNavigator {
    static let space = "blason.sheet-inputs"

    private struct Entry {
        var group: [Int]
        var frame: CGRect
        var activate: () -> Void
    }

    private var entries: [UUID: Entry] = [:]

    func update(_ id: UUID, group: [Int], frame: CGRect, activate: @escaping () -> Void) {
        entries[id] = Entry(group: group, frame: frame, activate: activate)
    }

    func remove(_ id: UUID) {
        entries[id] = nil
    }

    /// Ouvre la case suivante (ou précédente) ; faux s'il n'y en a pas.
    @discardableResult
    func move(from id: UUID, forward: Bool) -> Bool {
        let order = ordered()
        guard let index = order.firstIndex(of: id) else { return false }
        let target = index + (forward ? 1 : -1)
        guard order.indices.contains(target), let entry = entries[order[target]] else { return false }
        entry.activate()
        return true
    }

    private func ordered() -> [UUID] {
        let groups = Dictionary(grouping: entries, by: \.value.group)
        return groups.keys.sorted { $0.lexicographicallyPrecedes($1) }.flatMap { key in
            // Lignes : les cases dont le milieu tombe dans la hauteur de la première de la ligne.
            let byHeight = groups[key, default: []].sorted { $0.value.frame.midY < $1.value.frame.midY }
            var lines: [[(key: UUID, value: Entry)]] = []
            for item in byHeight {
                if let first = lines.last?.first, item.value.frame.midY <= first.value.frame.maxY {
                    lines[lines.count - 1].append(item)
                } else {
                    lines.append([item])
                }
            }
            return lines.flatMap { $0.sorted { $0.value.frame.minX < $1.value.frame.minX }.map(\.key) }
        }
    }
}

extension EnvironmentValues {
    /// Ordre de saisie de la page affichée (aucun hors de la page : bulles, inspecteur).
    @Entry var inputNavigator: InputNavigator?
    /// Place de la section (et de la colonne d'un tableau) dans l'ordre de lecture.
    @Entry var inputGroup: [Int] = []
}

extension View {
    /// Inscrit une case dans l'ordre de saisie de la page.
    func inputNavigation(id: UUID, activate: @escaping () -> Void) -> some View {
        modifier(InputRegistration(id: id, activate: activate))
    }

    /// Dans le champ ouvert : Tab ouvre la case suivante, Maj-Tab la précédente.
    func tabNavigation(id: UUID) -> some View {
        modifier(TabNavigation(id: id))
    }
}

private struct InputRegistration: ViewModifier {
    let id: UUID
    let activate: () -> Void

    @Environment(\.inputNavigator) private var navigator
    @Environment(\.inputGroup) private var group

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(InputNavigator.space)) } action: { frame in
                navigator?.update(id, group: group, frame: frame, activate: activate)
            }
            .onDisappear { navigator?.remove(id) }
    }
}

private struct TabNavigation: ViewModifier {
    let id: UUID

    @Environment(\.inputNavigator) private var navigator

    func body(content: Content) -> some View {
        content
            .onKeyPress(.tab, phases: .down) { press in
                guard let navigator else { return .ignored }
                return navigator.move(from: id, forward: !press.modifiers.contains(.shift)) ? .handled : .ignored
            }
            #if DEBUG
            // -demoTabSteps N : après -demoEdit, passe N fois à la case suivante (vérification).
            .task {
                guard InputNavigatorDemo.remaining > 0 else { return }
                InputNavigatorDemo.remaining -= 1
                try? await Task.sleep(for: .seconds(1))
                navigator?.move(from: id, forward: true)
            }
            #endif
    }
}

#if DEBUG
enum InputNavigatorDemo {
    nonisolated(unsafe) static var remaining = UserDefaults.standard.integer(forKey: "demoTabSteps")
}
#endif
