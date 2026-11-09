import SwiftUI
import SwiftData
import SheetKit

/// Vue provisoire (M1) : affiche le contenu d'une fiche sous forme de plan,
/// en lecture seule. Le vrai rendu de la fiche arrive au jalon M2.
struct SheetOutlineView: View {
    let title: String
    let sheet: Sheet?

    var body: some View {
        List {
            ForEach(sheet?.sortedPages ?? []) { page in
                Section(page.title) {
                    ForEach(page.sortedRows.flatMap(\.sortedSections)) { section in
                        DisclosureGroup {
                            switch section.kind {
                            case .fields: fields(of: section)
                            case .table: table(of: section)
                            }
                        } label: {
                            Text(section.title).font(.headline)
                        }
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fields(of section: SheetSection) -> some View {
        ForEach(section.sortedFields) { field in
            LabeledContent {
                Text(field.displayValue)
                    .foregroundStyle(field.kind == .formula ? .secondary : .primary)
            } label: {
                Text(field.label)
                if !field.code.isEmpty {
                    Text(field.code).font(.caption.monospaced())
                }
            }
        }
    }

    private func table(of section: SheetSection) -> some View {
        let columns = section.sortedColumns
        return ForEach(section.sortedGroups) { group in
            if !group.title.isEmpty {
                Text(group.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(group.sortedRows) { row in
                LabeledContent {
                    Text(columns.map { row.cell(for: $0)?.displayValue ?? "" }.joined(separator: "  ·  "))
                        .monospacedDigit()
                } label: {
                    Text(row.displayLabel)
                    if !row.isFromTemplate {
                        Text("ajoutée par le joueur").font(.caption)
                    }
                }
            }
        }
    }
}
