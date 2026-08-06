//
//  AppState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

// `Sendable` is a checked conformance, not decoration: it is what stops an untyped `Error`
// payload from being reintroduced into the state tree. Every error in here is a concrete enum
// for that reason, and that is also what let the two hand-written `==` implementations —
// which compared errors by `localizedDescription` — be deleted in favour of synthesis.
struct AppState: Equatable, Sendable {
    var authState: AuthState?
    var calendarState: CalendarState = CalendarState()
    var notifications: NotificationState = NotificationState()
    var analyticsActivated: Bool = false
    // Seeded with the fallback rather than the stored value: the store is built before any
    // service is reachable, so `.checkAccentTheme` replaces this on launch.
    var accentTheme: AccentTheme = .fallback
}

extension AppState {
    var isAuthenticated: Bool {
        if case .authenticated = authState { true } else { false }
    }

    var deviceId: String? {
        guard case .authenticated(let id, _) = authState else { return nil }
        return id
    }

    var currentUser: UserDetails? {
        guard case .authenticated(_, let user) = authState else { return nil }
        return user
    }
}
