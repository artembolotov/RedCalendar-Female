//
//  AppDelegate.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.06.2025.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    // Store reference to dispatch actions
    var appStore: AppStore?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // UIKit's tint is set from the chosen accent by `AppearanceMiddleware`, not from the
        // `AccentColor` asset here: this runs before the stored theme has been read, and an
        // appearance proxy set once at launch cannot follow a theme the user changes later.
        return true
    }

    // Called when APNs registration succeeds
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        AppLogger.info("Got APNS token: \(token)")
        
        // Dispatch Redux action
        appStore?.send(.push(.setAPNSToken(APNSToken(value: token, isSynced: false))))
    }
    
    // Called when APNs registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLogger.error("APNS registration failed", error: error)
    }
}
