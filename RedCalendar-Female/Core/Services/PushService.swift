//
//  PushService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.06.2025.
//

import Foundation
import UserNotifications
import UIKit

protocol PushServiceProtocol {
    func registerForRemoteNotifications()
    func updateAPNSToken(_ token: String) async throws -> APNSTokenResponse
}

final class PushService: PushServiceProtocol {
    
    @Injected private var apiService: APIServiceProtocol
    
    // Register for push notifications (no user prompt)
    func registerForRemoteNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
            AppLogger.info("Registered for remote notifications")
        }
    }
    
    func updateAPNSToken(_ token: String) async throws -> APNSTokenResponse {
        @Injected var keychain: KeychainServiceProtocol
        
        guard let deviceId = keychain.getDeviceID() else {
            AppLogger.error("Cannot update APNS token: no device_id")
            throw APIServiceError.serverError("No device_id found")
        }
        
        let response = try await apiService.updateAPNSToken(deviceId: deviceId, apnsToken: token)
        AppLogger.info("APNS token updated successfully")
        return response
    }
}
