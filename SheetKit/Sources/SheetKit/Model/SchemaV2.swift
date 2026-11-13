import Foundation
import SwiftData

// Modèle de données v2 — **brouillon** (SPEC §5.16) : il change tant que la Besace et le journal
// se mettent au point. Il contient le modèle v1 inchangé, plus des ajouts seulement (exigence
// CloudKit pour la réactivation d'iCloud). Mêmes règles que v1 (SPEC §7) : valeurs par défaut,
// relations optionnelles avec inverse, pas de `unique`, ordre par `order`.

public enum SheetSchemaV2: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            SheetTemplate.self, PlayerCharacter.self, Sheet.self, Page.self, SheetRow.self,
            SheetSection.self, SheetField.self, SheetTableColumn.self, SheetTableGroup.self,
            SheetTableRow.self, SheetTableCell.self,
            Inventory.self, ItemType.self, ItemProperty.self, InventoryItem.self, ItemPropertyValue.self,
            Currency.self, InventorySlot.self, EncumbranceLevel.self,
            Journal.self, JournalSession.self, CodexEntry.self, JournalDocument.self,
        ]
    }
}

public typealias SheetTemplate = SheetSchemaV2.SheetTemplate
public typealias PlayerCharacter = SheetSchemaV2.PlayerCharacter
public typealias Sheet = SheetSchemaV2.Sheet
public typealias Page = SheetSchemaV2.Page
public typealias SheetRow = SheetSchemaV2.SheetRow
public typealias SheetSection = SheetSchemaV2.SheetSection
public typealias SheetField = SheetSchemaV2.SheetField
public typealias SheetTableColumn = SheetSchemaV2.SheetTableColumn
public typealias SheetTableGroup = SheetSchemaV2.SheetTableGroup
public typealias SheetTableRow = SheetSchemaV2.SheetTableRow
public typealias SheetTableCell = SheetSchemaV2.SheetTableCell
public typealias Inventory = SheetSchemaV2.Inventory
public typealias ItemType = SheetSchemaV2.ItemType
public typealias ItemProperty = SheetSchemaV2.ItemProperty
public typealias InventoryItem = SheetSchemaV2.InventoryItem
public typealias ItemPropertyValue = SheetSchemaV2.ItemPropertyValue
public typealias Currency = SheetSchemaV2.Currency
public typealias InventorySlot = SheetSchemaV2.InventorySlot
public typealias EncumbranceLevel = SheetSchemaV2.EncumbranceLevel
public typealias Journal = SheetSchemaV2.Journal
public typealias JournalSession = SheetSchemaV2.JournalSession
public typealias CodexEntry = SheetSchemaV2.CodexEntry
public typealias JournalDocument = SheetSchemaV2.JournalDocument

extension SheetSchemaV2 {

    // MARK: Bibliothèque

    /// Structure de fiche pour un système de jeu.
    @Model
    public final class SheetTemplate {
        public var uid: UUID = UUID()
        public var name: String = ""
        public var system: String = ""
        public var notes: String = ""
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()

        @Relationship(deleteRule: .cascade, inverse: \Sheet.template)
        public var sheet: Sheet?

        public init(name: String, system: String = "") {
            self.name = name
            self.system = system
        }
    }

    /// Personnage : possède sa propre copie de la structure, avec ses valeurs.
    @Model
    public final class PlayerCharacter {
        public var uid: UUID = UUID()
        /// Nom de secours ; le nom affiché vient du champ « nom » de la fiche s'il existe.
        public var name: String = ""
        /// Template d'origine (informatif : le lien n'est pas maintenu).
        public var sourceTemplateUID: UUID?
        public var sourceTemplateName: String = ""
        public var createdAt: Date = Date()
        public var updatedAt: Date = Date()

        @Relationship(deleteRule: .cascade, inverse: \Sheet.character)
        public var sheet: Sheet?

        // V2 : journal du personnage (créé à la première ouverture).
        @Relationship(deleteRule: .cascade, inverse: \Journal.character)
        public var journal: Journal?

        public init(name: String) {
            self.name = name
        }
    }

    // MARK: Structure

    /// Contenu d'une fiche. Appartient soit à un template, soit à un personnage.
    @Model
    public final class Sheet {
        @Relationship(deleteRule: .cascade, inverse: \Page.sheet)
        public var pages: [Page]? = []

        public var template: SheetTemplate?
        public var character: PlayerCharacter?

        /// Thème d'affichage (identifiant connu de l'app) ; nil : thème natif pour un template,
        /// celui du template pour un personnage.
        public var themeID: String?
        /// Couleur du thème (identifiant de la palette de l'app).
        public var themeColor: String?

        public init() {}
    }

    /// Onglet de la fiche.
    @Model
    public final class Page {
        public var title: String = ""
        public var order: Int = 0

        @Relationship(deleteRule: .cascade, inverse: \SheetRow.page)
        public var rows: [SheetRow]? = []

        public var sheet: Sheet?

        public init(title: String, order: Int = 0) {
            self.title = title
            self.order = order
        }
    }

    /// Rangée d'une page : 1 à N colonnes de largeurs relatives ; chaque colonne
    /// empile ses sections (`SheetSection.columnIndex`).
    @Model
    public final class SheetRow {
        public var order: Int = 0
        /// Largeurs relatives des colonnes (ex. [2, 1] → ⅔ – ⅓). Le nombre d'éléments
        /// donne le nombre de colonnes.
        public var columnWeights: [Double] = [1]

        @Relationship(deleteRule: .cascade, inverse: \SheetSection.row)
        public var sections: [SheetSection]? = []

        public var page: Page?

        public init(order: Int = 0) {
            self.order = order
        }
    }

    /// Bloc titré : champs ou tableau.
    @Model
    public final class SheetSection {
        public var title: String = ""
        /// Colonne de la rangée qui contient la section.
        public var columnIndex: Int = 0
        /// Position dans la colonne.
        public var order: Int = 0
        public var kindRaw: String = SectionKind.fields.rawValue
        /// Disposition des champs (sections « Champs »).
        public var arrangementRaw: String = FieldArrangement.list.rawValue
        /// Colonnes de la grille, nombre de listes, ou colonnes d'affichage d'un tableau.
        public var columnCount: Int = 1
        /// Titre de la colonne implicite des libellés d'un tableau (« Compétence », « Arme »…).
        public var labelColumnTitle: String = ""

        @Relationship(deleteRule: .cascade, inverse: \SheetField.section)
        public var fields: [SheetField]? = []

        @Relationship(deleteRule: .cascade, inverse: \SheetTableColumn.section)
        public var columns: [SheetTableColumn]? = []

        @Relationship(deleteRule: .cascade, inverse: \SheetTableGroup.section)
        public var groups: [SheetTableGroup]? = []

        // V2 : Besace

        /// Contenu d'une section « Besace ».
        @Relationship(deleteRule: .cascade, inverse: \Inventory.section)
        public var inventory: Inventory?
        /// Vue de la Besace : codes des types d'objets montrés (objets équipés seulement).
        public var viewTypeCodes: [String] = []
        /// Vue de la Besace : codes des propriétés montrées en colonnes, dans l'ordre.
        public var viewPropertyCodes: [String] = []

        public var row: SheetRow?

        public init(title: String, kind: SectionKind = .fields, order: Int = 0) {
            self.title = title
            self.kindRaw = kind.rawValue
            self.order = order
        }
    }

    /// Donnée typée et nommée.
    @Model
    public final class SheetField {
        public var label: String = ""
        /// Identifiant court utilisé dans les formules (ex. « FOR »). Vide si non référencé.
        public var code: String = ""
        public var order: Int = 0
        public var kindRaw: String = FieldKind.text.rawValue
        public var labelPlacementRaw: String = LabelPlacement.leading.rawValue
        /// Largeur dans une grille (`FieldWidth`). Ajout V2.
        public var widthRaw: String = FieldWidth.auto.rawValue
        /// Liste d'appartenance quand la section est en disposition `columns`, `pairs` ou `tiles`.
        public var listIndex: Int = 0
        /// Valeur vivante : modifiable en mode Jouer.
        public var isLive: Bool = false
        /// Ce champ porte le nom du personnage (affiché dans la bibliothèque).
        public var isNameField: Bool = false

        // Configuration
        public var unit: String?
        public var hint: String?
        public var minimum: Double?
        public var maximum: Double?
        public var step: Double?
        public var options: [String] = []
        public var resourceStyleRaw: String = ResourceStyle.counter.rawValue
        /// Formule (`=FOR*5`). Type `formula` : valeur calculée. Ressource : calcule le maximum.
        /// Autres types : valeur par défaut calculée, modifiable à la main.
        public var formula: String?

        // Valeur (selon le type)
        public var textValue: String?
        public var numberValue: Double?
        /// Maximum d'une ressource.
        public var resourceMax: Double?
        public var boolValue: Bool?
        public var dateValue: Date?
        @Attribute(.externalStorage)
        public var imageData: Data?

        public var section: SheetSection?

        public init(label: String, kind: FieldKind = .text, code: String = "", order: Int = 0) {
            self.label = label
            self.kindRaw = kind.rawValue
            self.code = code
            self.order = order
        }
    }

    // MARK: Tableaux

    /// Colonne typée d'un tableau.
    @Model
    public final class SheetTableColumn {
        public var title: String = ""
        /// Identifiant utilisé dans les formules de ligne (ex. `=valeur/2`).
        public var code: String = ""
        public var order: Int = 0
        public var kindRaw: String = ColumnKind.text.rawValue
        /// Formule de colonne, appliquée à chaque ligne.
        public var formula: String?
        /// Modifiable en mode Jouer (ex. case « compétence utilisée »).
        public var isLive: Bool = false

        @Relationship(deleteRule: .cascade, inverse: \SheetTableCell.column)
        public var cells: [SheetTableCell]? = []

        public var section: SheetSection?

        public init(title: String, kind: ColumnKind, code: String, order: Int = 0) {
            self.title = title
            self.kindRaw = kind.rawValue
            self.code = code
            self.order = order
        }
    }

    /// Groupe de lignes avec en-tête (ex. « Communication »).
    @Model
    public final class SheetTableGroup {
        public var title: String = ""
        public var order: Int = 0
        /// Le groupe porte sa propre valeur (ex. bonus de catégorie BRP).
        public var hasValue: Bool = false
        public var numberValue: Double?

        @Relationship(deleteRule: .cascade, inverse: \SheetTableRow.group)
        public var rows: [SheetTableRow]? = []

        public var section: SheetSection?

        public init(title: String, order: Int = 0, hasValue: Bool = false) {
            self.title = title
            self.order = order
            self.hasValue = hasValue
        }
    }

    /// Ligne d'un tableau.
    @Model
    public final class SheetTableRow {
        public var order: Int = 0
        public var label: String = ""
        /// Complément libre : « Langue (Latin) », « Monter (Navire) ».
        public var specialization: String?
        public var allowsSpecialization: Bool = false
        /// Ligne définie dans le template (par opposition à une ligne ajoutée par le joueur).
        public var isFromTemplate: Bool = true

        @Relationship(deleteRule: .cascade, inverse: \SheetTableCell.row)
        public var cells: [SheetTableCell]? = []

        public var group: SheetTableGroup?

        public init(label: String, order: Int = 0) {
            self.label = label
            self.order = order
        }
    }

    /// Cellule à l'intersection d'une ligne et d'une colonne.
    @Model
    public final class SheetTableCell {
        public var textValue: String?
        public var numberValue: Double?
        public var boolValue: Bool?
        /// Formule propre à la cellule (ex. base « =DEX*2 »).
        public var formula: String?

        public var row: SheetTableRow?
        public var column: SheetTableColumn?

        public init() {}
    }

    // MARK: Besace (V2)

    /// Besace d'une section « Besace » : réglages, types d'objets, monnaies, emplacements, paliers.
    @Model
    public final class Inventory {
        /// Code dans les formules : `BESACE.poids`, `BESACE.limite`, `BESACE.malus`, `BESACE.argent`.
        public var code: String = "BESACE"
        /// Poids et encombrement. Désactivé : aucun poids n'est affiché.
        public var tracksWeight: Bool = false
        /// Unité de poids (« kg », « lb », « enc. »).
        public var weightUnit: String = "kg"
        /// Charge maximale (formule, ex. `=FOR*2`) : `BESACE.limite`.
        public var weightLimitFormula: String?
        /// Les paliers d'encombrement appliquent leur malus (`BESACE.malus`).
        public var appliesMalus: Bool = false

        @Relationship(deleteRule: .cascade, inverse: \ItemType.inventory)
        public var itemTypes: [ItemType]? = []
        @Relationship(deleteRule: .cascade, inverse: \Currency.inventory)
        public var currencies: [Currency]? = []
        @Relationship(deleteRule: .cascade, inverse: \InventorySlot.inventory)
        public var slots: [InventorySlot]? = []
        @Relationship(deleteRule: .cascade, inverse: \EncumbranceLevel.inventory)
        public var levels: [EncumbranceLevel]? = []

        public var section: SheetSection?

        public init() {}
    }

    /// Type d'objet (Arme, Armure…) et ses propriétés.
    @Model
    public final class ItemType {
        public var name: String = ""
        /// Identifiant court (vues de la Besace).
        public var code: String = ""
        /// Symbole SF.
        public var icon: String = "shippingbox"
        public var order: Int = 0

        @Relationship(deleteRule: .cascade, inverse: \ItemProperty.type)
        public var properties: [ItemProperty]? = []
        /// Un type supprimé laisse ses objets sans type.
        @Relationship(deleteRule: .nullify, inverse: \InventoryItem.type)
        public var items: [InventoryItem]? = []

        public var inventory: Inventory?

        public init(name: String, code: String = "", icon: String = "shippingbox", order: Int = 0) {
            self.name = name
            self.code = code
            self.icon = icon
            self.order = order
        }
    }

    /// Propriété d'un type d'objet : typée comme une colonne de tableau. Ses valeurs servent
    /// de défaut aux objets du type.
    @Model
    public final class ItemProperty {
        public var label: String = ""
        /// Identifiant dans les formules de l'objet (`=pct/2`) et les vues de la Besace.
        public var code: String = ""
        public var order: Int = 0
        public var kindRaw: String = ColumnKind.text.rawValue
        public var formula: String?
        /// Modifiable en mode Jouer.
        public var isLive: Bool = false
        public var textValue: String?
        public var numberValue: Double?
        public var boolValue: Bool?

        @Relationship(deleteRule: .cascade, inverse: \ItemPropertyValue.property)
        public var values: [ItemPropertyValue]? = []

        public var type: ItemType?

        public init(label: String, kind: ColumnKind = .text, code: String = "", order: Int = 0) {
            self.label = label
            self.kindRaw = kind.rawValue
            self.code = code
            self.order = order
        }
    }

    /// Objet de la Besace. Toujours dans un emplacement ; éventuellement dans un contenant
    /// (un seul niveau). Avec une monnaie, c'est un compteur d'argent (`quantity` pièces).
    @Model
    public final class InventoryItem {
        public var name: String = ""
        public var quantity: Double = 1
        /// Poids d'un exemplaire (unité de la Besace).
        public var unitWeight: Double?
        /// Valeur marchande, en texte libre (« 50 po »).
        public var price: String = ""
        public var isEquipped: Bool = false
        /// Sac, bourse, carquois : peut contenir d'autres objets.
        public var isContainer: Bool = false
        public var summary: String = ""
        public var notes: String = ""
        @Attribute(.externalStorage)
        public var imageData: Data?
        public var order: Int = 0

        public var type: ItemType?
        public var currency: Currency?
        public var slot: InventorySlot?
        /// Contenant ; supprimé, ses objets restent dans l'emplacement.
        public var container: InventoryItem?
        @Relationship(deleteRule: .nullify, inverse: \InventoryItem.container)
        public var contents: [InventoryItem]? = []

        @Relationship(deleteRule: .cascade, inverse: \ItemPropertyValue.item)
        public var propertyValues: [ItemPropertyValue]? = []

        public init(name: String, quantity: Double = 1, order: Int = 0) {
            self.name = name
            self.quantity = quantity
            self.order = order
        }
    }

    /// Valeur d'une propriété pour un objet (absente : défaut de la propriété).
    @Model
    public final class ItemPropertyValue {
        public var textValue: String?
        public var numberValue: Double?
        public var boolValue: Bool?
        public var formula: String?

        public var item: InventoryItem?
        public var property: ItemProperty?

        public init() {}
    }

    /// Monnaie : valeur relative à la plus petite (pièce de cuivre = 1, d'or = 100).
    @Model
    public final class Currency {
        public var name: String = ""
        public var abbreviation: String = ""
        public var rate: Double = 1
        public var order: Int = 0

        /// Une monnaie supprimée laisse ses compteurs comme objets ordinaires.
        @Relationship(deleteRule: .nullify, inverse: \InventoryItem.currency)
        public var items: [InventoryItem]? = []

        public var inventory: Inventory?

        public init(name: String, abbreviation: String, rate: Double = 1, order: Int = 0) {
            self.name = name
            self.abbreviation = abbreviation
            self.rate = rate
            self.order = order
        }
    }

    /// Emplacement de premier niveau : « Sur soi », « Monture », « Bateau ».
    @Model
    public final class InventorySlot {
        public var name: String = ""
        public var icon: String = "figure.stand"
        public var order: Int = 0
        public var countsTowardEncumbrance: Bool = true
        /// Charge maximale de l'emplacement (unité de la Besace).
        public var capacity: Double?

        @Relationship(deleteRule: .cascade, inverse: \InventoryItem.slot)
        public var items: [InventoryItem]? = []

        public var inventory: Inventory?

        public init(name: String, icon: String = "figure.stand", order: Int = 0) {
            self.name = name
            self.icon = icon
            self.order = order
        }
    }

    /// Palier d'encombrement : atteint quand le poids dépasse son seuil.
    @Model
    public final class EncumbranceLevel {
        public var name: String = ""
        public var order: Int = 0
        /// Seuil (formule : `=BESACE.limite*1.5`).
        public var thresholdFormula: String?
        /// Malus du palier (`BESACE.malus`), si la Besace applique les malus.
        public var malus: Double?
        /// Effet en texte libre (« Mouvement −2 »).
        public var effect: String = ""

        public var inventory: Inventory?

        public init(name: String, thresholdFormula: String? = nil, order: Int = 0) {
            self.name = name
            self.thresholdFormula = thresholdFormula
            self.order = order
        }
    }

    // MARK: Journal (V2)

    /// Journal d'un personnage (SPEC §5.14) : sessions, fiches de PNJ / lieux / indices, documents.
    /// Il appartient au personnage, pas à sa fiche : ni la copie d'une fiche ni un template ne l'emportent.
    @Model
    public final class Journal {
        @Relationship(deleteRule: .cascade, inverse: \JournalSession.journal)
        public var sessions: [JournalSession]? = []
        @Relationship(deleteRule: .cascade, inverse: \CodexEntry.journal)
        public var entries: [CodexEntry]? = []
        @Relationship(deleteRule: .cascade, inverse: \JournalDocument.journal)
        public var documents: [JournalDocument]? = []

        public var character: PlayerCharacter?

        public init() {}
    }

    /// Compte rendu d'une session de jeu.
    @Model
    public final class JournalSession {
        /// Numéro de la session (proposé : le plus grand + 1).
        public var number: Int = 0
        /// Date réelle de la partie.
        public var date: Date = Date()
        /// Date dans le monde du jeu, en texte libre (« 3 Thermidor 1792 »).
        public var gameDate: String = ""
        public var title: String = ""
        /// Résumé court, affiché dans la liste.
        public var summary: String = ""
        /// Récit mis en forme : `JournalText` encodé en JSON (paragraphes, styles, références, pièces jointes).
        public var richText: Data?
        /// Le même récit en texte brut : recherche, export lisible, secours si `richText` ne se lit pas.
        public var plainText: String = ""
        /// Gains de la session (expérience, objets, argent), reportés à la main sur la fiche.
        public var gains: String = ""
        public var createdAt: Date = Date()

        /// Fiches (PNJ, lieux…) qui apparaissent dans la session : celles que le récit cite.
        @Relationship(deleteRule: .nullify, inverse: \CodexEntry.sessions)
        public var entries: [CodexEntry]? = []
        /// Documents rattachés ; la session supprimée, ils restent dans le journal.
        @Relationship(deleteRule: .nullify, inverse: \JournalDocument.session)
        public var documents: [JournalDocument]? = []

        public var journal: Journal?

        public init(number: Int, date: Date = Date()) {
            self.number = number
            self.date = date
        }
    }

    /// Fiche courte du journal : PNJ, lieu, indice, faction…
    @Model
    public final class CodexEntry {
        /// Identifiant cité par le récit des sessions.
        public var uid: UUID = UUID()
        public var name: String = ""
        public var kindRaw: String = CodexKind.npc.rawValue
        public var summary: String = ""
        /// État libre : « vivant », « résolu »…
        public var status: String = ""
        @Attribute(.externalStorage)
        public var imageData: Data?
        public var createdAt: Date = Date()

        /// Sessions où la fiche apparaît.
        public var sessions: [JournalSession]? = []
        /// Documents rattachés ; la fiche supprimée, ils restent dans le journal.
        @Relationship(deleteRule: .nullify, inverse: \JournalDocument.entry)
        public var documents: [JournalDocument]? = []

        public var journal: Journal?

        public init(name: String, kind: CodexKind = .npc) {
            self.name = name
            self.kindRaw = kind.rawValue
        }
    }

    /// Document du journal : PDF ou image (aide de jeu, carte, lettre du MJ).
    @Model
    public final class JournalDocument {
        /// Identifiant cité par le récit des sessions (pièce jointe).
        public var uid: UUID = UUID()
        public var title: String = ""
        /// Type de contenu (identifiant UTType : `com.adobe.pdf`, `public.jpeg`, ou croquis et
        /// zone manuscrite de l'app, voir `JournalDocument.Kind`).
        public var contentType: String = ""
        @Attribute(.externalStorage)
        public var data: Data?
        /// Rendu d'un croquis ou d'une zone manuscrite (PNG), pour l'afficher sans le recalculer.
        @Attribute(.externalStorage)
        public var previewData: Data?
        /// Figure dans la liste des documents (un croquis peut ne pas y figurer ; une zone manuscrite n'y figure pas).
        public var isListed: Bool = true
        public var createdAt: Date = Date()

        /// Rattachement optionnel à une session ou à une fiche.
        public var session: JournalSession?
        public var entry: CodexEntry?

        public var journal: Journal?

        public init(title: String, contentType: String) {
            self.title = title
            self.contentType = contentType
        }
    }
}
