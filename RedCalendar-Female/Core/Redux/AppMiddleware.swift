//
//  AppMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

// MARK: - Create App Middleware
func combineAppMiddlewares() -> [Middleware] {
    return [
        loggerMiddleware,
        authMiddleware,
        migrationMiddleware,
        pushNotificationMiddleware,
        analyticsMiddleware,
        appearanceMiddleware,
        feedbackMiddleware,
        // The closure stays, but it is no longer the hop onto the main actor — `Middleware` is
        // `@MainActor` now, so there is no hop left to make. It is here because
        // `DatabaseMiddleware.shared.handle` cannot be written directly: a partial method
        // application is not `@Sendable`, and `combineAppMiddlewares()` is nonisolated, so
        // evaluating a main-actor `static let` in it is an error under Swift 6. Inside a
        // `@MainActor` closure literal both are fine, and nothing is captured.
        { state, action, dispatch in
            await DatabaseMiddleware.shared.handle(state: state, action: action, dispatch: dispatch)
        },
        // After the database middleware, and the order is load-bearing in one direction: a local
        // write dispatches its own `.sync(.requested(.localEdit))`, which is queued rather than
        // delivered inline, so it reaches this one on a later turn either way. What the order
        // does buy is that `.auth(.set(.authenticated))` starts the observations before the run
        // that may immediately pause them.
        { state, action, dispatch in
            await SyncMiddleware.shared.handle(state: state, action: action, dispatch: dispatch)
        }
    ]
}
