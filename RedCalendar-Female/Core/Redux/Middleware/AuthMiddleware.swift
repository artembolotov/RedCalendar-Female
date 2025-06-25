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
                
            case .checking(let email, let name):
                Task {
                    let emailState: EmailAuthState
                    
                    do {
                        let data = try await apiService.checkEmail(email).data
                        emailState = data.exists
                            ? .codeEntry(email: data.email, userName: data.name)
                            : .registration(email: data.email, name: name)
                    } catch {
                        emailState = .entry(email: email, error: AuthenticationError.from(error))
                    }
                    
                    dispatch(.setAuthState(.authenticating(.email(emailState))))
                }
                
            case .registering(let email, let code, let name):
                Task {
                    do {
                        
                        let response = try await apiService.verifyCode(
                            email: email,
                            code: code,
                            name: name
                        )
                        
                        guard response.success, let data = response.data else {
                            throw APIServiceError.serverError(response.message ?? "Registration failed")
                        }
                        
                        keychain.saveDeviceID(data.deviceId)
                        keychain.deleteUserUID()
                        
                        dispatch(.setAuthState(.authenticated(
                            deviceId: data.deviceId,
                            userDetails: nil
                        )))
                        
                    } catch {
                        let authError = AuthenticationError.from(error)
                        dispatch(.setAuthState(.authenticating(.email(.registration(
                            email: email,
                            code: code,
                            name: name,
                            error: authError
                        )))))
                    }
                }
                
            case .verifying(let email, let code, let name):
                Task {
                    do {
                        let response = try await apiService.verifyCode(
                            email: email,
                            code: code,
                            name: nil
                        )
                        
                        guard response.success, let data = response.data else {
                            throw APIServiceError.serverError(response.message ?? "Login failed")
                        }
                        
                        keychain.saveDeviceID(data.deviceId)
                        keychain.deleteUserUID()
                        
                        dispatch(.setAuthState(.authenticated(
                            deviceId: data.deviceId,
                            userDetails: nil
                        )))
                    } catch {
                        let authError = AuthenticationError.from(error)
                        dispatch(.setAuthState(.authenticating(.email(.codeEntry(
                            email: email,
                            userName: name,
                            error: authError)
                        ))))
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
