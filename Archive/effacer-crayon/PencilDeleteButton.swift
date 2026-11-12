// Archivé le 12 novembre 2026 : bouton « effacer un caractère » pendant l'écriture au crayon
// (Scribble). Mis de côté avant d'être essayé avec un vrai Pencil. Hors du build.
// Voir README.md pour où chaque morceau se branchait.

// MARK: - JournalEditorController

/// Écriture au crayon en cours (Scribble) : le bouton « effacer un caractère » s'affiche.
var isPencilWriting = false

/// Efface un caractère (bouton affiché pendant l'écriture au crayon).
/// Mêmes règles que la touche ⌫ : une citation s'efface d'un bloc, une puce arrête la liste.
func deleteBackward() {
    guard let host else { return }
    let selection = host.journalSelection
    let text = host.journalStorage.string as NSString
    let range = selection.length > 0 ? selection
        : selection.location > 0 ? text.rangeOfComposedCharacterSequence(at: selection.location - 1) : nil
    guard let range, range.length > 0 else { return }
    guard shouldChange(in: range, replacement: "") else { return }
    pendingRestyle = nil
    edit(String(localized: "Effacer")) { storage in
        storage.deleteCharacters(in: range)
        if storage.length > 0 {
            JournalTypography.restyle(storage, in: NSRange(location: min(range.location, storage.length - 1), length: 0))
        }
        return NSRange(location: range.location, length: 0)
    }
}

// MARK: - JournalTextRepresentable (iOS), makeUIView, après l'ajout de UIScribbleInteraction

NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.keyboardWillShow(_:)),
                                       name: UIResponder.keyboardWillShowNotification, object: nil)

// MARK: - JournalTextRepresentable.Coordinator (iOS)

func scribbleInteractionWillBeginWriting(_ interaction: UIScribbleInteraction) {
    controller.isPencilWriting = true
}

func textViewDidEndEditing(_ textView: UITextView) {
    controller.isPencilWriting = false
}

/// Le clavier revient : on écrit au clavier, le bouton s'en va.
@objc func keyboardWillShow(_ notification: Notification) {
    controller.isPencilWriting = false
}

// MARK: - JournalSessionEditor

// Sur la vue du récit :
JournalTextView(controller: controller, initialText: initialText, allowsScribble: allowsScribble)
    .overlay(alignment: .bottomTrailing) {
        if controller.isPencilWriting {
            pencilDeleteButton
                .transition(.scale.combined(with: .opacity))
        }
    }
    .animation(.snappy, value: controller.isPencilWriting)

/// Pendant l'écriture au crayon : effacer un seul caractère (maintenu, il répète), plutôt que
/// de barrer tout un mot.
private var pencilDeleteButton: some View {
    Button {
        controller.deleteBackward()
    } label: {
        Label("Effacer un caractère", systemImage: "delete.backward")
            .labelStyle(.iconOnly)
            .font(.title2)
            .frame(width: 60, height: 60)
            .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .buttonRepeatBehavior(.enabled)
    .foregroundStyle(.primary)
    .background(.regularMaterial, in: Circle())
    .overlay(Circle().strokeBorder(.quaternary))
    .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
    .padding(24)
}

// MARK: - JournalEditorSelfTest, avant l'aller-retour JournalText

// Bouton « effacer un caractère » (crayon) : mêmes règles que la touche ⌫.
view.selectedRange = NSRange(location: view.textStorage.length, length: 0)
controller.selectionDidChange()
type("Vu")
step { controller.insertReference(to: entry) }
let before = controller.text.paragraphs.last?.plainText
step { controller.deleteBackward() }
step { controller.deleteBackward() }
check("bouton effacer : un caractère, puis la citation d'un bloc",
      before == "Vu Aldo " && controller.text.paragraphs.last?.plainText == "Vu ")
step { controller.deleteBackward() }
check("bouton effacer : un seul caractère", controller.text.paragraphs.last?.plainText == "Vu")
controller.undoManager.undo()  // pas dans un `step` : annuler dans un groupe ouvert lève une exception
