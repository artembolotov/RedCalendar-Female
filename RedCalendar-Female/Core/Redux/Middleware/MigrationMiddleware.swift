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
    case .startMigration:
        // Get legacy user_id from keychain
        guard let userId = keychain.getUserUID() else {
            AppLogger.error("Migration started but no user_id found in keychain")
            return [.migrationFailed(MigrationError.noUserIdFound)]
        }
        
        // Perform async migration
        Task {
            do {
                let response = try await apiService.migrateUser(userId: userId)
                
                guard response.success,
                      let data = response.data else {
                    throw MigrationError.serverError(response.message ?? "Unknown error")
                }
                
                // Save device_id to keychain
                guard keychain.saveDeviceID(data.deviceId) else {
                    throw MigrationError.keychainSaveError
                }
                
                // Remove old user_id from keychain
                keychain.deleteUserUID()
                
                // Dispatch success action
                dispatch(.migrationCompleted(deviceId: data.deviceId, userId: data.userId))
                
            } catch {
                AppLogger.error("Migration failed", error: error)
                
                // Dispatch error action
                dispatch(.migrationFailed(error))
            }
        }
        
        return []
        
    default:
        return []
    }
}
