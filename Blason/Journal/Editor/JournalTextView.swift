import SwiftUI
import SheetKit
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Récit d'une session : vue de texte du système (UITextView, NSTextView), qui défile et occupe
/// toute la place ; la logique est dans `JournalEditorController`.
struct JournalTextView: View {
    let controller: JournalEditorController
    let initialText: JournalText
    /// Écriture au crayon convertie en texte (Scribble, iPad).
    var allowsScribble = true
    var placeholder: LocalizedStringKey = "Récit de la session"
    /// En-tête posé au-dessus du récit, qui défile avec lui (iOS) ; sur Mac, il reste au-dessus.
    var header: AnyView?

    @Environment(\.sheetTheme) private var theme

    #if canImport(UIKit)
    /// Zone sûre (sous les barres, au-dessus du clavier), dans la fenêtre.
    @State private var safeFrame: CGRect = .zero
    #endif

    var body: some View {
        #if canImport(UIKit)
        // Bord à bord : le texte passe sous les barres et sous le clavier ; les marges du système
        // deviennent celles du défilement.
        // La vue de texte compare elle-même la zone sûre à son propre cadre.
        Color.clear
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { safeFrame = $0 }
            .overlay {
                JournalTextRepresentable(controller: controller, initialText: initialText, allowsScribble: allowsScribble,
                                         style: theme.journal, header: header, safeFrame: safeFrame)
                    .accessibilityLabel(Text(placeholder))
                    .ignoresSafeArea()
            }
        #else
        VStack(spacing: 0) {
            if let header {
                header
                    .frame(maxWidth: readableWidth, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .frame(maxWidth: .infinity)
                Divider()
            }
            JournalTextRepresentable(controller: controller, initialText: initialText, allowsScribble: allowsScribble,
                                     style: theme.journal)
                .accessibilityLabel(Text(placeholder))
        }
        #endif
    }
}

/// Largeur de lecture : au-delà, le texte reste centré.
private let readableWidth: CGFloat = 720

#if canImport(UIKit)

private struct JournalTextRepresentable: UIViewRepresentable {
    let controller: JournalEditorController
    let initialText: JournalText
    let allowsScribble: Bool
    let style: JournalStyle
    let header: AnyView?
    let safeFrame: CGRect

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> JournalUITextView {
        let view = JournalUITextView(usingTextLayoutManager: true)
        view.journalUndo = controller.undoManager
        view.backgroundColor = .clear
        view.allowsEditingTextAttributes = false
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        view.contentInsetAdjustmentBehavior = .never
        view.adjustsFontForContentSizeCategory = false
        view.textContainer.lineFragmentPadding = 0
        controller.style = style
        view.tintColor = style.accent.map { UIColor($0) }
        view.attributedText = controller.initialText(for: initialText)
        view.typingAttributes = JournalTypography.typingAttributes(from: [:])
        view.delegate = context.coordinator
        controller.host = view

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)

        let scribble = UIScribbleInteraction(delegate: context.coordinator)
        view.addInteraction(scribble)
        context.coordinator.allowsScribble = allowsScribble

        if let header {
            let host = UIHostingController(rootView: measured(header, in: view))
            host.view.backgroundColor = .clear
            host.safeAreaRegions = []
            view.addSubview(host.view)
            view.headerView = host.view
            context.coordinator.header = host
        }
        return view
    }

    func updateUIView(_ view: JournalUITextView, context: Context) {
        context.coordinator.allowsScribble = allowsScribble
        view.safeFrame = safeFrame
        if style != controller.style {
            view.tintColor = style.accent.map { UIColor($0) }
            controller.applyStyle(style)
        }
        if let header, let host = context.coordinator.header {
            host.rootView = measured(header, in: view)
        }
    }

    /// L'en-tête à sa hauteur naturelle, qu'il transmet à la vue de texte pour décaler le récit.
    private func measured(_ header: AnyView, in view: JournalUITextView) -> AnyView {
        AnyView(header
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { [weak view] height in
                view?.headerHeight = height
            })
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate, UIScribbleInteractionDelegate {
        let controller: JournalEditorController
        var allowsScribble = true
        var header: UIHostingController<AnyView>?
        private var tappedItem: JournalTextItem?

        init(controller: JournalEditorController) {
            self.controller = controller
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            controller.shouldChange(in: range, replacement: text)
        }

        func textViewDidChange(_ textView: UITextView) {
            controller.didChange()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            controller.selectionDidChange()
        }

        // Toucher une citation, une pièce jointe ou une case.

        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let view = recognizer.view as? UITextView else { return false }
            tappedItem = item(at: recognizer.location(in: view), in: view)
            return tappedItem != nil
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }

        @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let item = tappedItem else { return }
            tappedItem = nil
            if case .checkbox = item {} else { recognizer.view?.resignFirstResponder() }
            controller.activate(item)
        }

        private func item(at point: CGPoint, in view: UITextView) -> JournalTextItem? {
            guard let position = view.closestPosition(to: point) else { return nil }
            let index = view.offset(from: view.beginningOfDocument, to: position)
            return controller.item(near: index) { range in
                guard let start = view.position(from: view.beginningOfDocument, offset: range.location),
                      let end = view.position(from: start, offset: range.length),
                      let textRange = view.textRange(from: start, to: end) else { return false }
                return view.firstRect(for: textRange).insetBy(dx: -4, dy: -4).contains(point)
            }
        }

        // Scribble : l'écriture au crayon devient du texte, sauf si on l'a désactivé.

        func scribbleInteraction(_ interaction: UIScribbleInteraction, shouldBeginAt location: CGPoint) -> Bool {
            allowsScribble
        }
    }
}

final class JournalUITextView: UITextView, JournalTextHost {
    var journalUndo: UndoManager?
    /// En-tête de la session, posé au-dessus du texte dans la zone qui défile.
    var headerView: UIView?
    var headerHeight: CGFloat = 0 {
        didSet { if headerHeight != oldValue { setNeedsLayout() } }
    }

    /// Zone sûre dans la fenêtre : barres et clavier passent par-dessus le texte, le défilement
    /// s'arrête à leur bord.
    var safeFrame: CGRect = .zero {
        didSet { if safeFrame != oldValue { setNeedsLayout() } }
    }

    private func applyOuterInsets() {
        guard window != nil, !safeFrame.isEmpty else { return }
        let frame = convert(bounds, to: nil)
        let insets = UIEdgeInsets(top: max(0, safeFrame.minY - frame.minY), left: 0,
                                  bottom: max(0, frame.maxY - safeFrame.maxY), right: 0)
        guard insets != contentInset else { return }
        // En haut du texte, on y reste : la session s'affiche depuis son en-tête.
        let atTop = contentOffset.y <= -contentInset.top + 1
        contentInset = insets
        verticalScrollIndicatorInsets = insets
        if atTop { contentOffset.y = -insets.top }
    }

    override var undoManager: UndoManager? { journalUndo ?? super.undoManager }

    override func layoutSubviews() {
        super.layoutSubviews()
        let side = max(20, (bounds.width - readableWidth) / 2)
        var top: CGFloat = 16
        if let headerView {
            headerView.frame = CGRect(x: side, y: top, width: max(0, bounds.width - 2 * side), height: headerHeight)
            top += headerHeight + 14
        }
        let inset = UIEdgeInsets(top: top, left: side, bottom: 120, right: side)
        if textContainerInset != inset { textContainerInset = inset }
        applyOuterInsets()
    }

    /// Les gestes du texte (curseur, sélection, citations) ne partent pas de l'en-tête.
    override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        if let headerView, headerView.frame.contains(recognizer.location(in: self)) { return false }
        return super.gestureRecognizerShouldBegin(recognizer)
    }

    /// Le texte collé perd sa mise en forme d'origine.
    override func paste(_ sender: Any?) {
        guard let string = UIPasteboard.general.string else { return super.paste(sender) }
        insertText(string.replacingOccurrences(of: JournalText.attachmentCharacter, with: ""))
    }

    var journalStorage: NSTextStorage { textStorage }

    var journalSelection: NSRange {
        get { selectedRange }
        set { selectedRange = newValue }
    }

    var journalTypingAttributes: [NSAttributedString.Key: Any] {
        get { typingAttributes }
        set { typingAttributes = newValue }
    }

    var journalUndoManager: UndoManager? { journalUndo }

    var journalHasMarkedText: Bool { markedTextRange != nil }

    func journalFocus() {
        if !isFirstResponder { becomeFirstResponder() }
    }

    func journalDidEdit() {
        delegate?.textViewDidChange?(self)
        scrollRangeToVisible(selectedRange)
    }
}

#else

private struct JournalTextRepresentable: NSViewRepresentable {
    let controller: JournalEditorController
    let initialText: JournalText
    let allowsScribble: Bool
    let style: JournalStyle

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true

        let view = JournalNSTextView(usingTextLayoutManager: true)
        view.journalController = controller
        view.isRichText = true
        view.importsGraphics = false
        view.allowsUndo = true
        view.usesFontPanel = false
        view.usesFindBar = true
        view.drawsBackground = false
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.minSize = .zero
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.lineFragmentPadding = 0
        controller.style = style
        view.insertionPointColor = style.accent.map { NSColor($0) } ?? .textInsertionPointColor
        view.textStorage?.setAttributedString(controller.initialText(for: initialText))
        view.typingAttributes = JournalTypography.typingAttributes(from: [:])
        view.delegate = context.coordinator
        scroll.documentView = view
        controller.host = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard style != controller.style, let view = scroll.documentView as? NSTextView else { return }
        view.insertionPointColor = style.accent.map { NSColor($0) } ?? .textInsertionPointColor
        controller.applyStyle(style)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        let controller: JournalEditorController

        init(controller: JournalEditorController) {
            self.controller = controller
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
            // Changement d'attributs seulement (pas de texte) : rien à vérifier.
            guard let text else { return true }
            return controller.shouldChange(in: range, replacement: text)
        }

        func textDidChange(_ notification: Notification) {
            controller.didChange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            controller.selectionDidChange()
        }

        func undoManager(for view: NSTextView) -> UndoManager? {
            controller.undoManager
        }
    }
}

final class JournalNSTextView: NSTextView, JournalTextHost {
    weak var journalController: JournalEditorController?

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        let side = max(20, (newSize.width - readableWidth) / 2)
        let inset = NSSize(width: side, height: 20)
        if textContainerInset != inset { textContainerInset = inset }
    }

    /// Le texte collé perd sa mise en forme d'origine.
    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1, let controller = journalController, let window {
            let point = convert(event.locationInWindow, from: nil)
            let index = characterIndexForInsertion(at: point)
            let item = controller.item(near: index) { range in
                let screen = firstRect(forCharacterRange: range, actualRange: nil)
                let rect = convert(window.convertFromScreen(screen), from: nil)
                return rect.insetBy(dx: -4, dy: -4).contains(point)
            }
            if let item {
                controller.activate(item)
                return
            }
        }
        super.mouseDown(with: event)
    }

    var journalStorage: NSTextStorage { textStorage ?? NSTextStorage() }

    var journalSelection: NSRange {
        get { selectedRange() }
        set { setSelectedRange(newValue) }
    }

    var journalTypingAttributes: [NSAttributedString.Key: Any] {
        get { typingAttributes }
        set { typingAttributes = newValue }
    }

    var journalUndoManager: UndoManager? { journalController?.undoManager }

    var journalHasMarkedText: Bool { hasMarkedText() }

    func journalFocus() {
        window?.makeFirstResponder(self)
    }

    func journalDidEdit() {
        // La saisie qui suit ne se fond pas dans l'annulation d'avant la modification.
        breakUndoCoalescing()
        didChangeText()
        scrollRangeToVisible(selectedRange())
    }
}

#endif
