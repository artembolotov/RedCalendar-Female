//
//  AppMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

// MARK: - Database Middleware Instance
let databaseMiddleware = DatabaseMiddleware()

// MARK: - Create App Middleware
func combineAppMiddlewares() -> [Middleware<AppState, AppAction>] {
    return [
        loggerMiddleware,
        authMiddleware,
        migrationMiddleware,
        pushNotificationMiddleware,
        analyticsMiddleware,
        appearanceMiddleware,
        feedbackMiddleware,
        databaseMiddleware.handle
    ]
}
