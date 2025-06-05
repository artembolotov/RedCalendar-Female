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
        // Just trigger middleware
        break
        
    case .authCheckCompleted(let deviceId):
        state.isInitialized = true
        state.deviceId = deviceId
        
    case .startMigration:
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
    }
    
    return state
}
