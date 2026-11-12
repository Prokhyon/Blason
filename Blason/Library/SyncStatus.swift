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

    /// iCloud en pause pendant la mise au point du modèle V2 : la base est locale
    /// (`SheetStore.openLocalStore`). À réactiver avec la base V2 finale.
    static let isEnabled = false

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
        // Synchronisation en pause (SPEC §5.16) : rien à suivre.
        guard Self.isEnabled else { return }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccount() }
        })
        observers.append(center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            // Seuls les événements terminés comptent pour l'avis : réussi l'efface, échoué le pose.
            guard event.endDate != nil else { return }
            let succeeded = event.succeeded
            let problem = succeeded ? nil : event.error.flatMap { SyncProblem(error: $0) }
            MainActor.assumeIsolated {
                guard let self else { return }
                if succeeded { self.syncProblem = nil } else if let problem { self.syncProblem = problem }
            }
        })
        refreshAccount()
    }

    private func refreshAccount() {
        Task {
            let container = CKContainer(identifier: SheetStore.cloudContainerID)
            let status = try? await container.accountStatus()
            accountProblem = status.flatMap { SyncProblem(accountStatus: $0) }
        }
    }
}

/// Avis discret sous les cartes de la bibliothèque, seulement en cas de problème.
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

// MARK: - Base d'essai V2

extension View {
    /// Prévient une fois si la base d'essai V2 a dû être recréée depuis la base V1.
    func storeOpeningNotice(_ opening: StoreOpening) -> some View {
        modifier(StoreOpeningNotice(opening: opening))
    }
}

private struct StoreOpeningNotice: ViewModifier {
    let opening: StoreOpening
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .onAppear { if case .recreated = opening { isPresented = true } }
            .alert("Base d'essai recréée", isPresented: $isPresented) {
                Button("OK") {}
            } message: {
                if case .recreated(let setAside) = opening {
                    Text("Le modèle de l'app a changé et l'ancienne base d'essai ne s'ouvrait plus. Elle est gardée sous le nom « \(setAside) » ; tes fiches ont été recopiées depuis la base d'avant la V2. Réimporte tes exports récents pour retrouver les dernières modifications.")
                }
            }
    }
}
