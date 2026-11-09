import Foundation
import SwiftData

/// Apparence d'une fiche : un thème et une couleur, désignés par identifiant (l'app connaît les
/// thèmes et la palette ; un identifiant inconnu, venu d'une version plus récente, revient au défaut).
public struct SheetAppearance: Equatable, Sendable {
    public var themeID: String
    public var colorID: String

    public static let defaultThemeID = "native"
    public static let defaultColorID = "blue"
    public static let standard = SheetAppearance(themeID: defaultThemeID, colorID: defaultColorID)

    public init(themeID: String, colorID: String) {
        self.themeID = themeID
        self.colorID = colorID
    }
}

extension Sheet {
    /// Apparence choisie pour cette fiche ; nil : aucune (défaut, ou celle du template pour un personnage).
    public var ownAppearance: SheetAppearance? {
        get {
            themeID.map { SheetAppearance(themeID: $0, colorID: themeColor ?? SheetAppearance.defaultColorID) }
        }
        set {
            themeID = newValue?.themeID
            themeColor = newValue?.colorID
        }
    }

    /// Apparence effective : la sienne ; pour un personnage qui n'en a pas, celle de son template
    /// (s'il existe encore) ; sinon le thème natif.
    public func appearance(in context: ModelContext?) -> SheetAppearance {
        if let own = ownAppearance { return own }
        if let character, let context, let template = character.sourceTemplate(in: context) {
            return template.sheet?.ownAppearance ?? .standard
        }
        return .standard
    }
}

extension PlayerCharacter {
    /// Template d'origine, s'il existe encore.
    public func sourceTemplate(in context: ModelContext) -> SheetTemplate? {
        guard let templateUID = sourceTemplateUID else { return nil }
        var descriptor = FetchDescriptor<SheetTemplate>(predicate: #Predicate { $0.uid == templateUID })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
