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
        
    // Push notification actions
    case .pushRegistrationCompleted(let token):
        state.apnsToken = APNSToken(value: token, isSynced: false)
        
    case .pushRegistrationFailed:
        // Just log, no state change needed
        break
        
    case .pushTokenSynced(let success):
        if let token = state.apnsToken {
            state.apnsToken = APNSToken(value: token.value, isSynced: success)
        }
        break
        
    case .syncPushToken:
       // No state change, handled by middleware
       break
        
    case .retryFailedTasks:
        // No state changes needed - middleware will handle retry logic
        break
    }
    
    return state
}
