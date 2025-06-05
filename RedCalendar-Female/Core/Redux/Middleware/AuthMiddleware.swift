//
//  AuthMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

let authMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
    @Injected var keychain: KeychainServiceProtocol
    
    switch action {
    case .checkAuth:
        // Priority 1: Check for device_id (new system)
        if let deviceId = keychain.getDeviceID() {
            // TODO: Verify device_id with server
            return [.authCheckCompleted(deviceId: deviceId)]
        }
        
        // Priority 2: Check for legacy user_id (Firebase)
        if let userId = keychain.getUserUID() {
            return [.startMigration]
        }
        
        // No credentials found
        return [.authCheckCompleted(deviceId: nil)]
        
    case .migrationCompleted(let deviceId, let userId):
        // After successful migration, authenticate with the new deviceId
        Task { @MainActor in
            dispatch(.authCheckCompleted(deviceId: deviceId))
        }
        return []
        
    case .login:
        // For now, create test user with device_id
        let testDeviceId = "test_device_\(UUID().uuidString.prefix(20))"
        keychain.saveDeviceID(testDeviceId)
        return [.authCheckCompleted(deviceId: testDeviceId)]
        
    case .logout:
        // Clear all keychain data
        keychain.deleteDeviceID()
        keychain.deleteUserUID()
        return []
        
    default:
        return []
    }
}
