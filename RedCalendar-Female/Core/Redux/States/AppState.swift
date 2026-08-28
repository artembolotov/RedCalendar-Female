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
    // The identity half of the one `user_profile` row (SYNC.md §3.1), observed independently of
    // `authState`. It stays `nil` until the row carries a `user_id`, which is the server's to
    // write: a sync run puts it there (§5.1 step 7), and a row created locally by a settings edit
    // carries whatever `sync_state` already knows — nothing at all before the first sign-in.
    var userProfile: UserDetails?
    /// What the app actually predicts with: the `user_profile` row's cycle settings, resolved.
    ///
    /// Beside `userProfile` rather than inside it, because the row's two halves have different
    /// owners (§4.4) and different lifetimes. `UserDetails` needs a `user_id`, which only the
    /// server writes; a settings edit made before the first successful run creates a row that has
    /// none, and folding the two together would make the number the user just chose come back as
    /// the fallback. It is also what the settings screen edits optimistically, the way a comment
    /// is edited (see `appReducer`).
    ///
    /// Every reader goes through here — never through `userProfile.settings.cycle`, which is
    /// unvalidated (see `ResolvedCycleSettings`).
    var cycleSettings: ResolvedCycleSettings = ResolvedCycleSettings(nil)
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
