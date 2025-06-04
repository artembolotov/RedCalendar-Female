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
        
    case .authCheckCompleted(let userId):
        state.isInitialized = true
        state.userId = userId
        
    case .login:
        // Trigger middleware
        break
        
    case .logout:
        state.userId = nil
    }
    
    return state
}
