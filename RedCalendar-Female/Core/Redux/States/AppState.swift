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
    // The one `user_profile` row (SYNC.md §3.1), observed independently of `authState` — it is
    // sync's to fill, not login's (see `.data(.setUserProfile)`), so this stays `nil` until the
    // first successful run lands (§5.1 step 7).
    var userProfile: UserDetails?
    /// What the sync run is doing, for the indicator of §12 item 12. Nothing else reads it: the
    /// run's real state — cursor, owner, dirty flags — is on the disk, where it survives a launch.
    var syncState: SyncState = .idle
}

extension AppState {
    var isAuthenticated: Bool {
        if case .authenticated = authState { true } else { false }
    }

    var deviceId: String? {
        guard case .authenticated(let id) = authState else { return nil }
        return id
    }

    var currentUser: UserDetails? { userProfile }
}
