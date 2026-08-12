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
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .noUserIdFound:
            return "No user ID found for migration"
        case .keychainSaveError:
            return "Failed to save device ID to keychain"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

let migrationMiddleware: Middleware = { state, action, dispatch in
    @Injected var keychain: KeychainServiceProtocol
    @Injected var apiService: APIServiceProtocol
    
    // Observes the auth domain rather than owning it, so it matches the one case it acts on
    // instead of switching exhaustively — a new `AuthAction` genuinely is none of its business.
    switch action {
    case .auth(.set(let authState)):
        if case .migrating(let userId, let error) = authState, error == nil {
            Task {
                do {
                    let response = try await apiService.migrateUser(userId: userId)
                    
                    guard response.success, let data = response.data else {
                        throw MigrationError.serverError(response.message ?? "Unknown error")
                    }
                    
                    guard keychain.saveDeviceID(data.deviceId) else {
                        throw MigrationError.keychainSaveError
                    }
                    
                    keychain.deleteUserUID()
                    
                    dispatch(.auth(.set(.authenticated(
                        deviceId: data.deviceId,
                        userDetails: nil
                    ))))
                } catch {
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
