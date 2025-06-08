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
    
    // Called when APNs registration succeeds
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        AppLogger.info("Got APNS token: \(token.prefix(20))...")
        
        // Dispatch Redux action
        appStore?.send(.pushRegistrationCompleted(token: token))
    }
    
    // Called when APNs registration fails
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        AppLogger.error("APNS registration failed", error: error)
        
        // Dispatch Redux action
        appStore?.send(.pushRegistrationFailed(error))
    }
}
