//
//  NotificationPreference.swift
//  RedCalendar-Female
//

/// Whether this account asked for notifications at all — the half of the answer that travels
/// between devices, as `settings.notifications.muted` on the one `user_profile` row (SYNC.md
/// §4.4). The other half is `PushPermissionState`, which belongs to this phone and to no one
/// else's.
///
/// Three cases rather than a `Bool`, and the third is the load-bearing one. "The row says
/// nothing is muted" and "no row has been read yet" are the same `false` to a `Bool?`-shaped
/// answer, and the difference decides whether this build is allowed to put the system permission
/// alert on screen: a returning user whose profile has not been pulled yet must not be asked on
/// the guess that they probably want notifications — that alert is shown once per install, and a
/// person who muted notifications on another device would spend it on a question they already
/// answered.
///
/// A row that carries no `notifications` key at all is `.enabled`, not `.unknown`. Every account
/// imported from RedCalendar 2.0 is in exactly that shape (§10.2 — `settings` crossed over
/// verbatim, and 2.0 only ever wrote the key when notifications were turned *off*), so absence
/// is a real answer there and it is the same default the switch draws.
enum NotificationPreference: Sendable, Equatable {
    /// No `user_profile` row has been read yet — before the first sync pull on a fresh install,
    /// and while signed out.
    case unknown
    case enabled
    case muted
}

extension NotificationPreference {
    /// Resolved from the profile row the observation delivered — `nil` when the table has none.
    ///
    /// Read off `UserProfileRecord` rather than off `UserDetails`, for the reason
    /// `DataAction.setCycleSettings` gives: `UserDetails` needs a `user_id` that only the server
    /// writes, so a row created by a local edit before the first successful run would come back
    /// as "no profile" and take the user's own choice with it.
    init(_ record: UserProfileRecord?) {
        guard let record else {
            self = .unknown
            return
        }
        self = record.settings?.notifications?.muted == true ? .muted : .enabled
    }
}
