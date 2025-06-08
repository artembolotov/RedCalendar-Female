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
        
    case .pushTokenUpdating:
        state.pushNotificationState = .tokenUpdating
        
    case .pushTokenUpdated(let success):
        if success {
            AppLogger.info("Push token updated successfully - setting state to .tokenUpdated")
            state.pushNotificationState = .tokenUpdated
        } else {
            AppLogger.info("Push token update failed - setting state to .registered for retry")
            state.pushNotificationState = .registered
        }
        
    case .retryFailedTasks:
        // No state changes needed - middleware will handle retry logic
        break
    }
    
    return state
}
