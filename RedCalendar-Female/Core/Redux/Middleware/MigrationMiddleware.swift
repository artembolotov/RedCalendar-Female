//
//  MigrationMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

// MARK: - Migration Errors
enum MigrationError: Error, LocalizedError, Equatable {
    case noUserIdFound
    case keychainSaveError
    /// The consent version was refused as invalid (SYNC.md §21.3) — a client bug, worded for the
    /// person rather than in the server's terms.
    case consentInvalid
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .noUserIdFound:
            return String(localized: "MigrationError.NoUserIdFound")
        case .keychainSaveError:
            return String(localized: "MigrationError.KeychainSaveError")
        case .consentInvalid:
            return String(localized: "MigrationError.ConsentInvalid")
        case .serverError(let message):
            return message
        }
    }
}

let migrationMiddleware: Middleware = { state, action, dispatch in
    @Injected var keychain: KeychainServiceProtocol
    @Injected var apiService: APIServiceProtocol
    @Injected var dbService: DatabaseServiceProtocol
    
    // Observes the auth domain rather than owning it, so it matches the one case it acts on
    // instead of switching exhaustively — a new `AuthAction` genuinely is none of its business.
    switch action {
    case .auth(.set(let authState)):
        // No version, no request: `RootView` shows the consent step instead, and sends this same
        // state again once it is agreed to (SYNC.md §21.4). The legacy id stays in the keychain
        // all the while, so a launch that ends here comes back to the same step.
        if case .migrating(let userId, let error) = authState, error == nil,
           let consentVersion = state.consent.signInVersion {
            Task {
                do {
                    let response = try await apiService.migrateUser(userId: userId, consentVersion: consentVersion)
                    
                    guard response.success, let data = response.data else {
                        throw MigrationError.serverError(response.message ?? String(localized: "MigrationError.Unknown"))
                    }
                    
                    // The third point of §6's owner check. In practice it claims an unowned
                    // database rather than finding a stranger's — a device arrives here only
                    // with a legacy Firebase id and no `device_id` — but the check belongs on
                    // every path that learns a user_id, and it is here for the same reason as on
                    // the other two: before the new `device_id` is saved, never after.
                    try await dbService.claimOwner(data.userId)

                    guard keychain.saveDeviceID(data.deviceId) else {
                        throw MigrationError.keychainSaveError
                    }
                    
                    keychain.deleteUserUID()
                    
                    dispatch(.auth(.set(.authenticated(deviceId: data.deviceId))))
                } catch {
                    // Both refusals come before anything else is done on the server, so the
                    // migration can simply run again once there is a version it accepts.
                    switch ConsentRefusal(error) {
                    case .outdated(let version):
                        // The state is still `.migrating` with no error, which with no version is
                        // the consent step again.
                        AppLogger.info("Migration: consent version \(consentVersion) is outdated, asking for \(version)")
                        dispatch(.consent(.signInConsentOutdated(version: version, retry: authState)))
                        return
                    case .invalid:
                        // Dropped as well as reported: there is no cancelling a migration, so
                        // the retry has to lead back to the step rather than resend the same
                        // version forever.
                        AppLogger.error("Migration: consent version \(consentVersion) refused as invalid", error: error)
                        dispatch(.consent(.discardSignInConsent))
                        dispatch(.auth(.set(.migrating(userId: userId, error: .consentInvalid))))
                        return
                    case nil:
                        break
                    }

                    AppLogger.error("Migration failed", error: error)
                    // Not `AuthenticationError.from` — its `.unknownError` drops the message it
                    // is handed, and `RootView` renders exactly that description.
                    let migrationError = error as? MigrationError
                        ?? .serverError(error.localizedDescription)
                    dispatch(.auth(.set(.migrating(userId: userId, error: migrationError))))
                }
            }
        }
        
    default:
        break
    }
}
