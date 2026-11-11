import CloudKit
import Testing
@testable import SheetKit

@Suite("Problèmes de synchronisation iCloud")
struct SyncProblemTests {

    @Test("État du compte : seuls les comptes indisponibles sont signalés")
    func accountStatus() {
        #expect(SyncProblem(accountStatus: .available) == nil)
        #expect(SyncProblem(accountStatus: .couldNotDetermine) == nil)
        #expect(SyncProblem(accountStatus: .noAccount) == .noAccount)
        #expect(SyncProblem(accountStatus: .restricted) == .restricted)
        #expect(SyncProblem(accountStatus: .temporarilyUnavailable) == .temporarilyUnavailable)
    }

    @Test("Les erreurs passagères (réseau, service occupé) ne s'affichent pas")
    func transientErrors() {
        for code in [CKError.Code.networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy] {
            #expect(SyncProblem(error: CKError(code)) == nil)
        }
    }

    @Test("Stockage plein et compte déconnecté sont reconnus")
    func knownErrors() {
        #expect(SyncProblem(error: CKError(.quotaExceeded)) == .quotaExceeded)
        #expect(SyncProblem(error: CKError(.notAuthenticated)) == .noAccount)
        #expect(SyncProblem(error: NSError(domain: NSCocoaErrorDomain, code: 134400)) == .noAccount)
        if case .failed? = SyncProblem(error: CKError(.permissionFailure)) {} else {
            Issue.record("Une autre erreur CloudKit doit être signalée comme échec")
        }
    }

    @Test("Erreur partielle : le stockage plein l'emporte, les erreurs passagères sont ignorées")
    func partialFailure() {
        let full = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [
            "a": CKError(.networkFailure), "b": CKError(.quotaExceeded),
        ]])
        #expect(SyncProblem(error: full) == .quotaExceeded)
        let transient = CKError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [
            "a": CKError(.networkFailure),
        ]])
        #expect(SyncProblem(error: transient) == nil)
    }

    @Test("Seuls les avis de compte se masquent")
    func dismissible() {
        #expect(SyncProblem.noAccount.isDismissible)
        #expect(!SyncProblem.quotaExceeded.isDismissible)
        #expect(!SyncProblem.failed("x").isDismissible)
    }
}
