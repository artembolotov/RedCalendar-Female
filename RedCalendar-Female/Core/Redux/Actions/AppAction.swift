//
//  AppAction.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

enum AppAction {
    case checkAuth
    case authCheckCompleted(userId: String?)
    case startMigration
    case migrationCompleted(deviceId: String, userId: String)
    case migrationFailed(Error)
    case login
    case logout
}
