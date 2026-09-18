//
//  Configurator.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation
import UserNotifications

// Main-actor isolated because it constructs `TapticFeedbackService`, which owns UIKit
// feedback generators. `setup()` is called from `AppDelegate.didFinishLaunchingWithOptions`,
// which is already on the main actor, so this annotation has no ripple beyond this file. It has
// to be the first thing that method does: `AppStore.shared` resolves services as it is built,
// and an unregistered one is a `fatalError` in `ServiceLocator`.
@MainActor
final class Configurator {
    static let shared = Configurator()
    
    private init() {}
    
    func setup() {
        registerAnalyticsService()
        registerDatabaseService()
        registerKeychainService()
        registerAPIService()
        registerPushPermissionsService()
        registerTapticFeedbackService()
        registerAppearanceService()
        registerNotificationDelegate()
    }
    
    private func registerAnalyticsService() {
        let analytics: any AnalyticsServiceProtocol = AnalyticsService()
        ServiceLocator.shared.addService(AnalyticsServiceProtocol.self, service: analytics)

        analytics.registerApp()
    }

    private func registerDatabaseService() {
        do {
            let dbService: DatabaseServiceProtocol = try DatabaseService()
            ServiceLocator.shared.addService(DatabaseServiceProtocol.self, service: dbService)
        } catch {
            fatalError("Failed to initialize DatabaseService: \(error)")
        }
    }

    private func registerKeychainService() {
        let keychain: KeychainServiceProtocol = KeychainService()
        ServiceLocator.shared.addService(KeychainServiceProtocol.self, service: keychain)
    }

    private func registerAPIService() {
        let apiService: APIServiceProtocol = APIService()
        ServiceLocator.shared.addService(APIServiceProtocol.self, service: apiService)
    }

    private func registerPushPermissionsService() {
        let pushPermissionsService: PushPermissionServiceProtocol = PushPermissionService()
        ServiceLocator.shared.addService(PushPermissionServiceProtocol.self, service: pushPermissionsService)
    }

    private func registerTapticFeedbackService() {
        let tapticFeedbackService: TapticFeedbackServiceProtocol = TapticFeedbackService()
        ServiceLocator.shared.addService(TapticFeedbackServiceProtocol.self, service: tapticFeedbackService)
    }

    private func registerAppearanceService() {
        let appearanceService: AppearanceServiceProtocol = AppearanceService()
        ServiceLocator.shared.addService(AppearanceServiceProtocol.self, service: appearanceService)
    }

    // Not a `ServiceLocator` registration — `NotificationDelegate` has no protocol and nothing
    // injects it. It needs the same "assigned somewhere before the callback can arrive" treatment
    // the services above get, though: `UNUserNotificationCenter.current().delegate` is `weak`,
    // and this is the one place in the app guaranteed to run before a background launch can
    // deliver a notification tap (see `AppDelegate`).
    private func registerNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
}
