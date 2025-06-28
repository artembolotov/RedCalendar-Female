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
                
            case .registering(let email, let code, let name),
                 .verifying(let email, let code, let name):
                Task {
                    do {
                        // For registering: pass the name, for verifying: pass nil
                        let nameToSend: String? = if case .registering = emailState { name } else { nil }
                        
                        let response = try await apiService.verifyCode(
                            email: email,
                            code: code,
                            name: nameToSend
                        )
                        
                        guard response.success, let data = response.data else {
                            throw APIServiceError.serverError(response.message ?? "Authentication failed")
                        }
                        
                        keychain.saveDeviceID(data.deviceId)
                        keychain.deleteUserUID()
                        
                        dispatch(.setAuthState(.authenticated(
                            deviceId: data.deviceId,
                            userDetails: nil
                        )))
                        
                    } catch {
                        let authError = AuthenticationError.from(error)
                        
                        // Return to appropriate error state based on original case
                        let errorState: EmailAuthState = if case .registering = emailState {
                            .registration(email: email, code: code, name: name, error: authError)
                        } else {
                            .codeEntry(email: email, code: code, userName: name, error: authError)
                        }
                        
                        dispatch(.setAuthState(.authenticating(.email(errorState))))
                    }
                }
            default:
                break
            }
                
            // MARK: - Phone Authentication
            case .phone(let phoneState):
                switch phoneState {
                
                case .requesting(let phoneNumber):
                    Task {
                        let phoneState: PhoneAuthState
                        
                        do {
                            let response = try await apiService.checkPhone(phoneNumber)
                            
                            // This shouldn't happen with current implementation
                            if response.success {
                                phoneState = .verification(phoneNumber: phoneNumber, maskedCallerNumber: "")
                            } else {
                                phoneState = .entry(
                                    phoneNumber: phoneNumber,
                                    error: AuthenticationError.from(APIServiceError.serverError(
                                        response.message ?? "Phone authentication not available"
                                    ))
                                )
                            }
                            
                        } catch {
                            // Handle all errors the same way
                            phoneState = .entry(
                                phoneNumber: phoneNumber,
                                error: AuthenticationError.from(error)
                            )
                        }
                        
                        dispatch(.setAuthState(.authenticating(.phone(phoneState))))
                    }
                    
                case .verifying(let phoneNumber, let code):
                    // TODO: Handle phone verification code
                    // This will be implemented when phone verification is fully supported
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
