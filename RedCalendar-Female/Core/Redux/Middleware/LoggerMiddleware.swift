//
//  LoggerMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

let loggerMiddleware: Middleware = { state, action, dispatch in
    AppLogger.action(action)
    return []
}
