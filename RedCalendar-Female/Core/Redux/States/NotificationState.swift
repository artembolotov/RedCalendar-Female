//
//  NotificationState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 21.05.2026.
//

/// The two independent answers to "will this person see a notification", plus the token that
/// makes it possible at all.
///
/// They are independent on purpose and neither one may be written from the other. `preference`
/// belongs to the account and reaches every device through the profile (SYNC.md §4.4);
/// `pushPermissionState` belongs to this phone and is iOS's to change, never ours. A device whose
/// system permission is denied therefore leaves the account's preference exactly as it is — the
/// person's other phone is still entitled to the notifications they asked for.
struct NotificationState: Equatable {
    var apnsToken: APNSToken?
    var pushPermissionState: PushPermissionState?
    var preference: NotificationPreference = .unknown
}

extension NotificationState {
    /// iOS will deliver nothing to *this* device whatever the account asks for. `.notAsked` is
    /// deliberately not blocked: it is the state the permission alert can still be shown from.
    var isBlockedBySystem: Bool { pushPermissionState == .denied }

    /// The account's answer, with "not read yet" reading as yes — the same default the switch
    /// draws and the same one a profile carrying no `notifications` key means.
    var isAllowedByPreference: Bool { preference != .muted }

    /// The one condition under which this build may put the system permission alert on screen:
    /// the account has actually asked for notifications, and iOS has not yet been asked on its
    /// behalf. `.unknown` is not enough — see `NotificationPreference`.
    var shouldRequestSystemPermission: Bool {
        preference == .enabled && pushPermissionState == .notAsked
    }
}
