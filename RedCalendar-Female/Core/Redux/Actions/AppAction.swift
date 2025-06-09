//
//  AppAction.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

enum AppAction {
    // Auth actions
    case checkAuth
    case authCheckCompleted(deviceId: String?)
    case startMigration
    case migrationCompleted(deviceId: String, userId: String)
    case migrationFailed(Error)
    case login
    case logout
    
    // Push notification actions
    case setAPNSToken(_ token: APNSToken)
    
    // Retry actions
    case retryFailedTasks
}
