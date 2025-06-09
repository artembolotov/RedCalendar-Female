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
    @Injected var analytics: AnalyticsServiceProtocol
    
    switch action {
    case .pushRegistrationCompleted(let token):
        // Save token and try to sync if authenticated
        if state.isAuthenticated, let deviceId = state.deviceId {
            return [.syncPushToken]
        }
        return []
        
    case .authCheckCompleted(let deviceId):
        // If we have unsyced token and now authenticated - sync it
        if deviceId != nil,
           let token = state.apnsToken,
           !state.isApnsTokenSynced {
            return [.syncPushToken]
        }
        return []
        
    case .syncPushToken:
        Task {
            do {
                _ = try await apiService.updateAPNSToken(deviceId: state.deviceId!, apnsToken: state.apnsToken!)
                dispatch(.pushTokenSynced(true))
            } catch {
                dispatch(.pushTokenSynced(false))
            }
        }
        return []
        
    case .retryFailedTasks:
        if state.isAuthenticated && !state.isApnsTokenSynced {
            return [.syncPushToken]
        }
        return []
        
    default:
        return []
    }
}
