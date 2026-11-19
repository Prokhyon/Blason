import SwiftUI
import SheetKit
#if canImport(UIKit)
import UIKit
typealias PlatformFont = UIFont
typealias PlatformColor = UIColor
#else
import AppKit
typealias PlatformFont = NSFont
typealias PlatformColor = NSColor
#endif

// Récit d'une session dans l'éditeur du système (UIKit ou AppKit) : la mise en forme est portée par
// des attributs propres à l'app (gras, style, liste, citation, pièce jointe) ; polices, couleurs et
// retraits s'en déduisent (`JournalTypography.restyle`). Le format enregistré est `JournalText`.

extension NSAttributedString.Key {
    static let journalBold = NSAttributedString.Key("ch.loristhomas.blason.bold")
    static let journalItalic = NSAttributedString.Key("ch.loristhomas.blason.italic")
    /// Style du paragraphe (`JournalText.Style`, valeur brute).
    static let journalStyle = NSAttributedString.Key("ch.loristhomas.blason.style")
    /// Liste du paragraphe (`JournalText.List`, valeur brute).
    static let journalList = NSAttributedString.Key("ch.loristhomas.blason.list")
    static let journalChecked = NSAttributedString.Key("ch.loristhomas.blason.checked")
    /// Caractères de la puce ou de la case d'un élément de liste (pas du texte).
    static let journalMarker = NSAttributedString.Key("ch.loristhomas.blason.marker")
    /// Fiche citée (`CodexEntry.uid`, en texte).
    static let journalReference = NSAttributedString.Key("ch.loristhomas.blason.reference")
    /// Pièce jointe (`JournalDocument.uid`, en texte).
    static let journalAttachment = NSAttributedString.Key("ch.loristhomas.blason.attachment")
}

/// Image d'une pièce jointe dans le texte.
struct JournalAttachmentContent {
    var image: PlatformImage?
    var kind: JournalDocument.Kind
    var title: String
}

/// Pièce jointe du récit : son image s'adapte à la largeur de la page.
nonisolated final class JournalTextAttachment: NSTextAttachment {
    var uid = UUID()
    var kind: JournalDocument.Kind = .image
    /// Rapport largeur / hauteur de l'image.
    var aspect: CGFloat = 4.0 / 3.0

    /// Taille d'affichage dans une ligne de `lineWidth` points.
    func displaySize(lineWidth: CGFloat) -> CGSize {
        let available = max(80, lineWidth - 8)
        // Un document (PDF, photo) en vignette ; croquis et écriture sur toute la largeur.
        let maxWidth: CGFloat = kind == .pdf || kind == .image ? min(available, 420) : available
        var width = maxWidth
        var height = width / max(aspect, 0.1)
        let maxHeight: CGFloat = kind == .handwriting ? 900 : 480
        if height > maxHeight {
            height = maxHeight
            width = height * aspect
        }
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    override func attachmentBounds(for attributes: [NSAttributedString.Key: Any], location: any NSTextLocation,
                                   textContainer: NSTextContainer?, proposedLineFragment: CGRect,
                                   position: CGPoint) -> CGRect {
        CGRect(origin: .zero, size: displaySize(lineWidth: proposedLineFragment.width))
    }

    #if canImport(UIKit)
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect,
                                   glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        CGRect(origin: .zero, size: displaySize(lineWidth: lineFrag.width))
    }
    #else
    override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: NSRect,
                                   glyphPosition position: NSPoint, characterIndex charIndex: Int) -> NSRect {
        CGRect(origin: .zero, size: displaySize(lineWidth: lineFrag.width))
    }
    #endif
}

/// Case d'une liste à cocher (marque de liste, pas une pièce jointe).
nonisolated final class JournalCheckbox: NSTextAttachment {
    var checked = false
}

/// Polices et couleurs du récit, données par le thème de la fiche (`SheetTheme.journal`).
/// Le format enregistré (`JournalText`) n'en garde rien : changer de thème ne touche pas au texte.
struct JournalStyle: Equatable {
    /// Corps de texte avec empattements (New York) ; sinon la police du système.
    var serif = false
    /// Police du corps de texte ; nil : celle du système (avec empattements si `serif`).
    var bodyFontName: String?
    /// Police du style Titre ; nil : celle du système, en gras.
    var titleFontName: String?
    /// Police des styles En-tête et Sous-en-tête ; nil : celle du système.
    var headingFontName: String?
    /// Taille des polices de titre et d'en-tête par rapport au style : une écriture manuscrite paraît
    /// plus petite qu'une police de texte de même corps.
    var fontScale: CGFloat = 1
    /// Texte ; nil : couleur du système.
    var text: Color?
    /// Titres et en-têtes (rubriques) ; nil : couleur du texte.
    var heading: Color?
    /// Citations et cases cochées ; nil : couleur d'accent du système.
    var accent: Color?
}

enum JournalTypography {
    static let listIndent: CGFloat = 24

    // MARK: Thème

    /// Style du récit en cours d'édition. Les fonctions de mise en forme le lisent ; le contrôleur
    /// l'installe avant chaque modification (deux fenêtres peuvent montrer deux thèmes).
    private(set) static var theme = JournalStyle()
    private static var colors = Colors(JournalStyle())

    /// Installe un style ; `true` s'il change (le texte affiché est alors à remettre en forme).
    @discardableResult
    static func use(_ style: JournalStyle) -> Bool {
        guard style != theme else { return false }
        theme = style
        colors = Colors(style)
        return true
    }

    /// Couleurs du style, converties une fois pour la vue de texte.
    private struct Colors {
        let text, secondary, tertiary, heading, accent: PlatformColor

        init(_ style: JournalStyle) {
            #if canImport(UIKit)
            let text = style.text.map { UIColor($0) }
            self.text = text ?? .label
            secondary = text?.withAlphaComponent(0.6) ?? .secondaryLabel
            tertiary = text?.withAlphaComponent(0.35) ?? .tertiaryLabel
            accent = style.accent.map { UIColor($0) } ?? .tintColor
            #else
            let text = style.text.map { NSColor($0) }
            self.text = text ?? .labelColor
            secondary = text?.withAlphaComponent(0.6) ?? .secondaryLabelColor
            tertiary = text?.withAlphaComponent(0.35) ?? .tertiaryLabelColor
            accent = style.accent.map { NSColor($0) } ?? .controlAccentColor
            #endif
            heading = style.heading.map { PlatformColor($0) } ?? self.text
        }
    }

    /// Police propre au thème pour ce style de paragraphe, s'il en donne une.
    private static func themeFontName(for style: JournalText.Style) -> String? {
        switch style {
        case .title: theme.titleFontName
        case .heading, .subheading: theme.headingFontName
        case .body: theme.bodyFontName
        case .monospaced: nil
        }
    }

    // MARK: Polices et couleurs

    static func font(style: JournalText.Style, bold: Bool, italic: Bool) -> PlatformFont {
        #if canImport(UIKit)
        var base: UIFont
        var traits: UIFontDescriptor.SymbolicTraits = []
        switch style {
        case .body: base = .preferredFont(forTextStyle: .body)
        case .title: base = .preferredFont(forTextStyle: .title1); traits.insert(.traitBold)
        case .heading: base = .preferredFont(forTextStyle: .title3); traits.insert(.traitBold)
        case .subheading: base = .preferredFont(forTextStyle: .headline)
        case .monospaced:
            base = .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        }
        if let name = themeFontName(for: style), let custom = UIFont(name: name, size: base.pointSize * (style == .body ? 1 : theme.fontScale)) {
            base = custom
            traits.remove(.traitBold)
        } else if theme.serif, style != .monospaced, let serif = base.fontDescriptor.withDesign(.serif) {
            base = UIFont(descriptor: serif, size: 0)
        }
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        guard !traits.isEmpty,
              let descriptor = base.fontDescriptor.withSymbolicTraits(base.fontDescriptor.symbolicTraits.union(traits))
        else { return base }
        return UIFont(descriptor: descriptor, size: 0)
        #else
        var base: NSFont
        var traits: NSFontDescriptor.SymbolicTraits = []
        switch style {
        case .body: base = .preferredFont(forTextStyle: .body)
        case .title: base = .preferredFont(forTextStyle: .title1); traits.insert(.bold)
        case .heading: base = .preferredFont(forTextStyle: .title3); traits.insert(.bold)
        case .subheading: base = .preferredFont(forTextStyle: .headline)
        case .monospaced:
            base = .monospacedSystemFont(ofSize: NSFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
        }
        if let name = themeFontName(for: style), let custom = NSFont(name: name, size: base.pointSize * (style == .body ? 1 : theme.fontScale)) {
            base = custom
            traits.remove(.bold)
        } else if theme.serif, style != .monospaced, let serif = base.fontDescriptor.withDesign(.serif),
                  let font = NSFont(descriptor: serif, size: 0) {
            base = font
        }
        if bold { traits.insert(.bold) }
        if italic { traits.insert(.italic) }
        guard !traits.isEmpty else { return base }
        let descriptor = base.fontDescriptor.withSymbolicTraits(base.fontDescriptor.symbolicTraits.union(traits))
        return NSFont(descriptor: descriptor, size: 0) ?? base
        #endif
    }

    static var textColor: PlatformColor { colors.text }
    static var secondaryColor: PlatformColor { colors.secondary }
    static var referenceColor: PlatformColor { colors.accent }

    static func paragraphStyle(style: JournalText.Style, list: JournalText.List?) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacingBefore = style == .body || style == .monospaced ? 0 : 6
        paragraph.paragraphSpacing = list == nil ? 4 : 2
        if list != nil {
            paragraph.headIndent = listIndent
            paragraph.tabStops = [NSTextTab(textAlignment: .left, location: listIndent)]
            paragraph.defaultTabInterval = listIndent
        }
        return paragraph
    }

    /// Puce ou case d'un élément de liste, suivie d'une tabulation. La case est une image (symbole).
    static func marker(_ list: JournalText.List, checked: Bool, style: JournalText.Style) -> NSAttributedString {
        let attributes = attributes(style: style, list: list, checked: checked, bold: false, italic: false,
                                    underline: false, strikethrough: false, reference: nil, marker: true)
        switch list {
        case .bullet:
            return NSAttributedString(string: "•\t", attributes: attributes)
        case .checklist:
            let result = NSMutableAttributedString(attachment: checkbox(checked: checked, style: style))
            result.addAttributes(attributes, range: NSRange(location: 0, length: result.length))
            result.append(NSAttributedString(string: "\t", attributes: attributes))
            return result
        }
    }

    /// Case d'une liste à cocher, à la taille du texte.
    static func checkbox(checked: Bool, style: JournalText.Style) -> JournalCheckbox {
        let pointSize = font(style: style, bold: false, italic: false).pointSize
        let side = (pointSize * 1.15).rounded()
        let name = checked ? "checkmark.circle.fill" : "circle"
        let attachment = JournalCheckbox()
        attachment.checked = checked
        #if canImport(UIKit)
        let configuration = UIImage.SymbolConfiguration(pointSize: side, weight: .regular)
        attachment.image = UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(checked ? colors.accent : colors.tertiary, renderingMode: .alwaysOriginal)
        #else
        let configuration = NSImage.SymbolConfiguration(pointSize: side, weight: .regular)
            .applying(.init(paletteColors: [checked ? colors.accent : colors.tertiary]))
        attachment.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        #endif
        let descender = font(style: style, bold: false, italic: false).descender
        attachment.bounds = CGRect(x: 0, y: descender + 1, width: side, height: side)
        return attachment
    }

    // MARK: Attributs

    /// Attributs du paragraphe, posés sur tous ses caractères (retour à la ligne compris).
    static func paragraphAttributes(style: JournalText.Style, list: JournalText.List?, checked: Bool)
        -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .journalStyle: style.rawValue,
            .paragraphStyle: paragraphStyle(style: style, list: list),
        ]
        if let list {
            attributes[.journalList] = list.rawValue
            if list == .checklist { attributes[.journalChecked] = checked }
        }
        return attributes
    }

    /// Attributs complets d'un caractère, déduits de sa mise en forme.
    static func attributes(style: JournalText.Style, list: JournalText.List?, checked: Bool, bold: Bool, italic: Bool,
                           underline: Bool, strikethrough: Bool, reference: String?, marker: Bool)
        -> [NSAttributedString.Key: Any] {
        var attributes = paragraphAttributes(style: style, list: list, checked: checked)
        attributes[.font] = font(style: style, bold: bold || reference != nil && style == .body, italic: italic)
        let isHeading = style == .title || style == .heading || style == .subheading
        attributes[.foregroundColor] = reference != nil ? referenceColor
            : marker && list == .checklist ? (checked ? referenceColor : secondaryColor)
            : checked && list == .checklist ? secondaryColor : isHeading ? colors.heading : textColor
        if bold { attributes[.journalBold] = true }
        if italic { attributes[.journalItalic] = true }
        if underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if strikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if let reference { attributes[.journalReference] = reference }
        if marker { attributes[.journalMarker] = true }
        return attributes
    }

    /// Attributs de saisie à une position : la mise en forme du texte qui précède, sans citation.
    static func typingAttributes(from existing: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        let style = (existing[.journalStyle] as? String).flatMap(JournalText.Style.init) ?? .body
        let list = (existing[.journalList] as? String).flatMap(JournalText.List.init)
        return attributes(style: style, list: list, checked: existing[.journalChecked] as? Bool ?? false,
                          bold: existing[.journalBold] as? Bool ?? false, italic: existing[.journalItalic] as? Bool ?? false,
                          underline: (existing[.underlineStyle] as? Int ?? 0) != 0,
                          strikethrough: (existing[.strikethroughStyle] as? Int ?? 0) != 0,
                          reference: nil, marker: false)
    }

    // MARK: JournalText → texte de l'éditeur

    static func attributedString(from text: JournalText,
                                 content: (UUID) -> JournalAttachmentContent?) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, paragraph) in text.paragraphs.enumerated() {
            let checked = paragraph.checked ?? false
            if let list = paragraph.list {
                result.append(marker(list, checked: checked, style: paragraph.style))
            }
            for run in paragraph.runs {
                var runAttributes = attributes(
                    style: paragraph.style, list: paragraph.list, checked: checked, bold: run.bold, italic: run.italic,
                    underline: run.underline, strikethrough: run.strikethrough,
                    reference: run.reference?.uuidString, marker: false)
                if let uid = run.attachment {
                    runAttributes[.attachment] = makeAttachment(uid: uid, content: content(uid))
                    runAttributes[.journalAttachment] = uid.uuidString
                    result.append(NSAttributedString(string: JournalText.attachmentCharacter, attributes: runAttributes))
                } else {
                    result.append(NSAttributedString(string: run.text, attributes: runAttributes))
                }
            }
            if index < text.paragraphs.count - 1 {
                result.append(NSAttributedString(string: "\n", attributes: attributes(
                    style: paragraph.style, list: paragraph.list, checked: checked, bold: false, italic: false,
                    underline: false, strikethrough: false, reference: nil, marker: false)))
            }
        }
        return result
    }

    static func makeAttachment(uid: UUID, content: JournalAttachmentContent?) -> JournalTextAttachment {
        let attachment = JournalTextAttachment()
        attachment.uid = uid
        attachment.kind = content?.kind ?? .image
        let image = content?.image.map { framed($0, kind: content?.kind ?? .image) }
            ?? placeholderImage(for: content?.kind)
        attachment.image = image
        if let image, image.size.width > 0, image.size.height > 0 {
            attachment.aspect = image.size.width / image.size.height
        }
        return attachment
    }

    /// Fond « papier » des croquis et de l'écriture : l'encre reste lisible en mode sombre.
    static let paperColor = CGColor(red: 0.988, green: 0.976, blue: 0.949, alpha: 1)

    /// Image d'une pièce jointe dans le texte : coins arrondis et filet ; un dessin sur fond papier.
    static func framed(_ image: PlatformImage, kind: JournalDocument.Kind) -> PlatformImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let radius = max(size.width, size.height) * 0.02
        let paper = kind == .sketch || kind == .handwriting
        let draw: (CGContext) -> Void = { context in
            let rect = CGRect(origin: .zero, size: size)
            let path = CGPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerWidth: radius, cornerHeight: radius,
                              transform: nil)
            context.saveGState()
            context.addPath(path)
            context.clip()
            if paper {
                context.setFillColor(paperColor)
                context.fill(rect)
            }
            #if canImport(UIKit)
            image.draw(in: rect)
            #else
            image.draw(in: rect)
            #endif
            context.restoreGState()
            context.addPath(path)
            context.setStrokeColor(CGColor(gray: 0.5, alpha: 0.35))
            context.setLineWidth(max(1, size.width / 400))
            context.strokePath()
        }
        #if canImport(UIKit)
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { draw($0.cgContext) }
        #else
        return NSImage(size: size, flipped: false) { _ in
            if let context = NSGraphicsContext.current?.cgContext { draw(context) }
            return true
        }
        #endif
    }

    /// Image de secours : document introuvable ou croquis vide.
    static func placeholderImage(for kind: JournalDocument.Kind?) -> PlatformImage? {
        let name = switch kind {
        case .sketch: "scribble"
        case .handwriting: "pencil.and.scribble"
        case .pdf: "doc.richtext"
        case .image: "photo"
        case nil: "questionmark.square.dashed"
        }
        #if canImport(UIKit)
        return UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: 64, weight: .light))?
            .withTintColor(.tertiaryLabel, renderingMode: .alwaysOriginal)
        #else
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 64, weight: .light))
        #endif
    }

    // MARK: Texte de l'éditeur → JournalText

    static func journalText(from string: NSAttributedString) -> JournalText {
        let text = string.string as NSString
        var paragraphs: [JournalText.Paragraph] = []
        var location = 0
        while location < text.length {
            let range = text.paragraphRange(for: NSRange(location: location, length: 0))
            let content = contentRange(of: range, in: text)
            paragraphs.append(paragraph(in: string, range: range, content: content))
            location = NSMaxRange(range)
        }
        if text.length > 0, text.hasSuffix("\n") {
            // Dernier paragraphe vide, après le dernier retour à la ligne.
            let attributes = string.attributes(at: text.length - 1, effectiveRange: nil)
            let style = (attributes[.journalStyle] as? String).flatMap(JournalText.Style.init) ?? .body
            paragraphs.append(JournalText.Paragraph(style: style == .title || style == .heading || style == .subheading ? .body : style))
        }
        return JournalText(paragraphs: paragraphs).normalized()
    }

    /// Paragraphe sans son retour à la ligne final.
    static func contentRange(of paragraph: NSRange, in text: NSString) -> NSRange {
        var content = paragraph
        while content.length > 0 {
            let last = text.character(at: NSMaxRange(content) - 1)
            guard last == 0x0A || last == 0x0D || last == 0x2029 else { break }
            content.length -= 1
        }
        return content
    }

    private static func paragraph(in string: NSAttributedString, range: NSRange, content: NSRange) -> JournalText.Paragraph {
        let first = range.length > 0 ? string.attributes(at: range.location, effectiveRange: nil) : [:]
        let style = (first[.journalStyle] as? String).flatMap(JournalText.Style.init) ?? .body
        let hasMarker = content.length > 0 && first[.journalMarker] as? Bool == true
        let list = hasMarker ? (first[.journalList] as? String).flatMap(JournalText.List.init) : nil
        var runs: [JournalText.Run] = []
        string.enumerateAttributes(in: content) { attributes, runRange, _ in
            if attributes[.journalMarker] as? Bool == true { return }
            if let uid = (attributes[.journalAttachment] as? String).flatMap(UUID.init(uuidString:)) {
                for _ in 0..<runRange.length { runs.append(.attachment(uid)) }
                return
            }
            let piece = (string.string as NSString).substring(with: runRange)
                .replacingOccurrences(of: JournalText.attachmentCharacter, with: "")
            guard !piece.isEmpty else { return }
            runs.append(JournalText.Run(
                text: piece,
                bold: attributes[.journalBold] as? Bool ?? false,
                italic: attributes[.journalItalic] as? Bool ?? false,
                underline: (attributes[.underlineStyle] as? Int ?? 0) != 0,
                strikethrough: (attributes[.strikethroughStyle] as? Int ?? 0) != 0,
                reference: (attributes[.journalReference] as? String).flatMap(UUID.init(uuidString:))
            ))
        }
        return JournalText.Paragraph(style: style, list: list,
                                     checked: list == .checklist ? (first[.journalChecked] as? Bool ?? false) : nil,
                                     runs: runs)
    }

    // MARK: Remise en forme

    /// Réapplique polices, couleurs et retraits des paragraphes qui touchent `range`, d'après leurs
    /// attributs propres ; retire au passage les attributs étrangers (texte collé, glissé).
    /// Le style et la liste d'un paragraphe sont ceux de son premier caractère.
    static func restyle(_ storage: NSMutableAttributedString, in range: NSRange) {
        let text = storage.string as NSString
        guard text.length > 0 else { return }
        let start = min(range.location, text.length - 1)
        let end = min(NSMaxRange(range), text.length)
        var location = text.paragraphRange(for: NSRange(location: start, length: 0)).location
        storage.beginEditing()
        while location < end || location == start {
            let paragraph = text.paragraphRange(for: NSRange(location: location, length: 0))
            guard paragraph.length > 0 else { break }
            let first = storage.attributes(at: paragraph.location, effectiveRange: nil)
            // Un paragraphe vide (hors liste) redevient du corps de texte.
            let isEmpty = contentRange(of: paragraph, in: text).length == 0
            let style = isEmpty ? .body : (first[.journalStyle] as? String).flatMap(JournalText.Style.init) ?? .body
            let hasMarker = first[.journalMarker] as? Bool == true
            let list = hasMarker ? (first[.journalList] as? String).flatMap(JournalText.List.init) : nil
            let checked = first[.journalChecked] as? Bool ?? false
            storage.enumerateAttributes(in: paragraph) { attributes, runRange, _ in
                var fresh = Self.attributes(
                    style: style, list: list, checked: checked,
                    bold: attributes[.journalBold] as? Bool ?? false, italic: attributes[.journalItalic] as? Bool ?? false,
                    underline: (attributes[.underlineStyle] as? Int ?? 0) != 0,
                    strikethrough: (attributes[.strikethroughStyle] as? Int ?? 0) != 0,
                    reference: attributes[.journalReference] as? String,
                    marker: list != nil && attributes[.journalMarker] as? Bool == true)
                if let attachment = attributes[.attachment] as? JournalTextAttachment {
                    fresh[.attachment] = attachment
                    fresh[.journalAttachment] = attributes[.journalAttachment] ?? attachment.uid.uuidString
                } else if let checkbox = attributes[.attachment] as? JournalCheckbox, fresh[.journalMarker] != nil {
                    fresh[.attachment] = checkbox
                }
                storage.setAttributes(fresh, range: runRange)
            }
            location = NSMaxRange(paragraph)
            if location >= text.length { break }
        }
        storage.endEditing()
    }
}
