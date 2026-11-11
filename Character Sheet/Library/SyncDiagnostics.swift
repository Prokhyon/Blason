#if DEBUG
import SwiftUI
import SwiftData
import CloudKit
import SheetKit

// Indicateur iCloud TEMPORAIRE, pour mettre au point la synchronisation (builds de développement
// seulement). À retirer une fois la synchronisation éprouvée : seul l'avis de problème restera.

/// Bouton de la barre de la bibliothèque : l'icône résume l'état, le toucher ouvre le diagnostic.
struct SyncDiagnosticsButton: View {
    @Environment(SyncMonitor.self) private var monitor
    @State private var isShowing = false

    var body: some View {
        Button("iCloud", systemImage: symbol) { isShowing = true }
            .foregroundStyle(color)
            .popover(isPresented: $isShowing) {
                SyncDiagnosticsView()
                    .frame(minWidth: 420, minHeight: 720)
            }
            // Captures : -demoSyncDiagnostics YES ouvre le diagnostic.
            .task {
                guard UserDefaults.standard.bool(forKey: "demoSyncDiagnostics") else { return }
                try? await Task.sleep(for: .seconds(1))
                isShowing = true
            }
    }

    private var lastFinished: SyncEventRecord? { monitor.events.first { $0.end != nil } }
    private var isRunning: Bool { monitor.events.contains { $0.end == nil } }

    private var symbol: String {
        if monitor.accountProblem != nil { return "icloud.slash" }
        if isRunning { return "arrow.triangle.2.circlepath.icloud" }
        guard let lastFinished else { return "icloud" }
        return lastFinished.succeeded ? "checkmark.icloud" : "exclamationmark.icloud"
    }

    private var color: Color {
        if monitor.accountProblem != nil { return .secondary }
        if let lastFinished, !lastFinished.succeeded, !isRunning { return .orange }
        return .accentColor
    }
}

/// Diagnostic : compte, conteneur, base locale et derniers événements ; « Copier le rapport ».
struct SyncDiagnosticsView: View {
    @Environment(SyncMonitor.self) private var monitor
    @Environment(\.modelContext) private var context
    @State private var copied = false

    var body: some View {
        NavigationStack {
            List {
                Section("Compte") {
                    LabeledContent("État", value: accountText)
                    LabeledContent("Utilisateur", value: shortUserID)
                }
                Section {
                    LabeledContent("Conteneur", value: SheetStore.cloudContainerID)
                    LabeledContent("Environnement", value: "Développement")
                    LabeledContent("App", value: appText)
                    LabeledContent("Base locale", value: localText)
                } footer: {
                    Text("Deux appareils synchronisés doivent montrer le même utilisateur. Un build Xcode utilise l'environnement de développement ; TestFlight et l'App Store, la production.")
                }
                Section("Événements (du plus récent)") {
                    if monitor.events.isEmpty {
                        Text("Aucun depuis le lancement").foregroundStyle(.secondary)
                    }
                    ForEach(monitor.events) { event in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(event.kind).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(stateText(event)).font(.subheadline)
                                    .foregroundStyle(event.end == nil ? Color.secondary : event.succeeded ? Color.green : Color.orange)
                            }
                            Text(event.start, format: .dateTime.hour().minute().second())
                                .font(.caption).foregroundStyle(.secondary)
                            if let error = event.error {
                                Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .navigationTitle("iCloud (diagnostic)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button(copied ? "Copié" : "Copier le rapport", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    UIPasteboard.general.string = report
                    copied = true
                }
            }
        }
    }

    private var accountText: String {
        switch monitor.accountStatus {
        case .available?: "Disponible"
        case .noAccount?: "Aucun compte"
        case .restricted?: "Bloqué"
        case .temporarilyUnavailable?: "À revalider"
        case .couldNotDetermine?: "Indéterminé"
        case nil: "Recherche…"
        @unknown default: "Inconnu"
        }
    }

    /// Fin de l'identifiant : assez pour comparer deux appareils.
    private var shortUserID: String {
        guard let id = monitor.userID else { return "—" }
        return "…" + id.suffix(8)
    }

    private var appText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(Bundle.main.bundleIdentifier ?? "?") \(version) (\(build))"
    }

    private var localText: String {
        let templates = (try? context.fetchCount(FetchDescriptor<SheetTemplate>())) ?? 0
        let characters = (try? context.fetchCount(FetchDescriptor<PlayerCharacter>())) ?? 0
        return "\(templates) templates, \(characters) personnages"
    }

    private func stateText(_ event: SyncEventRecord) -> String {
        guard let end = event.end else { return "en cours" }
        let duration = end.timeIntervalSince(event.start).formatted(.number.precision(.fractionLength(1)))
        return event.succeeded ? "réussi (\(duration) s)" : "échec"
    }

    private var report: String {
        var lines = [
            "Blason — diagnostic iCloud, \(Date.now.formatted(date: .abbreviated, time: .standard))",
            "Appareil : \(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)",
            "Compte : \(accountText), utilisateur \(shortUserID)",
            "Conteneur : \(SheetStore.cloudContainerID) (développement)",
            "App : \(appText)",
            "Base locale : \(localText)",
            "Événements :",
        ]
        for event in monitor.events {
            var line = "- \(event.start.formatted(.dateTime.hour().minute().second())) \(event.kind) : \(stateText(event))"
            if let error = event.error { line += " — \(error)" }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }
}
#endif
