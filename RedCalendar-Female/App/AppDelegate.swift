//
//  AppDelegate.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.06.2025.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // The documented "exactly once per process" point, and the one that runs on a background
        // launch — where `WindowGroup`'s closure does not (SYNC.md §8). Everything the app needs
        // before a scene exists starts here.
        //
        // The order is not a preference. `AppStore.shared` is a lazy `static let` whose evaluation
        // calls `combineAppMiddlewares()`, and any service resolved before it is registered is a
        // `fatalError` in `ServiceLocator` — so `setup()` goes first, exactly as the rule in
        // CLAUDE.md ("nothing resolves a service at construction time") has always required. Only
        // the place has moved.
        Configurator.shared.setup()

        AppStore.shared.send(.auth(.check))
        AppStore.shared.send(.analytics(.checkStatus))
        AppStore.shared.send(.appearance(.checkAccentTheme))

        // Nothing sets `UIWindow.appearance().tintColor` here, deliberately: this runs before the
        // stored theme has been read, and an appearance proxy set once at launch cannot follow a
        // theme the user changes later. `AppearanceMiddleware` writes it on `.setAccentTheme`.
        return true
    }

    // MARK: - Remote Notifications

    /// The silent push of SYNC.md §7.
    ///
    /// `r` is the revision the server had written when it sent this, and comparing it with the
    /// local cursor is what lets a device that is already current answer without touching the
    /// network — which is the behaviour APNs' background budget is actually granted for. The
    /// comparison happens inside the run, against the cursor read in its first transaction,
    /// because that is the only reading of it that cannot be stale.
    ///
    /// `syncNow` is called directly rather than through `.sync(.requested)`: `send` returns
    /// nothing, and iOS wants a `UIBackgroundFetchResult` here. Same implementation either way.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Read out here rather than carried into the task: `userInfo` is not `Sendable`, and an
        // `Int` is all of it that matters. APNs delivers JSON numbers as `NSNumber`.
        let revision = (userInfo["r"] as? NSNumber)?.intValue
        AppLogger.info("Silent push: revision \(revision.map(String.init) ?? "none")")

        Task { @MainActor in
            let result = await SyncMiddleware.shared.syncNow(
                reason: .remoteNotification,
                serverRevision: revision
            )
            completionHandler(result)
        }
    }

    // Called when APNs registration succeeds
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        AppLogger.info("Got APNS token: \(token)")
        
        // Dispatch Redux action
        AppStore.shared.send(.push(.setAPNSToken(APNSToken(value: token, isSynced: false))))
    }
    
    // Called when APNs registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLogger.error("APNS registration failed", error: error)
    }
}
