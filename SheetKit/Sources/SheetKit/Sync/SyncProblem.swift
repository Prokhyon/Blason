import CloudKit
import Foundation

/// Problème de synchronisation iCloud à signaler dans la bibliothèque (SPEC §5.10).
/// Tout le reste (synchronisation en cours, hors ligne, réussie) ne s'affiche pas.
public enum SyncProblem: Equatable, Sendable {
    /// Pas de compte iCloud sur l'appareil, ou iCloud coupé pour l'app.
    case noAccount
    /// iCloud bloqué (contrôle parental, profil de gestion).
    case restricted
    /// Compte à revalider (mot de passe à saisir dans Réglages…).
    case temporarilyUnavailable
    /// Stockage iCloud plein : les modifications ne partent plus.
    case quotaExceeded
    /// Autre échec, avec la description du système.
    case failed(String)

    /// Problème d'après l'état du compte ; nil si le compte est disponible ou l'état inconnu.
    public init?(accountStatus: CKAccountStatus) {
        switch accountStatus {
        case .noAccount: self = .noAccount
        case .restricted: self = .restricted
        case .temporarilyUnavailable: self = .temporarilyUnavailable
        default: return nil
        }
    }

    /// Problème d'après l'erreur d'une synchronisation ; nil pour une erreur passagère
    /// (réseau, service occupé, opération annulée) qui se résout seule.
    public init?(error: Error) {
        // Core Data refuse de démarrer la synchronisation sans compte (constaté sur simulateur).
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == Self.noAccountCoreDataCode {
            self = .noAccount
            return
        }
        guard let error = error as? CKError else {
            self = .failed(error.localizedDescription)
            return
        }
        // Une erreur partielle regroupe les erreurs de chaque enregistrement : la plus parlante l'emporte.
        if error.code == .partialFailure, let errors = error.partialErrorsByItemID?.values {
            let problems = errors.compactMap { SyncProblem(error: $0) }
            guard let first = problems.first else { return nil }
            self = problems.first { $0 == .quotaExceeded } ?? first
            return
        }
        switch error.code {
        case .quotaExceeded: self = .quotaExceeded
        case .notAuthenticated: self = .noAccount
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited,
             .zoneBusy, .operationCancelled, .serverRecordChanged, .changeTokenExpired:
            return nil
        default: self = .failed(error.localizedDescription)
        }
    }

    /// « Unable to initialize without an iCloud account » (NSCloudKitMirroringDelegate).
    static let noAccountCoreDataCode = 134400

    /// Le joueur peut masquer l'avis : il a choisi de ne pas utiliser iCloud.
    /// Les échecs, eux, restent affichés jusqu'à la prochaine synchronisation réussie.
    public var isDismissible: Bool {
        switch self {
        case .noAccount, .restricted: true
        default: false
        }
    }
}
