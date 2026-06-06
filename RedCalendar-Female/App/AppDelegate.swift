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
        if let accent = UIColor(named: "AccentColor") {
            UIWindow.appearance().tintColor = accent
        }
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
        appStore?.send(.setAPNSToken(APNSToken(value: token, isSynced: false)))
    }
    
    // Called when APNs registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLogger.error("APNS registration failed", error: error)
    }
}
