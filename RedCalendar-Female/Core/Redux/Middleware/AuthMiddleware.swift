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
        
    // Handle authentication method states
    if case .authenticating(let authMethod) = authState {
        switch authMethod {
        
        // MARK: - Email Authentication
        case .email(let emailState):
            switch emailState {
            
            case .checking(let email):
                Task {
                    do {
                        let response = try await apiService.checkEmail(email)
                        
                        if response.data.exists {
                            // User exists - show password entry
                            dispatch(.setAuthState(.authenticating(.email(.codeEntry(
                                email: response.data.email,
                                userName: response.data.name,
                                error: nil
                            )))))
                        } else {
                            // User doesn't exist - show registration
                            dispatch(.setAuthState(.authenticating(.email(.registration(
                                email: response.data.email,
                                code: nil,
                                error: nil)
                            ))))
                        }
                        
                    } catch APIServiceError.serverError(let message) {
                        // Server error - show error in entry state
                        dispatch(.setAuthState(.authenticating(.email(.entry(
                            email: email,
                            error: AuthenticationError.serverError(message)
                        )))))
                        
                    } catch APIServiceError.networkError(let error) {
                        // Network error - show error in entry state
                        dispatch(.setAuthState(.authenticating(.email(.entry(
                            email: email,
                            error: AuthenticationError.networkError(error.localizedDescription)
                        )))))
                        
                    } catch {
                        // Unknown error - show generic error
                        dispatch(.setAuthState(.authenticating(.email(.entry(
                            email: email,
                            error: AuthenticationError.unknownError(error.localizedDescription)
                        )))))
                    }
                }
                
            default:
                break
            }
                
            // MARK: - Phone Authentication
            case .phone(let phoneState):
                switch phoneState {
                
                case .requesting(let phoneNumber):
                    // TODO: Handle phone number verification request
                    break
                    
                case .verifying(let phoneNumber, let code):
                    // TODO: Handle phone verification code
                    break
                    
                default:
                    // No API calls needed for entry state
                    break
                }
            }
            
            return []
        }
        
        // Existing logic for other auth states...
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
