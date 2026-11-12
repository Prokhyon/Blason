#if DEBUG && canImport(UIKit)
import UIKit
import SheetKit

/// Vérification de l'éditeur du récit sans interface (`-journalSelfTest YES`) : saisie simulée,
/// listes, cases, citations, annulation ; le résultat s'écrit dans la console.
@MainActor
enum JournalEditorSelfTest {
    static func run() {
        let view = JournalUITextView(usingTextLayoutManager: true)
        let controller = JournalEditorController()
        view.journalUndo = controller.undoManager
        view.attributedText = controller.initialText(for: JournalText())
        view.typingAttributes = JournalTypography.typingAttributes(from: [:])
        controller.host = view
        // Hors de la boucle d'événements : un groupe d'annulation par commande, à la main.
        controller.undoManager.groupsByEvent = false
        var failures = 0
        func step(_ body: () -> Void) {
            controller.undoManager.beginUndoGrouping()
            body()
            controller.undoManager.endUndoGrouping()
        }

        func type(_ string: String) { step { typeNow(string) } }
        func typeNow(_ string: String) {
            let range = view.selectedRange
            guard controller.shouldChange(in: range, replacement: string) else {
                controller.selectionDidChange()
                return
            }
            view.textStorage.replaceCharacters(in: range,
                                               with: NSAttributedString(string: string, attributes: view.typingAttributes))
            view.selectedRange = NSRange(location: range.location + (string as NSString).length, length: 0)
            controller.didChange()
            controller.selectionDidChange()
        }
        func backspace() { step { backspaceNow() } }
        func backspaceNow() {
            let range = view.selectedRange.length > 0 ? view.selectedRange
                : NSRange(location: max(0, view.selectedRange.location - 1), length: view.selectedRange.location > 0 ? 1 : 0)
            guard controller.shouldChange(in: range, replacement: "") else { controller.selectionDidChange(); return }
            view.textStorage.deleteCharacters(in: range)
            view.selectedRange = NSRange(location: range.location, length: 0)
            controller.didChange()
            controller.selectionDidChange()
        }
        func check(_ label: String, _ condition: Bool) {
            if !condition { failures += 1 }
            print("JOURNALTEST \(condition ? "ok  " : "FAIL") \(label)")
        }
        func dump() -> String {
            String(data: controller.text.encoded() ?? Data(), encoding: .utf8) ?? ""
        }

        type("Bonjour")
        check("saisie", controller.text.plainText == "Bonjour")

        step { controller.toggleList(.checklist) }
        check("liste à cocher", controller.text.paragraphs.first?.list == .checklist)
        check("curseur après la case", view.selectedRange.location == view.textStorage.length)
        type("\n")
        type("Deux")
        check("retour : nouvelle case", controller.text.paragraphs.count == 2
              && controller.text.paragraphs[1].list == .checklist && controller.text.paragraphs[1].plainText == "Deux")
        type("\n")
        type("\n")
        check("retour sur une case vide : fin de liste", controller.text.paragraphs.count == 3
              && controller.text.paragraphs[2].list == nil)

        step { controller.toggleCheckbox(at: 0) }
        check("cocher", controller.text.paragraphs[0].checked == true)

        type("Rencontre avec ")
        let entry = CodexEntry(name: "Aldo", kind: .npc)
        step { controller.insertReference(to: entry) }
        check("citation", controller.text.referencedEntries == [entry.uid]
              && controller.text.paragraphs[2].plainText == "Rencontre avec Aldo ")
        type("au port.")
        backspace()  // « . »
        let afterDot = controller.text.paragraphs[2].plainText
        check("effacement simple", afterDot == "Rencontre avec Aldo au port")
        // Curseur juste après « Aldo » : l'effacement emporte la citation entière.
        let text = view.textStorage.string as NSString
        view.selectedRange = NSRange(location: text.range(of: "Aldo").location + 4, length: 0)
        controller.selectionDidChange()
        backspace()
        check("effacement de la citation entière", controller.text.paragraphs[2].plainText == "Rencontre avec  au port"
              && controller.text.referencedEntries.isEmpty)
        controller.undoManager.undo()
        check("annuler : la citation revient", controller.text.referencedEntries == [entry.uid])

        view.selectedRange = NSRange(location: 2, length: 3)
        controller.selectionDidChange()
        step { controller.setStyle(.heading) }
        check("style du paragraphe", controller.text.paragraphs[0].style == .heading
              && controller.text.paragraphs[0].list == .checklist)

        let start = (view.textStorage.string as NSString).range(of: "Rencontre").location
        view.selectedRange = NSRange(location: start, length: 9)
        controller.selectionDidChange()
        step { controller.toggle(.bold) }
        check("gras", controller.text.paragraphs[2].runs.first?.bold == true
              && controller.text.paragraphs[2].runs.first?.text == "Rencontre")

        step { controller.toggleList(.bullet) }
        check("puces", controller.text.paragraphs[2].list == .bullet
              && controller.text.paragraphs[2].plainText.hasPrefix("Rencontre"))
        view.selectedRange = NSRange(location: start + 2, length: 0)  // juste après la puce « •\t »
        controller.selectionDidChange()
        backspace()
        check("effacer la puce arrête la liste", controller.text.paragraphs[2].list == nil
              && controller.text.paragraphs[2].plainText.hasPrefix("Rencontre"))

        let uid = UUID()
        view.selectedRange = NSRange(location: view.textStorage.length, length: 0)
        step { controller.insertAttachment(uid) }
        check("pièce jointe sur sa ligne", controller.text.attachments == [uid]
              && controller.text.paragraphs.last?.runs.isEmpty == true)

        while controller.undoManager.canUndo { controller.undoManager.undo() }
        check("tout annuler", controller.text.attachments.isEmpty && controller.text.paragraphs[0].list == nil)
        while controller.undoManager.canRedo { controller.undoManager.redo() }
        check("tout rétablir", controller.text.attachments == [uid] && controller.text.paragraphs[0].style == .heading)

        let reloaded = JournalTypography.journalText(
            from: JournalTypography.attributedString(from: controller.text, content: { _ in nil }))
        check("aller-retour JournalText", reloaded == controller.text)
        print("JOURNALTEST texte : \(dump())")
        print("JOURNALTEST \(failures == 0 ? "RÉUSSI" : "\(failures) ÉCHEC(S)")")
    }
}
#endif
