//
//  AuthMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation
import UIKit

let authMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
    @Injected var keychain: KeychainServiceProtocol
    @Injected var pushPermissionService: PushPermissionServiceProtocol
    @Injected var apiService: APIServiceProtocol
    
    switch action {
    
    case .checkAuthState:
        // Priority 1: Check for device_id (new system)
        if let deviceId = keychain.getDeviceID() {
            return [.setAuthState(AuthState.authenticated(deviceId: deviceId, userDetails: nil))]
        }
        
        // Priority 2: Check for legacy user_id (Firebase)
        if let userId = keychain.getUserUID() {
            return [.setAuthState(.migrating(userId: userId, error: nil))]
        }
        
        return [.setAuthState(.notAuthenticated)]
        
    case .setAuthState(let authState):
        
        if case .notAuthenticated = authState {
            keychain.deleteDeviceID()
        }
        
        if case .authenticated(_, _) = authState {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
            }
            if state.pushPermissionState == .notAsked {
                await pushPermissionService.requestAuthorization()
            }
        }
        
        return []
       
    case .logout:
        if case .authenticated(let deviceId, _) = state.authState {
            Task {
                do {
                    let _ = try await apiService.logout(deviceId: deviceId)
                    AppLogger.info("Device successfully logged out from server")
                    
                    dispatch(.setAuthState(.notAuthenticated))
                } catch APIServiceError.unauthorized {
                    dispatch(.setAuthState(.notAuthenticated))
                } catch {
                    AppLogger.error(error.localizedDescription)
                }
            }
        }
        return []
        
    default:
        return []
    }
}
