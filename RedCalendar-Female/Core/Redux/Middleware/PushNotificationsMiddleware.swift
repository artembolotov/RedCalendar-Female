//
//  PushNotificationMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.06.2025.
//

import Foundation

let pushNotificationMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
    @Injected var pushService: PushNotificationsServiceProtocol
    @Injected var analytics: AnalyticsServiceProtocol
    
    switch action {
    case .pushRegistrationCompleted(let token):
        // Check if user is authenticated - send token to server immediately
        if let deviceId = state.deviceId {
            AppLogger.info("User authenticated, sending APNS token to server")
            // Start the async task to send token
            Task {
                dispatch(.pushTokenUpdating)
                do {
                    let _ = try await pushService.updateAPNSToken(token)
                    dispatch(.pushTokenUpdated(success: true))
                    analytics.trackEvent("push_token_updated_success")
                } catch {
                    AppLogger.error("Failed to update APNS token on server", error: error)
                    dispatch(.pushTokenUpdated(success: false))
                    analytics.trackEvent("push_token_updated_failed")
                }
            }
        } else {
            // User not authenticated yet, token will be sent after auth
            AppLogger.info("User not authenticated, APNS token saved for later")
        }
        analytics.trackEvent("push_registration_completed")
        return []
        
    case .retryFailedTasks:
        // Only retry if there are actually failed tasks
        // Check if user is authenticated and has failed push token
        if let deviceId = state.deviceId,
           let token = state.apnsToken,
           state.pushNotificationState == .registered {
            
            AppLogger.info("Found failed APNS token task, retrying...")
            AppLogger.info("- deviceId: present")
            AppLogger.info("- apnsToken: present")
            AppLogger.info("- pushNotificationState: .registered (failed)")
            
            Task {
                dispatch(.pushTokenUpdating)
                do {
                    let _ = try await pushService.updateAPNSToken(token)
                    dispatch(.pushTokenUpdated(success: true))
                    analytics.trackEvent("push_token_updated_on_retry")
                } catch {
                    AppLogger.error("Failed to update APNS token on retry", error: error)
                    dispatch(.pushTokenUpdated(success: false))
                    analytics.trackEvent("push_token_update_failed_on_retry")
                }
            }
        } else {
            // No failed tasks found - this is normal behavior
            // Don't spam logs on every app activation
            if state.deviceId == nil {
                AppLogger.info("No retry needed: user not authenticated")
            } else if state.apnsToken == nil {
                AppLogger.info("No retry needed: no APNS token available")
            } else if state.pushNotificationState != .registered {
                AppLogger.info("No retry needed: push token state is \(state.pushNotificationState)")
            }
        }
        return []
        
    case .authCheckCompleted(let deviceId):
        // Don't send token here - it will be sent either:
        // 1. In pushRegistrationCompleted if user is already authenticated
        // 2. In migrationCompleted/login if user just became authenticated
        return []
        
    case .pushRegistrationFailed(let error):
        AppLogger.error("Push registration failed", error: error)
        analytics.trackEvent("push_registration_failed", parameters: [
            "error": error.localizedDescription
        ])
        return []
        
    case .login:
        // After manual login, retry sending APNS token if it failed before
        if let token = state.apnsToken,
           state.pushNotificationState == .registered {
            AppLogger.info("User logged in, retrying APNS token send")
            Task {
                dispatch(.pushTokenUpdating)
                do {
                    let _ = try await pushService.updateAPNSToken(token)
                    dispatch(.pushTokenUpdated(success: true))
                    analytics.trackEvent("push_token_updated_after_login")
                } catch {
                    AppLogger.error("Failed to update APNS token after login", error: error)
                    dispatch(.pushTokenUpdated(success: false))
                    analytics.trackEvent("push_token_update_failed_after_login")
                }
            }
        }
        return []
        
    case .migrationCompleted:
        // User migrated and we have a pending APNS token - send it to server
        if let token = state.apnsToken,
           state.pushNotificationState == .registered {
            AppLogger.info("User migrated with pending APNS token, sending to server")
            Task {
                dispatch(.pushTokenUpdating)
                do {
                    let _ = try await pushService.updateAPNSToken(token)
                    dispatch(.pushTokenUpdated(success: true))
                    analytics.trackEvent("push_token_updated_after_migration")
                } catch {
                    AppLogger.error("Failed to update APNS token after migration", error: error)
                    dispatch(.pushTokenUpdated(success: false))
                    analytics.trackEvent("push_token_update_failed_after_migration")
                }
            }
        }
        return []
        
    default:
        return []
    }
}
