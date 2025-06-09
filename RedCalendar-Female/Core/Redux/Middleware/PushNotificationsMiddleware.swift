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
    
    switch action {
    case .setAPNSToken(let token):
        if case .authenticated(let deviceId, _) = state.authState, token.isSynced == false {
            Task {
                do {
                    let _ = try await apiService.updateAPNSToken(deviceId: deviceId, apnsToken: token.value)
                    dispatch(.setAPNSToken(APNSToken(value: token.value, isSynced: true)))
                    
                    AppLogger.info("Apns token synced")
                } catch {
                    AppLogger.error(error.localizedDescription)
                }
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
