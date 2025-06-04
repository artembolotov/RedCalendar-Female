//
//  LoggerMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

let loggerMiddleware: Middleware<AppState, AppAction> = { state, action in
    AppLogger.action(action)
    return []
}
