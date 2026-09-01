//
//  NotificationPreference.swift
//  RedCalendar-Female
//

/// Whether this account asked for notifications at all — the half of the answer that travels
/// between devices, as `settings.notifications.muted` on the one `user_profile` row (SYNC.md
/// §4.4). The other half is `PushPermissionState`, which belongs to this phone alone.
///
/// Three cases rather than a `Bool`, and the third is the load-bearing one: "no row has been read
/// yet" and "the row says nothing" look identical and mean opposite things. The first is a
/// returning user whose profile has not been pulled, who may have muted notifications on another
/// device and must not be asked on a guess — that alert is shown once per install. The second is
/// every account imported from RedCalendar 2.0 (§10.2), where silence has always meant on.
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
    /// writes, so a row created by a local edit before the first sync run would read as "no
    /// profile" and take the user's own choice with it.
    init(_ record: UserProfileRecord?) {
        guard let record else {
            self = .unknown
            return
        }
        self = record.settings?.notifications?.muted == true ? .muted : .enabled
    }
}
