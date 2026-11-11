import SwiftUI
import CloudKit
import CoreData
import SheetKit

/// Suit l'état de la synchronisation iCloud pour n'en signaler que les problèmes (SPEC §5.10) :
/// compte absent ou indisponible, stockage plein, échec. La synchronisation elle-même est faite
/// par SwiftData (base privée iCloud de l'utilisateur).
@MainActor @Observable
final class SyncMonitor {
    private(set) var accountProblem: SyncProblem?
    private(set) var syncProblem: SyncProblem?

    /// Problème à afficher : celui du compte d'abord (il explique les échecs qui suivent).
    var problem: SyncProblem? { accountProblem ?? syncProblem }

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init() {
        #if DEBUG
        // Captures : -demoSyncProblem noAccount | quota | failed.
        switch UserDefaults.standard.string(forKey: "demoSyncProblem") {
        case "noAccount": accountProblem = .noAccount; return
        case "quota": syncProblem = .quotaExceeded; return
        case "failed": syncProblem = .failed("Le serveur iCloud a refusé la demande."); return
        default: break
        }
        #endif
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccount() }
        })
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            let record = SyncEventRecord(event)
            // Seuls les événements terminés comptent pour l'avis : réussi l'efface, échoué le pose.
            let problem = event.succeeded ? nil : event.error.flatMap { SyncProblem(error: $0) }
            MainActor.assumeIsolated {
                guard let self else { return }
                #if DEBUG
                self.record(record)
                #endif
                guard record.end != nil else { return }
                if record.succeeded { self.syncProblem = nil } else if let problem { self.syncProblem = problem }
            }
        })
        refreshAccount()
    }

    private func refreshAccount() {
        Task {
            let container = CKContainer(identifier: SheetStore.cloudContainerID)
            let status = try? await container.accountStatus()
            accountProblem = status.flatMap { SyncProblem(accountStatus: $0) }
            #if DEBUG
            accountStatus = status
            userID = try? await container.userRecordID().recordName
            #endif
        }
    }

    #if DEBUG
    // MARK: Diagnostic (temporaire, builds de développement seulement)

    private(set) var accountStatus: CKAccountStatus?
    /// Identifiant de l'utilisateur dans le conteneur : le même sur deux appareils du même compte.
    private(set) var userID: String?
    /// Derniers événements de synchronisation, du plus récent au plus ancien.
    private(set) var events: [SyncEventRecord] = []

    private func record(_ record: SyncEventRecord) {
        if let index = events.firstIndex(where: { $0.id == record.id }) {
            events[index] = record
        } else {
            events.insert(record, at: 0)
            if events.count > 30 { events.removeLast() }
        }
    }
    #endif
}

/// Événement de synchronisation (configuration, import, export), réduit à ce qui s'affiche.
struct SyncEventRecord: Identifiable, Sendable {
    let id: UUID
    let kind: String
    let start: Date
    let end: Date?
    let succeeded: Bool
    let error: String?

    nonisolated init(_ event: NSPersistentCloudKitContainer.Event) {
        id = event.identifier
        switch event.type {
        case .setup: kind = "Configuration"
        case .import: kind = "Import"
        case .export: kind = "Export"
        @unknown default: kind = "Autre"
        }
        start = event.startDate
        end = event.endDate
        succeeded = event.succeeded
        error = event.error.map { error in
            let nsError = error as NSError
            return "\(nsError.domain) \(nsError.code) : \(nsError.localizedDescription)"
        }
    }
}

/// Avis discret en bas de la barre latérale de la bibliothèque, seulement en cas de problème.
struct SyncNotice: View {
    let problem: SyncProblem

    /// Avis de compte masqué par le joueur (il n'utilise pas iCloud) ; réapparaît si le problème change.
    @AppStorage("syncNoticeDismissed") private var dismissed = ""

    var body: some View {
        if !(problem.isDismissible && dismissed == key) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .foregroundStyle(problem.isDismissible ? Color.secondary : Color.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if problem.isDismissible {
                    Button("Masquer", systemImage: "xmark") { dismissed = key }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: 560)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
            .padding(.horizontal)
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)
        }
    }

    private var key: String {
        switch problem {
        case .noAccount: "noAccount"
        case .restricted: "restricted"
        default: ""
        }
    }

    private var symbol: String {
        switch problem {
        case .quotaExceeded: "exclamationmark.icloud"
        case .failed: "exclamationmark.icloud"
        default: "icloud.slash"
        }
    }

    private var title: LocalizedStringKey {
        switch problem {
        case .noAccount: "iCloud désactivé"
        case .restricted: "iCloud bloqué"
        case .temporarilyUnavailable: "iCloud à reconnecter"
        case .quotaExceeded: "Stockage iCloud plein"
        case .failed: "Synchronisation impossible"
        }
    }

    private var message: String {
        switch problem {
        case .noAccount:
            String(localized: "Tes fiches restent sur cet appareil. Pour les retrouver sur tes autres appareils, active iCloud pour Blason dans Réglages.")
        case .restricted:
            String(localized: "iCloud est bloqué sur cet appareil (contrôle parental ou gestion). Tes fiches restent ici.")
        case .temporarilyUnavailable:
            String(localized: "Ouvre Réglages pour revalider ton compte Apple. La synchronisation reprendra ensuite.")
        case .quotaExceeded:
            String(localized: "Tes modifications restent sur cet appareil et partiront quand il y aura de la place.")
        case .failed(let description):
            String(localized: "Tes modifications restent sur cet appareil. \(description)")
        }
    }
}

#Preview {
    VStack {
        SyncNotice(problem: .noAccount)
        SyncNotice(problem: .quotaExceeded)
    }
}
