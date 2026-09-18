//
//  NotificationDelegate.swift
//  RedCalendar-Female
//

import UserNotifications

/// What a tapped push notification's payload says about where to go.
///
/// Read off `userInfo["t"]` — the one key every payload this server sends carries
/// (`notification-messages.js`'s `extras`, spread flat into the payload beside `aps` rather than
/// nested under an `extras` key of its own). The cycle notifications (`PeriodStart.*`,
/// `PeriodEnd.*`, `Ovulation.*`) carry a `d` beside it and have no case here yet — nothing taps
/// into a specific day from one of those today — so an unrecognised or absent `t` is not an
/// error, just nothing to route.
enum NotificationTapTarget: Equatable {
    case addEmailReminder

    init?(userInfo: [AnyHashable: Any]) {
        switch userInfo["t"] as? String {
        case "add_email":
            self = .addEmailReminder
        default:
            return nil
        }
    }
}

/// `UNUserNotificationCenterDelegate` for this app's user-visible pushes.
///
/// Not `AppDelegate`: registering this has nothing to do with `UIApplicationDelegate`'s own
/// callbacks — the silent sync push and the two APNs registration callbacks `AppDelegate` already
/// implements (SYNC.md §7, §8) — and the two kinds of push stay apart the same way the server
/// keeps a `content-available` payload apart from an `aps.alert` one.
///
/// A singleton rather than a value handed to whoever constructs it first:
/// `UNUserNotificationCenter.current().delegate` is `weak`, so whatever is assigned to it has to
/// be kept alive somewhere else for the life of the process. `Configurator.setup()` does that by
/// assigning the shared instance rather than a fresh one — the same reason `AppStore.shared` and
/// `PushNotificationsMiddleware.shared` are singletons rather than values constructed on the spot.
// `UNUserNotificationCenterDelegate`'s requirements are `nonisolated` by default, so a
// `@MainActor` conformer needs the isolation on the conformance itself (SE-0470) rather than on
// the type — the same shape `CalendarGridView`'s `@MainActor Equatable` takes for the same reason.
@MainActor
final class NotificationDelegate: NSObject, @MainActor UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    private override init() {}

    /// Every push this app sends is worth seeing while the app is open too — there is nothing
    /// here whose banner would be a distraction. Without a delegate at all (the state of this app
    /// before this file), the default is to show nothing: a cycle notification has never been
    /// presented while the app was foregrounded, for want of this one method.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    /// The tap — backgrounded, foregrounded, or cold-launching the process, all three arrive here
    /// identically. `Self.action(for:)` is called out as its own method because `UNNotificationResponse`
    /// has no public initialiser: it is the one half of this a test can actually reach.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let action = Self.action(for: response.notification.request.content.userInfo) {
            AppStore.shared.send(action)
        }
        completionHandler()
    }

    /// Pure: a `userInfo` dictionary in, an action out, nothing awaited and nothing dispatched.
    /// `nonisolated` rather than inheriting the type's `@MainActor` — it touches no actor-isolated
    /// state, and leaving it isolated would make it uncallable from a plain (non-`@MainActor`)
    /// test method for no reason beyond the class it happens to live on.
    nonisolated static func action(for userInfo: [AnyHashable: Any]) -> AppAction? {
        switch NotificationTapTarget(userInfo: userInfo) {
        case .addEmailReminder:
            // Reaches exactly where `ProfileView`'s own "Email" row does (SYNC.md §18.12,
            // ProfileView.swift). `HomeView.openSettingsIfEmailPending()` is what notices this
            // state and opens the two screens between `HomeView` and `ProfileView` to reach it.
            return .emailBinding(.set(.entry()))

        case nil:
            return nil
        }
    }
}
