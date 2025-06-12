//
//  PushNotificationMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.06.2025.
//

import Foundation

// PushNotificationMiddleware.swift
let pushNotificationMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
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
                    dispatch(.setAuthState(.authenticating(nil)))
                } catch {
                    AppLogger.error(error.localizedDescription)
                }
            }
        }
        return []
        
    case .setPushPermissionState(let state):
        if state == nil {
            Task {
                let status = await pushPermissionService.getState()
                dispatch(.setPushPermissionState(status))
            }
        }
        return []
        
    case .retryFailedTasks:
        
        if state.isAuthenticated, let token = state.apnsToken, token.isSynced == false {
            return [.setAPNSToken(token)]
        }
        return []
        
    default:
        return []
    }
}
