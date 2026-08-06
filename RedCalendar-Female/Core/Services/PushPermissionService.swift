//
//  PushPermissionService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.06.2025.
//

@preconcurrency import UserNotifications
import UIKit

// MARK: - Push Permission Status
enum PushPermissionState {
    case notAsked
    case denied
    case authorized
}

// MARK: - Protocol
protocol PushPermissionServiceProtocol: Sendable {
    func getState() async -> PushPermissionState
    
    @discardableResult
    func requestAuthorization() async -> Bool
}

// MARK: - Implementation
final class PushPermissionService: PushPermissionServiceProtocol, Sendable {
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - Get Current Status
    func getState() async -> PushPermissionState {
        let settings = await notificationCenter.notificationSettings()
        
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notAsked
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .notAsked
        }
    }
    
    // MARK: - Request Authorization
    func requestAuthorization() async -> Bool {
        do {
            let isGranted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            
            return isGranted
            
        } catch {
            AppLogger.error("Push permission request failed", error: error)
            return false
        }
    }
}
