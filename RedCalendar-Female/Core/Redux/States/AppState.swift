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
    
    // Computed property
    var isAuthenticated: Bool {
        userId != nil
    }
    
    // Auth check state
    var authCheckState: AuthCheckState {
        switch (isInitialized, userId) {
        case (false, _):
            return .checking
        case (true, .some):
            return .authenticated
        case (true, .none):
            return .notAuthenticated
        }
    }
}

enum AuthCheckState {
    case checking          // Checking keychain for saved user
    case authenticated     // User found, proceed to main app
    case notAuthenticated  // No user found, show login
}

// Type alias for convenience
typealias AppStore = Store<AppState, AppAction>
