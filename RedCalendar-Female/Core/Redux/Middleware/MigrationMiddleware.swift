//
//  MigrationMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

// MARK: - Migration Errors
enum MigrationError: Error, LocalizedError {
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

let migrationMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
    @Injected var keychain: KeychainServiceProtocol
    @Injected var apiService: APIServiceProtocol
    
    switch action {
    case .setAuthState(let authState):
        if case AuthState.migrating(let userId, let error) = authState, error == nil {
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
                    
                    dispatch(.setAuthState(.authenticated(deviceId: data.deviceId, userDetails: nil)))
                } catch {
                    AppLogger.error("Migration failed", error: error)
                    dispatch(.setAuthState(.migrating(userId: userId, error: error)))
                }
            }
        }
        return []
        
    default:
        return []
    }
}
