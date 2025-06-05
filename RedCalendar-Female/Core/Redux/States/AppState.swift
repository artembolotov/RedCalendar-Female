//
//  AppState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

struct AppState {
    var isInitialized = false
    var userId: String?
    var deviceId: String?
    var isMigrating = false
    var migrationError: String?
    
    // Computed property
    var isAuthenticated: Bool {
        deviceId != nil
    }
    
    // Auth check state
    var authCheckState: AuthCheckState {
        switch (isInitialized, isMigrating, deviceId) {
        case (false, _, _):
            return .checking
        case (true, true, _):
            return .migrating
        case (true, false, .some):
            return .authenticated
        case (true, false, .none):
            return .notAuthenticated
        }
    }
}

enum AuthCheckState {
    case checking          // Checking keychain for saved credentials
    case migrating         // Migrating user_id to device_id
    case authenticated     // User authenticated with device_id
    case notAuthenticated  // No credentials found, show login
}
