//
//  AppMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

// MARK: - Create App Middleware
func createAppMiddleware() -> [Middleware<AppState, AppAction>] {
    return [
        loggerMiddleware,
        authMiddleware,
        analyticsMiddleware
    ]
}
