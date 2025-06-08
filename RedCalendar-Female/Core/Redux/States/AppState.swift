//
//  AppState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

struct AppState {
    var isCheckingAuth = true
    var userId: String?
    var deviceId: String?
    var isMigrating = false
    var migrationError: String?
    
    // Push notification state
    var pushNotificationState: PushNotificationState = .notRequested
    var apnsToken: String?
    
    // Computed property
    var isAuthenticated: Bool {
        deviceId != nil
    }
    
    // Auth check state
    var authCheckState: AuthCheckState {
        if isCheckingAuth {
            return .checking
        }
        
        if isMigrating || migrationError != nil {
            return .migrating
        }
        
        return deviceId != nil ? .authenticated : .notAuthenticated
    }
}

enum AuthCheckState {
    case checking          // Checking keychain for saved credentials
    case migrating         // Migrating user_id to device_id
    case authenticated     // User authenticated with device_id
    case notAuthenticated  // No credentials found, show login
}

enum PushNotificationState {
    case notRequested      // Haven't requested yet
    case registered        // Successfully registered
    case failed            // Registration failed
    case tokenUpdating     // Sending token to server
    case tokenUpdated      // Token sent to server
}
