//
//  AppMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

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
        // `Middleware` is an unisolated type and DatabaseMiddleware lives on the main actor,
        // because it owns the GRDB observation tokens. This `await` is the hop onto it, and it is
        // also what serialises actions the store otherwise sends each in its own `Task`.
        { state, action, dispatch in
            await DatabaseMiddleware.shared.handle(state: state, action: action, dispatch: dispatch)
        }
    ]
}
