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
            AppLogger.action(.authCheckCompleted(userId: deviceId))
            return [.authCheckCompleted(userId: deviceId)]
        }
        
        // Priority 2: Check for legacy user_id (Firebase)
        if let userId = keychain.getUserUID() {
            AppLogger.action(.startMigration)
            return [.startMigration]
        }
        
        // No credentials found
        AppLogger.action(.authCheckCompleted(userId: nil))
        return [.authCheckCompleted(userId: nil)]
        
    case .migrationCompleted(let deviceId, let userId):
        // After successful migration, set the deviceId as the primary auth token
        return [.authCheckCompleted(userId: deviceId)]
        
    case .login:
        // For now, create test user with device_id
        let testDeviceId = "test_device_\(UUID().uuidString.prefix(20))"
        keychain.saveDeviceID(testDeviceId)
        return [.authCheckCompleted(userId: testDeviceId)]
        
    case .logout:
        // Clear all keychain data
        keychain.deleteDeviceID()
        keychain.deleteUserUID()
        return []
        
    default:
        return []
    }
}
