//
//  AppReducer.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

func appReducer(state: AppState, action: AppAction) -> AppState {
    var state = state
    
    switch action {
    case .checkAuth:
        state.isCheckingAuth = true
        
    case .authCheckCompleted(let deviceId):
        state.isCheckingAuth = false
        state.deviceId = deviceId
        
    case .startMigration:
        state.isCheckingAuth = false
        state.isMigrating = true
        state.migrationError = nil
        
    case .migrationCompleted(let deviceId, let userId):
        state.isMigrating = false
        state.deviceId = deviceId
        state.userId = userId
        state.migrationError = nil
        
    case .migrationFailed(let error):
        state.isMigrating = false
        state.migrationError = error.localizedDescription
        
    case .login:
        // Trigger middleware
        break
        
    case .logout:
        state.userId = nil
        state.deviceId = nil
        state.migrationError = nil
        state.apnsToken = nil
        state.pushNotificationState = .notRequested
        
    // Push notification actions
    case .pushRegistrationCompleted(let token):
        state.pushNotificationState = .registered
        state.apnsToken = token
        
    case .pushRegistrationFailed:
        state.pushNotificationState = .failed
        
    case .pushTokenUpdated(let success):
        if success {
            state.pushNotificationState = .tokenUpdated
        } else {
            // Keep current state but could add error handling
            break
        }
    }
    
    return state
}
