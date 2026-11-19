import SwiftUI
import SheetKit

/// Carte d'une section : titre, puis champs ou tableau.
struct SectionCard: View {
    let section: SheetSection

    @Environment(\.sheetMode) private var mode
    @Environment(\.structureEditor) private var editor
    @Environment(\.sheetTheme) private var theme

    var body: some View {
        theme.sectionFrame(SectionFrameConfiguration(
            title: title, titleText: section.title.isEmpty ? nil : section.title, content: AnyView(content)))
            .structureItem(.section(section))
    }

    /// Titre mis en forme par le thème ; le cadre du thème décide où le poser.
    private var title: AnyView? {
        if mode == .structure && section.title.isEmpty {
            return AnyView(Text("Section sans titre")
                .font(theme.sectionTitleFont)
                .foregroundStyle(.tertiary))
        }
        guard !section.title.isEmpty else { return nil }
        return AnyView(Text(section.title)
            .font(theme.sectionTitleFont)
            .textCase(theme.sectionTitleCase)
            .tracking(theme.sectionTitleTracking)
            .sheetHeading(theme)
            .accessibilityAddTraits(.isHeader))
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch section.kind {
            case .fields:
                FieldsSectionView(section: section)
            case .table:
                TableSectionView(section: section)
            case .inventory:
                InventorySectionView(section: section)
            case .inventoryView:
                InventoryViewSection(section: section)
            }
            if mode == .structure, let editor, section.kind == .fields || section.kind == .table {
                addBar(editor)
            }
        }
    }

    /// Ajouts en bas de section : champ (par type) ou colonne / groupe, et « Coller une liste ».
    @ViewBuilder
    private func addBar(_ editor: StructureEditor) -> some View {
        AddButtonsBar {
            switch section.kind {
            case .fields:
                Menu {
                    ForEach(FieldKind.allCases, id: \.self) { kind in
                        Button {
                            editor.addField(kind, to: section)
                        } label: {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                    }
                } label: {
                    AddButtonLabel(title: "Champ")
                }
            case .table:
                Menu {
                    ForEach(ColumnKind.allCases, id: \.self) { kind in
                        Button {
                            editor.addColumn(kind, to: section)
                        } label: {
                            Label(kind.title, systemImage: kind.symbol)
                        }
                    }
                } label: {
                    AddButtonLabel(title: "Colonne")
                }
                Button {
                    editor.addGroup(to: section)
                } label: {
                    AddButtonLabel(title: "Groupe")
                }
            case .inventory, .inventoryView:
                EmptyView()
            }
            Button {
                editor.requestPasteList(into: section)
            } label: {
                AddButtonLabel(title: "Coller une liste", systemImage: "list.clipboard")
            }
        }
        .padding(.top, 4)
    }
}
