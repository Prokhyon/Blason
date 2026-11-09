import Foundation
import SwiftData

// Modèle de données v1.
//
// Règles (voir SPEC.md §7) :
// - Un personnage possède sa propre copie de la structure (`Sheet`) : les valeurs vivent
//   directement dans les champs et les cellules. Dans un template, elles servent de défaut.
// - Compatible CloudKit : tous les attributs ont une valeur par défaut, toutes les relations
//   sont optionnelles et ont un inverse, aucune contrainte `unique`.
// - Les enfants sont supprimés en cascade : supprimer un parent ne laisse aucun orphelin.
// - Les tableaux de relations ne sont pas ordonnés : utiliser `order` (accesseurs `sorted…`).

public enum SheetSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            SheetTemplate.self, PlayerCharacter.self, Sheet.self, Page.self, SheetRow.self,
            SheetSection.self, SheetField.self, SheetTableColumn.self, SheetTableGroup.self,
            SheetTableRow.self, SheetTableCell.self,
        ]
    }
}

public typealias SheetTemplate = SheetSchemaV1.SheetTemplate
public typealias PlayerCharacter = SheetSchemaV1.PlayerCharacter
public typealias Sheet = SheetSchemaV1.Sheet
public typealias Page = SheetSchemaV1.Page
public typealias SheetRow = SheetSchemaV1.SheetRow
public typealias SheetSection = SheetSchemaV1.SheetSection
public typealias SheetField = SheetSchemaV1.SheetField
public typealias SheetTableColumn = SheetSchemaV1.SheetTableColumn
public typealias SheetTableGroup = SheetSchemaV1.SheetTableGroup
public typealias SheetTableRow = SheetSchemaV1.SheetTableRow
public typealias SheetTableCell = SheetSchemaV1.SheetTableCell

extension SheetSchemaV1 {

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
        /// Liste d'appartenance quand la section est en disposition `columns`.
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
}
