import SwiftUI
import SheetKit

/// Vue de texte du système (UITextView ou NSTextView) pilotée par `JournalEditorController`.
@MainActor
protocol JournalTextHost: AnyObject {
    var journalStorage: NSTextStorage { get }
    var journalSelection: NSRange { get set }
    var journalTypingAttributes: [NSAttributedString.Key: Any] { get set }
    var journalUndoManager: UndoManager? { get }
    /// Saisie en cours de composition (accents, clavier japonais…) : ne rien toucher.
    var journalHasMarkedText: Bool { get }
    func journalFocus()
    /// Fin d'une modification faite par le code (mise en page, défilement jusqu'au curseur).
    func journalDidEdit()
}

/// Élément touché dans le texte.
enum JournalTextItem: Equatable {
    case reference(UUID)
    case attachment(UUID)
    /// Case d'une liste à cocher : position du paragraphe.
    case checkbox(Int)
}

/// Logique de l'éditeur du récit, commune à iOS et macOS : mise en forme (styles, gras, listes),
/// citations des fiches du carnet, pièces jointes, comportement des listes au retour à la ligne,
/// annulation, enregistrement différé dans la session.
@MainActor @Observable
final class JournalEditorController {
    /// Mise en forme à l'emplacement du curseur (état des commandes).
    struct Format: Equatable {
        var style: JournalText.Style = .body
        var list: JournalText.List?
        var bold = false
        var italic = false
        var underline = false
        var strikethrough = false
        var selectedText = ""
    }

    private(set) var format = Format()

    @ObservationIgnored weak var host: JournalTextHost?
    /// Image et genre d'une pièce jointe.
    @ObservationIgnored var content: (UUID) -> JournalAttachmentContent? = { _ in nil }
    /// Le texte a changé (enregistrement différé).
    @ObservationIgnored var onChange: () -> Void = {}
    /// Une citation ou une pièce jointe a été touchée.
    @ObservationIgnored var onOpen: (JournalTextItem) -> Void = { _ in }
    /// Gestionnaire d'annulation propre au récit (distinct de celui de la base).
    @ObservationIgnored let undoManager = UndoManager()

    /// Paragraphes touchés par la saisie en cours, remis en forme après elle.
    @ObservationIgnored private var pendingRestyle: NSRange?

    init() {
        undoManager.levelsOfUndo = 200
    }

    var text: JournalText {
        guard let host else { return JournalText() }
        return JournalTypography.journalText(from: host.journalStorage)
    }

    func initialText(for text: JournalText) -> NSAttributedString {
        JournalTypography.attributedString(from: text, content: content)
    }

    // MARK: - Saisie (appelé par la vue de texte)

    /// Avant une modification de l'utilisateur : `false` si l'éditeur s'en charge lui-même
    /// (retour à la ligne dans une liste, effacement d'une citation ou d'une puce).
    func shouldChange(in range: NSRange, replacement: String) -> Bool {
        guard let host, !host.journalHasMarkedText else { return true }
        let storage = host.journalStorage
        let text = storage.string as NSString

        if replacement == "\n", let handled = handleReturn(in: range, storage: storage, text: text), handled {
            return false
        }

        // Effacement juste après une puce : la liste s'arrête (le texte reste).
        if replacement.isEmpty, range.length > 0, let marker = markerRange(at: range.location, in: storage),
           NSMaxRange(range) == NSMaxRange(marker) {
            setList(nil, paragraphsAt: [marker.location], actionName: String(localized: "Liste"))
            return false
        }

        // Une citation ne se coupe pas : on l'efface en entier, on n'écrit pas au milieu.
        var expanded = range
        if range.length == 0 {
            if let reference = referenceRange(containing: range.location, in: storage),
               reference.location < range.location {
                return false
            }
        } else {
            for location in [range.location, NSMaxRange(range) - 1] {
                if let reference = referenceRange(containing: location, in: storage) {
                    expanded = NSUnionRange(expanded, reference)
                }
            }
            // Effacer le retour à la ligne avant un élément de liste emporte sa puce.
            if NSMaxRange(expanded) < text.length, let marker = markerRange(at: NSMaxRange(expanded), in: storage),
               marker.location == NSMaxRange(expanded), expanded.location < marker.location {
                expanded = NSUnionRange(expanded, marker)
            }
        }
        if expanded != range {
            let typing = host.journalTypingAttributes
            edit(String(localized: "Saisie")) { storage in
                storage.replaceCharacters(in: expanded, with: NSAttributedString(string: replacement, attributes: typing))
                return NSRange(location: expanded.location + (replacement as NSString).length, length: 0)
            }
            return false
        }
        pendingRestyle = NSRange(location: range.location, length: (replacement as NSString).length)
        return true
    }

    /// Après une modification de l'utilisateur.
    func didChange() {
        guard let host else { return }
        if !host.journalHasMarkedText, let range = pendingRestyle {
            let selection = host.journalSelection
            JournalTypography.restyle(host.journalStorage, in: range)
            host.journalSelection = selection
        }
        pendingRestyle = nil
        onChange()
        updateFormat()
    }

    func selectionDidChange() {
        guard let host, !host.journalHasMarkedText else { return }
        let selection = host.journalSelection
        // Le curseur ne se place pas avant une puce.
        if selection.length == 0, let marker = markerRange(at: selection.location, in: host.journalStorage),
           selection.location >= marker.location, selection.location < NSMaxRange(marker) {
            host.journalSelection = NSRange(location: NSMaxRange(marker), length: 0)
            return
        }
        if selection.length == 0 {
            host.journalTypingAttributes = typingAttributes(at: selection.location)
        }
        updateFormat()
    }

    /// Retour à la ligne : une liste continue (ou s'arrête sur un élément vide).
    private func handleReturn(in range: NSRange, storage: NSTextStorage, text: NSString) -> Bool? {
        guard range.length == 0 else { return nil }
        let paragraph = text.paragraphRange(for: NSRange(location: range.location, length: 0))
        guard paragraph.length > 0, let marker = markerRange(at: paragraph.location, in: storage) else { return nil }
        let attributes = storage.attributes(at: paragraph.location, effectiveRange: nil)
        guard let list = (attributes[.journalList] as? String).flatMap(JournalText.List.init) else { return nil }
        let style = (attributes[.journalStyle] as? String).flatMap(JournalText.Style.init) ?? .body
        let content = JournalTypography.contentRange(of: paragraph, in: text)
        if content.length <= marker.length {
            setList(nil, paragraphsAt: [paragraph.location], actionName: String(localized: "Liste"))
            return true
        }
        edit(String(localized: "Saisie")) { storage in
            let line = NSMutableAttributedString(string: "\n", attributes: JournalTypography.attributes(
                style: style, list: list, checked: attributes[.journalChecked] as? Bool ?? false, bold: false,
                italic: false, underline: false, strikethrough: false, reference: nil, marker: false))
            line.append(JournalTypography.marker(list, checked: false, style: style))
            storage.replaceCharacters(in: range, with: line)
            return NSRange(location: range.location + line.length, length: 0)
        }
        return true
    }

    // MARK: - Commandes de mise en forme

    enum Trait {
        case bold, italic, underline, strikethrough

        var key: NSAttributedString.Key {
            switch self {
            case .bold: .journalBold
            case .italic: .journalItalic
            case .underline: .underlineStyle
            case .strikethrough: .strikethroughStyle
            }
        }

        var name: String {
            switch self {
            case .bold: String(localized: "Gras")
            case .italic: String(localized: "Italique")
            case .underline: String(localized: "Souligné")
            case .strikethrough: String(localized: "Barré")
            }
        }

        func isOn(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
            switch self {
            case .bold, .italic: attributes[key] as? Bool == true
            case .underline, .strikethrough: (attributes[key] as? Int ?? 0) != 0
            }
        }

        var onValue: Any {
            switch self {
            case .bold, .italic: true
            case .underline, .strikethrough: NSUnderlineStyle.single.rawValue
            }
        }
    }

    func toggle(_ trait: Trait) {
        guard let host else { return }
        let selection = host.journalSelection
        if selection.length == 0 {
            var typing = host.journalTypingAttributes
            if trait.isOn(typing) { typing.removeValue(forKey: trait.key) } else { typing[trait.key] = trait.onValue }
            host.journalTypingAttributes = JournalTypography.typingAttributes(from: typing)
            updateFormat()
            return
        }
        let storage = host.journalStorage
        var allOn = true
        storage.enumerateAttributes(in: selection) { attributes, _, stop in
            if attributes[.journalMarker] == nil, !trait.isOn(attributes) { allOn = false; stop.pointee = true }
        }
        edit(trait.name) { storage in
            storage.enumerateAttributes(in: selection) { attributes, range, _ in
                guard attributes[.journalMarker] == nil else { return }
                if allOn { storage.removeAttribute(trait.key, range: range) }
                else { storage.addAttribute(trait.key, value: trait.onValue, range: range) }
            }
            JournalTypography.restyle(storage, in: selection)
            return selection
        }
    }

    /// Style des paragraphes sélectionnés (titre, en-tête…).
    func setStyle(_ style: JournalText.Style) {
        guard let host else { return }
        let paragraphs = paragraphRanges(for: host.journalSelection)
        let nonEmpty = paragraphs.filter {
            JournalTypography.contentRange(of: $0, in: host.journalStorage.string as NSString).length > 0
        }
        if nonEmpty.isEmpty {
            // Paragraphe vide : le style vaut pour ce qu'on va écrire.
            var typing = host.journalTypingAttributes
            typing[.journalStyle] = style.rawValue
            host.journalTypingAttributes = JournalTypography.typingAttributes(from: typing)
            updateFormat()
            host.journalFocus()
            return
        }
        let selection = host.journalSelection
        edit(String(localized: "Style")) { storage in
            for paragraph in nonEmpty {
                storage.addAttribute(.journalStyle, value: style.rawValue, range: paragraph)
                JournalTypography.restyle(storage, in: paragraph)
            }
            return selection
        }
        // Les cases suivent la taille du texte.
        if nonEmpty.contains(where: { markerRange(at: $0.location, in: host.journalStorage) != nil }) {
            refreshCheckboxes()
        }
    }

    /// Liste à puces ou à cocher sur les paragraphes sélectionnés ; la même une seconde fois l'enlève.
    func toggleList(_ list: JournalText.List) {
        guard let host else { return }
        let paragraphs = paragraphRanges(for: host.journalSelection)
        let storage = host.journalStorage
        let allInList = paragraphs.allSatisfy { paragraph in
            markerRange(at: paragraph.location, in: storage) != nil
                && storage.attribute(.journalList, at: paragraph.location, effectiveRange: nil) as? String == list.rawValue
        }
        setList(allInList ? nil : list, paragraphsAt: paragraphs.map(\.location),
                actionName: list == .checklist ? String(localized: "Liste de tâches") : String(localized: "Liste"))
    }

    /// Pose ou retire une liste sur des paragraphes (désignés par leur début).
    private func setList(_ list: JournalText.List?, paragraphsAt starts: [Int], actionName: String) {
        guard let host else { return }
        let selection = host.journalSelection
        var shift = 0
        edit(actionName) { storage in
            // Du dernier au premier : les positions des précédents ne bougent pas.
            for start in starts.sorted(by: >) {
                let text = storage.string as NSString
                let attributes = start < text.length ? storage.attributes(at: start, effectiveRange: nil)
                    : JournalTypography.typingAttributes(from: host.journalTypingAttributes)
                let style = (attributes[.journalStyle] as? String).flatMap(JournalText.Style.init) ?? .body
                var delta = 0
                if let marker = markerRange(at: start, in: storage) {
                    storage.deleteCharacters(in: marker)
                    delta -= marker.length
                }
                let paragraph = start < (storage.string as NSString).length
                    ? (storage.string as NSString).paragraphRange(for: NSRange(location: start, length: 0))
                    : NSRange(location: start, length: 0)
                if paragraph.length > 0 {
                    if let list {
                        storage.addAttribute(.journalList, value: list.rawValue, range: paragraph)
                        storage.addAttribute(.journalChecked, value: false, range: paragraph)
                    } else {
                        storage.removeAttribute(.journalList, range: paragraph)
                        storage.removeAttribute(.journalChecked, range: paragraph)
                    }
                }
                if let list {
                    let marker = JournalTypography.marker(list, checked: false, style: style)
                    storage.insert(marker, at: start)
                    delta += marker.length
                }
                let updated = (storage.string as NSString).length > start
                    ? (storage.string as NSString).paragraphRange(for: NSRange(location: start, length: 0)) : nil
                if let updated { JournalTypography.restyle(storage, in: updated) }
                if start <= selection.location { shift += delta }
            }
            return NSRange(location: max(0, selection.location + shift), length: selection.length)
        }
    }

    /// Coche ou décoche l'élément de liste qui commence à `start`.
    func toggleCheckbox(at start: Int) {
        guard let host, let marker = markerRange(at: start, in: host.journalStorage) else { return }
        let storage = host.journalStorage
        let checked = !(storage.attribute(.journalChecked, at: start, effectiveRange: nil) as? Bool ?? false)
        let style = (storage.attribute(.journalStyle, at: start, effectiveRange: nil) as? String)
            .flatMap(JournalText.Style.init) ?? .body
        let selection = host.journalSelection
        edit(checked ? String(localized: "Cocher") : String(localized: "Décocher")) { storage in
            let paragraph = (storage.string as NSString).paragraphRange(for: NSRange(location: start, length: 0))
            storage.addAttribute(.journalChecked, value: checked, range: paragraph)
            storage.replaceCharacters(in: marker, with: JournalTypography.marker(.checklist, checked: checked, style: style))
            JournalTypography.restyle(storage, in: paragraph)
            return selection
        }
    }

    /// Recrée les cases (taille du texte après un changement de style).
    private func refreshCheckboxes() {
        guard let host else { return }
        let storage = host.journalStorage
        storage.beginEditing()
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard let box = value as? JournalCheckbox else { return }
            let style = (storage.attribute(.journalStyle, at: range.location, effectiveRange: nil) as? String)
                .flatMap(JournalText.Style.init) ?? .body
            storage.addAttribute(.attachment, value: JournalTypography.checkbox(checked: box.checked, style: style),
                                 range: range)
        }
        storage.endEditing()
        host.journalDidEdit()
    }

    // MARK: - Citations et pièces jointes

    /// Cite une fiche du carnet : la sélection devient la citation, sinon le nom de la fiche est inséré.
    func insertReference(to entry: CodexEntry) {
        guard let host else { return }
        let selection = host.journalSelection
        let storage = host.journalStorage
        let selected = (storage.string as NSString).substring(with: selection)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let label = selected.isEmpty || selected.contains("\n") ? entry.name : selected
        guard !label.isEmpty else { return }
        let base = selection.location < storage.length
            ? storage.attributes(at: selection.location, effectiveRange: nil) : host.journalTypingAttributes
        edit(String(localized: "Citer")) { storage in
            var typing = JournalTypography.typingAttributes(from: base)
            typing[.journalReference] = entry.uid.uuidString
            let inserted = NSMutableAttributedString(string: label, attributes: typing)
            let end = NSMaxRange(selection)
            let next = end < storage.length ? (storage.string as NSString).character(at: end) : 0x0A
            let nextIsSeparator = next == 0x0A || next == 0x20 || next == 0x2C || next == 0x2E
            if !nextIsSeparator || end >= storage.length {
                inserted.append(NSAttributedString(string: " ", attributes: JournalTypography.typingAttributes(from: base)))
            }
            storage.replaceCharacters(in: selection, with: inserted)
            JournalTypography.restyle(storage, in: NSRange(location: selection.location, length: inserted.length))
            return NSRange(location: selection.location + inserted.length, length: 0)
        }
        host.journalFocus()
    }

    /// Insère une pièce jointe au curseur, sur sa propre ligne.
    func insertAttachment(_ uid: UUID) {
        guard let host else { return }
        let selection = host.journalSelection
        edit(String(localized: "Insérer")) { storage in
            let text = storage.string as NSString
            let base = JournalTypography.attributes(style: .body, list: nil, checked: false, bold: false, italic: false,
                                                    underline: false, strikethrough: false, reference: nil, marker: false)
            let inserted = NSMutableAttributedString()
            let location = selection.location
            if location > 0, text.character(at: location - 1) != 0x0A {
                inserted.append(NSAttributedString(string: "\n", attributes: base))
            }
            var attachmentAttributes = base
            attachmentAttributes[.attachment] = JournalTypography.makeAttachment(uid: uid, content: content(uid))
            attachmentAttributes[.journalAttachment] = uid.uuidString
            inserted.append(NSAttributedString(string: JournalText.attachmentCharacter, attributes: attachmentAttributes))
            inserted.append(NSAttributedString(string: "\n", attributes: base))
            storage.replaceCharacters(in: selection, with: inserted)
            return NSRange(location: location + inserted.length, length: 0)
        }
        host.journalFocus()
    }

    /// Nouvelle image d'une pièce jointe (dessin modifié).
    func refreshAttachment(_ uid: UUID) {
        guard let host else { return }
        let storage = host.journalStorage
        let selection = host.journalSelection
        storage.beginEditing()
        storage.enumerateAttribute(.journalAttachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard value as? String == uid.uuidString else { return }
            storage.addAttribute(.attachment, value: JournalTypography.makeAttachment(uid: uid, content: content(uid)),
                                 range: range)
        }
        storage.endEditing()
        host.journalSelection = selection
        host.journalDidEdit()
    }

    // MARK: - Toucher

    /// Élément aux alentours de `index` ; `contains` dit si le point touché est bien sur ce caractère.
    func item(near index: Int, contains: (NSRange) -> Bool) -> JournalTextItem? {
        guard let host else { return nil }
        let storage = host.journalStorage
        for candidate in [index, index - 1] where candidate >= 0 && candidate < storage.length {
            let attributes = storage.attributes(at: candidate, effectiveRange: nil)
            let single = NSRange(location: candidate, length: 1)
            if let uid = (attributes[.journalAttachment] as? String).flatMap(UUID.init(uuidString:)), contains(single) {
                return .attachment(uid)
            }
            if attributes[.attachment] is JournalCheckbox, contains(single) {
                let paragraph = (storage.string as NSString).paragraphRange(for: single)
                return .checkbox(paragraph.location)
            }
            if let uid = (attributes[.journalReference] as? String).flatMap(UUID.init(uuidString:)), contains(single) {
                return .reference(uid)
            }
        }
        return nil
    }

    /// Toucher un élément : la case se coche ; citation et pièce jointe s'ouvrent.
    func activate(_ item: JournalTextItem) {
        switch item {
        case .checkbox(let start): toggleCheckbox(at: start)
        case .reference, .attachment: onOpen(item)
        }
    }

    // MARK: - Outils

    /// Modification faite par l'éditeur, annulable d'un bloc (instantané du texte et de la sélection).
    private func edit(_ actionName: String, _ body: (NSTextStorage) -> NSRange?) {
        guard let host else { return }
        let storage = host.journalStorage
        let before = NSAttributedString(attributedString: storage)
        let selectionBefore = host.journalSelection
        storage.beginEditing()
        let selection = body(storage)
        storage.endEditing()
        if let selection {
            host.journalSelection = NSRange(location: min(selection.location, storage.length),
                                            length: min(selection.length, storage.length - min(selection.location, storage.length)))
        }
        registerUndo(actionName, restoring: before, selection: selectionBefore)
        host.journalDidEdit()
        if host.journalSelection.length == 0 {
            host.journalTypingAttributes = typingAttributes(at: host.journalSelection.location)
        }
        onChange()
        updateFormat()
    }

    private func registerUndo(_ actionName: String, restoring snapshot: NSAttributedString, selection: NSRange) {
        undoManager.registerUndo(withTarget: self) { controller in
            MainActor.assumeIsolated {
                controller.restore(snapshot, selection: selection, actionName: actionName)
            }
        }
        undoManager.setActionName(actionName)
    }

    private func restore(_ snapshot: NSAttributedString, selection: NSRange, actionName: String) {
        guard let host else { return }
        let storage = host.journalStorage
        let current = NSAttributedString(attributedString: storage)
        let currentSelection = host.journalSelection
        storage.setAttributedString(snapshot)
        host.journalSelection = NSRange(location: min(selection.location, storage.length), length: 0)
        registerUndo(actionName, restoring: current, selection: currentSelection)
        host.journalDidEdit()
        onChange()
        updateFormat()
    }

    /// Attributs de saisie au curseur : ceux du texte qui précède, sans citation. Au début d'un
    /// paragraphe vide, du corps de texte.
    private func typingAttributes(at location: Int) -> [NSAttributedString.Key: Any] {
        guard let host else { return [:] }
        let storage = host.journalStorage
        let text = storage.string as NSString
        let body = JournalTypography.typingAttributes(from: [:])
        guard text.length > 0 else { return body }
        if location > 0, text.character(at: location - 1) != 0x0A {
            return JournalTypography.typingAttributes(from: storage.attributes(at: location - 1, effectiveRange: nil))
        }
        guard location < text.length else { return body }
        let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
        guard JournalTypography.contentRange(of: paragraph, in: text).length > 0 else { return body }
        return JournalTypography.typingAttributes(from: storage.attributes(at: location, effectiveRange: nil))
    }

    private func updateFormat() {
        guard let host else { return }
        let storage = host.journalStorage
        let selection = host.journalSelection
        let attributes: [NSAttributedString.Key: Any]
        if selection.length > 0 {
            var first = selection.location
            while first < NSMaxRange(selection) - 1,
                  storage.attribute(.journalMarker, at: first, effectiveRange: nil) != nil { first += 1 }
            attributes = storage.attributes(at: first, effectiveRange: nil)
        } else {
            attributes = host.journalTypingAttributes
        }
        var style = (attributes[.journalStyle] as? String).flatMap(JournalText.Style.init) ?? .body
        var list: JournalText.List?
        let paragraphStart = selection.location < storage.length || selection.location > 0
            ? (storage.string as NSString).paragraphRange(for: NSRange(location: min(selection.location, storage.length), length: 0)).location
            : 0
        if paragraphStart < storage.length, markerRange(at: paragraphStart, in: storage) != nil {
            list = (storage.attribute(.journalList, at: paragraphStart, effectiveRange: nil) as? String)
                .flatMap(JournalText.List.init)
            style = (storage.attribute(.journalStyle, at: paragraphStart, effectiveRange: nil) as? String)
                .flatMap(JournalText.Style.init) ?? style
        }
        let selected = selection.length > 0 ? (storage.string as NSString).substring(with: selection) : ""
        let format = Format(
            style: style, list: list,
            bold: Trait.bold.isOn(attributes), italic: Trait.italic.isOn(attributes),
            underline: Trait.underline.isOn(attributes), strikethrough: Trait.strikethrough.isOn(attributes),
            selectedText: selected.replacingOccurrences(of: JournalText.attachmentCharacter, with: "")
        )
        if format != self.format { self.format = format }
    }

    /// Puce ou case au début du paragraphe qui contient `location`.
    private func markerRange(at location: Int, in storage: NSTextStorage) -> NSRange? {
        let text = storage.string as NSString
        guard location < text.length else { return nil }
        let start = text.paragraphRange(for: NSRange(location: location, length: 0)).location
        var range = NSRange()
        guard storage.attribute(.journalMarker, at: start, longestEffectiveRange: &range,
                                in: NSRange(location: start, length: text.length - start)) != nil else { return nil }
        return range
    }

    /// Citation entière qui contient le caractère `location`.
    private func referenceRange(containing location: Int, in storage: NSTextStorage) -> NSRange? {
        guard location >= 0, location < storage.length else { return nil }
        var range = NSRange()
        guard let uid = storage.attribute(.journalReference, at: location, longestEffectiveRange: &range,
                                          in: NSRange(location: 0, length: storage.length)) as? String else { return nil }
        _ = uid
        return range
    }

    /// Paragraphes touchés par une sélection (le paragraphe vide final compris).
    private func paragraphRanges(for selection: NSRange) -> [NSRange] {
        guard let host else { return [] }
        let text = host.journalStorage.string as NSString
        guard text.length > 0 else { return [NSRange(location: 0, length: 0)] }
        if selection.location >= text.length {
            if text.hasSuffix("\n") { return [NSRange(location: text.length, length: 0)] }
            return [text.paragraphRange(for: NSRange(location: text.length - 1, length: 0))]
        }
        var ranges: [NSRange] = []
        var location = selection.location
        let end = max(NSMaxRange(selection), selection.location + 1)
        while location < min(end, text.length) {
            let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
            ranges.append(paragraph)
            location = NSMaxRange(paragraph)
        }
        return ranges
    }
}
