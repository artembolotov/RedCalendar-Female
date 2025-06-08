//
//  PushNotificationMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.06.2025.
//

import Foundation

let pushNotificationMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
    @Injected var pushService: PushServiceProtocol
    @Injected var analytics: AnalyticsServiceProtocol
    
    switch action {
    case .pushRegistrationCompleted(let token):
        // Check if user is authenticated - send token to server immediately
        if let deviceId = state.deviceId {
            AppLogger.info("User authenticated, sending APNS token to server")
            Task {
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
        
    case .pushRegistrationFailed(let error):
        AppLogger.error("Push registration failed", error: error)
        analytics.trackEvent("push_registration_failed", parameters: [
            "error": error.localizedDescription
        ])
        return []
        
    case .authCheckCompleted(let deviceId):
        // User authenticated and we have a pending APNS token - send it to server
        if deviceId != nil,
           let token = state.apnsToken,
           state.pushNotificationState == .registered {
            AppLogger.info("User authenticated with pending APNS token, sending to server")
            Task {
                do {
                    let _ = try await pushService.updateAPNSToken(token)
                    dispatch(.pushTokenUpdated(success: true))
                    analytics.trackEvent("push_token_updated_after_auth")
                } catch {
                    AppLogger.error("Failed to update APNS token after auth", error: error)
                    dispatch(.pushTokenUpdated(success: false))
                    analytics.trackEvent("push_token_update_failed_after_auth")
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
