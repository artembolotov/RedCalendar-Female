//
//  AppAction.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

enum AppAction {
    // Auth actions
    case setAuthState(_ state: AuthState?)
    
    // Push notification actions
    case setAPNSToken(_ token: APNSToken)
    case setPushPermissionState(_ state: PushPermissionState?)
    
    // Retry actions
    case retryFailedTasks
}
