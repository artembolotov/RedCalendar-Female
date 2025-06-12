//
//  AppReducer.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import UIKit

func appReducer(state: AppState, action: AppAction) -> AppState {
    var state = state
    
    switch action {
        
    case .checkAuthState:
        break
        
    case .setAuthState(let authState):
        state.authState = authState
        if case .authenticating(nil) = authState {
            state.apnsToken = nil
        }
        
    case .setAPNSToken(let token):
        state.apnsToken = token
        
    case .setPushPermissionState(let permissionState):
        state.pushPermissionState = permissionState
        
    case .retryFailedTasks:
        break
        
    case .logout:
        break
    }
    
    return state
}
