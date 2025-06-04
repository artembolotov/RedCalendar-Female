//
//  AppMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

let authMiddleware: Middleware<AppState, AppAction> = { state, action in
    @Injected var keychain: KeychainServiceProtocol
    
    switch action {
    case .checkAuth:
        // Check if user UID exists in keychain
        let userId = keychain.getUserUID()
        return [.authCheckCompleted(userId: userId)]
        
    case .login:
        // For now, create test user
        let testUserId = UUID().uuidString
        keychain.saveUserUID(testUserId)
        return [.authCheckCompleted(userId: testUserId)]
        
    case .logout:
        // Clear keychain
        keychain.deleteUserUID()
        // State already updated in reducer
        return []
        
    default:
        return []
    }
}
