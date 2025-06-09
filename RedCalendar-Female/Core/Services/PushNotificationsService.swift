//
//  PushService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.06.2025.
//

import Foundation
import UserNotifications
import UIKit

protocol PushNotificationsServiceProtocol {
    func registerForRemoteNotifications()
}

final class PushNotificationsService: PushNotificationsServiceProtocol {
    
    @Injected private var apiService: APIServiceProtocol
    
    // Register for push notifications (no user prompt)
    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            AppLogger.info("Registered for remote notifications")
        }
    }
}
