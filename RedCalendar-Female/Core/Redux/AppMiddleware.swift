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
        // The one middleware that is a type rather than a closure, because it owns the GRDB
        // observation tokens and has to keep them somewhere isolated. The adapter exists only to
        // match the typealias; it used to be the actor hop as well, back when `Middleware` was
        // unisolated and this `await` was what got the call onto the main actor.
        { state, action, dispatch in
            await DatabaseMiddleware.shared.handle(state: state, action: action, dispatch: dispatch)
        }
    ]
}
