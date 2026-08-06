//
//  PushNotificationMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.06.2025.
//

import Foundation

// PushNotificationMiddleware.swift
let pushNotificationMiddleware: Middleware = { state, action, dispatch in
    @Injected var apiService: APIServiceProtocol
    @Injected var pushPermissionService: PushPermissionServiceProtocol
    
    switch action {
    case .setAPNSToken(let token):
        if case .authenticated(let deviceId, _) = state.authState, token.isSynced == false {
            Task {
                do {
                    let _ = try await apiService.updateAPNSToken(deviceId: deviceId, apnsToken: token.value)
                    dispatch(.setAPNSToken(APNSToken(value: token.value, isSynced: true)))
                    
                    AppLogger.info("Apns token synced")
                } catch APIServiceError.unauthorized {
                    dispatch(.setAuthState(.notAuthenticated))
                } catch {
                    AppLogger.error(error.localizedDescription)
                }
            }
        }
        
    case .setPushPermissionState(let state):
        if state == nil {
            Task {
                let status = await pushPermissionService.getState()
                dispatch(.setPushPermissionState(status))
            }
        }
        
    case .retryFailedTasks:
        
        if state.isAuthenticated, let token = state.notifications.apnsToken, token.isSynced == false {
            dispatch(.setAPNSToken(token))
        }
        
    default:
        break
    }
}
