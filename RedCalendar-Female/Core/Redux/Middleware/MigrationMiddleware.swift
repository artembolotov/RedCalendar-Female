//
//  MigrationMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

let migrationMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
    @Injected var keychain: KeychainServiceProtocol
    @Injected var apiService: APIServiceProtocol
    
    switch action {
    case .setAuthState(let authState):
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
                    
                    dispatch(.setAuthState(.authenticated(
                        deviceId: data.deviceId,
                        userDetails: nil
                    )))
                } catch {
                    AppLogger.error("Migration failed", error: error)
                    dispatch(.setAuthState(
                        .migrating(userId: userId, error: MigrationError.from(error))
                    ))
                }
            }
        }
        return []
        
    default:
        return []
    }
}
