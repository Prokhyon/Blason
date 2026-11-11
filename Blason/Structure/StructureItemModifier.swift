import SwiftUI
import GameController
import SheetKit

/// État du clavier physique au moment d'un toucher (iOS n'expose pas les touches de modification
/// aux gestes SwiftUI).
enum HardwareKeyboard {
    /// ⌘ ou ⇧ enfoncée : le toucher ajoute à la sélection (ou en retire).
    static var isExtendingSelection: Bool {
        guard let input = GCKeyboard.coalesced?.keyboardInput else { return false }
        let keys: [GCKeyCode] = [.leftGUI, .rightGUI, .leftShift, .rightShift]
        return keys.contains { input.button(forKeyCode: $0)?.isPressed == true }
    }
}

extension View {
    /// En mode Structure : rend l'élément sélectionnable (toucher, ⌘ ou ⇧ + toucher pour ajouter
    /// à la sélection), déplaçable par glisser-déposer, avec un menu contextuel. Sans effet ailleurs.
    func structureItem(_ item: StructureItem) -> some View {
        modifier(StructureItemModifier(item: item))
    }
}

private struct StructureItemModifier: ViewModifier {
    let item: StructureItem

    @Environment(\.sheetMode) private var mode
    @Environment(\.structureEditor) private var editor
    @State private var isTargeted = false

    func body(content: Content) -> some View {
        if mode == .structure, let editor {
            let selected = editor.isSelected(item)
            content
                .padding(3)
                .contentShape(Rectangle())
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? Color.accentColor.opacity(0.10) : .clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2)
                }
                .overlay(alignment: .top) {
                    if isTargeted {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(height: 3)
                            .offset(y: -3)
                    }
                }
                .onTapGesture {
                    editor.select(item, extending: HardwareKeyboard.isExtendingSelection)
                }
                // Cible du défilement vers l'élément sélectionné (`scrollsToSelection`).
                .id(item)
                .contextMenu {
                    StructureItemMenu(item: item, editor: editor)
                }
                .draggable(editor.beginDrag(item))
                .dropDestination(for: String.self) { tokens, _ in
                    tokens.contains(StructureEditor.dragToken) && editor.drop(onto: item)
                } isTargeted: {
                    isTargeted = $0
                }
        } else {
            content
        }
    }
}

/// Menu contextuel d'un élément : il agit sur l'élément (et la sélection s'il en fait partie).
private struct StructureItemMenu: View {
    let item: StructureItem
    let editor: StructureEditor

    var body: some View {
        Button(editor.isSelected(item) ? "Retirer de la sélection" : "Ajouter à la sélection",
               systemImage: "checkmark.circle") {
            editor.select(item, extending: true)
        }
        Divider()
        Button("Copier", systemImage: "doc.on.doc") {
            prepare()
            editor.copy()
        }
        Button("Coller", systemImage: "doc.on.clipboard") {
            prepare()
            editor.paste()
        }
        .disabled(!editor.canPaste)
        Button("Dupliquer", systemImage: "plus.square.on.square") {
            prepare()
            editor.duplicate()
        }
        Divider()
        Button("Supprimer", systemImage: "trash", role: .destructive) {
            prepare()
            editor.delete()
        }
    }

    /// L'action porte sur la sélection si l'élément en fait partie, sinon sur lui seul.
    private func prepare() {
        if !editor.isSelected(item) {
            editor.select(item)
        }
    }
}

extension View {
    /// Fait défiler la fiche juste assez pour montrer l'élément sélectionné quand la sélection change
    /// (sur iPhone, au-dessus de la feuille de l'inspecteur ; aussi après un ajout ou un collage).
    func scrollsToSelection(_ editor: StructureEditor, proxy: ScrollViewProxy) -> some View {
        task(id: editor.primary) {
            guard let item = editor.primary else { return }
            // Laisse la feuille de l'inspecteur apparaître et la marge du bas se mettre à jour.
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation { proxy.scrollTo(item) }
        }
    }
}

/// Boutons d'ajout côte à côte, ou empilés si la largeur manque.
struct AddButtonsBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                content()
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
        .buttonStyle(.borderless)
        .lineLimit(1)
    }
}

/// Bouton discret d'ajout, affiché en mode Structure.
struct AddButtonLabel: View {
    let title: LocalizedStringKey
    var systemImage = "plus"

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout)
    }
}

/// Zone d'ajout en pointillés (bas de colonne, bas de page).
struct DashedAddZone<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, minHeight: 36)
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(.tertiary)
            }
    }
}
