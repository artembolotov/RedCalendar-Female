//
//  AppState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

/// `Sendable` is declared here rather than left to inference, and it is declared on the *root*
/// deliberately: it makes the compiler check the whole tree beneath it — `CalendarState`, the GRDB
/// records, `Daystamp`, `DayDisplayState` — without those leaves needing an annotation each. A
/// value that stops being sendable anywhere in the graph fails here, at the one type that actually
/// crosses an isolation boundary.
///
/// `nonisolated` is what keeps that check honest. The module is main-actor by default, and a
/// main-actor-isolated type is *implicitly* `Sendable` no matter what it holds — so leaving the
/// default here would satisfy the conformance above by isolation alone and stop looking at the
/// tree. State is a value; it belongs to no actor. The store, the reducer and the middleware are
/// the main-actor half.
nonisolated struct AppState: Equatable, Sendable {
    var authState: AuthState?
    var calendarState: CalendarState = CalendarState()
    var notifications: NotificationState = NotificationState()
    var analyticsActivated: Bool = false
    // Seeded with the fallback rather than the stored value: the store is built before any
    // service is reachable, so `.checkAccentTheme` replaces this on launch.
    var accentTheme: AccentTheme = .fallback
}

nonisolated extension AppState {
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
