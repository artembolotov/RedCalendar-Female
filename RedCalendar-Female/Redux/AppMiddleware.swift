//
//  AppMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

let authMiddleware: Middleware<AppState, AppAction> = { state, action in
    switch action {
    case .checkAuth:
        // Check if user UID exists in keychain
        let userId = KeychainHelper.getUserUID()
        return .authCheckCompleted(userId: userId)
        
    case .login:
        // For now, create test user
        let testUserId = UUID().uuidString
        KeychainHelper.saveUserUID(testUserId)
        return .authCheckCompleted(userId: testUserId)
        
    case .logout:
        // Clear keychain
        KeychainHelper.deleteUserUID()
        // State already updated in reducer
        return nil
        
    default:
        return nil
    }
}
