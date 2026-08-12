//
//  AuthMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation
import UIKit

let authMiddleware: Middleware = { state, action, dispatch in
    @Injected var keychain: KeychainServiceProtocol
    @Injected var pushPermissionService: PushPermissionServiceProtocol
    @Injected var apiService: APIServiceProtocol

    // This middleware owns the auth domain, so the inner switch is exhaustive: a new
    // `AuthAction` is a build error here until somebody decides what it means.
    guard case .auth(let authAction) = action else { return }

    switch authAction {

    case .check:
        // Priority 1: Check for device_id (new system)
        if let deviceId = keychain.getDeviceID() {
            dispatch(.auth(.set(.authenticated(deviceId: deviceId, userDetails: nil))))
            return
        }

        // Priority 2: Check for legacy user_id (Firebase)
        if let userId = keychain.getUserUID() {
            dispatch(.auth(.set(.migrating(userId: userId, error: nil))))
            return
        }

        dispatch(.auth(.set(.notAuthenticated)))

    case .set(let authState):

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

                        dispatch(.auth(.set(.authenticating(.email(emailState)))))
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

                            dispatch(.auth(.set(.authenticated(
                                deviceId: data.deviceId,
                                userDetails: data.user
                            ))))

                        } catch {
                            let authError = AuthenticationError.from(error)

                            // Return to appropriate error state based on original case
                            let errorState: EmailAuthState = if case .registering = emailState {
                                .registration(email: email, code: code, name: name, error: authError)
                            } else {
                                .codeEntry(email: email, code: code, userName: name, error: authError)
                            }

                            dispatch(.auth(.set(.authenticating(.email(errorState)))))
                        }
                    }
                default:
                    break
                }

            // MARK: - Phone Authentication
            case .phone(let phoneState):
                switch phoneState {

                case .requesting(let prettyPhoneNumber, let e164PhoneNumber):
                    Task {
                        let phoneState: PhoneAuthState

                        do {
                            let response = try await apiService.checkPhone(e164PhoneNumber)

                            // Check if phone exists and Flash Call was successful
                            guard let data = response.data else {
                                throw APIServiceError.serverError(response.message ?? "Phone check failed")
                            }

                            if response.success && data.exists {
                                // Flash Call successfully initiated
                                guard let flashCall = data.flashCall else {
                                    throw APIServiceError.serverError("Flash Call data missing")
                                }

                                phoneState = .verification(
                                    prettyPhoneNumber: prettyPhoneNumber,
                                    e164PhoneNumber: e164PhoneNumber,
                                    maskedCallerNumber: flashCall.from,
                                    requestId: flashCall.requestId,
                                    error: nil
                                )
                            } else {
                                // Error - phone not found or Flash Call failed
                                let authError: AuthenticationError = !data.exists
                                    ? .phoneNotRegistered
                                    : .phoneCallFailed

                                phoneState = .entry(
                                    prettyPhoneNumber: prettyPhoneNumber,
                                    error: authError
                                )
                            }

                        } catch {
                            // Network or other errors
                            phoneState = .entry(
                                prettyPhoneNumber: prettyPhoneNumber,
                                error: AuthenticationError.from(error)
                            )
                        }

                        dispatch(.auth(.set(.authenticating(.phone(phoneState)))))
                    }

                case .verifying(let prettyPhoneNumber, let e164PhoneNumber, let maskedCallerNumber, let requestId, let verificationCode):
                    Task {
                        let phoneState: PhoneAuthState

                        do {
                            // Call API to verify Flash Call code
                            let response = try await apiService.verifyFlashCall(requestId: requestId, code: verificationCode)

                            guard response.success, let data = response.data else {
                                throw APIServiceError.serverError(response.message ?? "Flash Call verification failed")
                            }

                            // Save device ID and clean up old Firebase user ID
                            keychain.saveDeviceID(data.deviceId)
                            keychain.deleteUserUID()

                            // Move to authenticated state
                            dispatch(.auth(.set(.authenticated(
                                deviceId: data.deviceId,
                                userDetails: data.user
                            ))))

                        } catch {
                            // Verification failed - return to verification screen with error (not entry)
                            let authError = AuthenticationError.from(error)
                            phoneState = .verification(
                                prettyPhoneNumber: prettyPhoneNumber,
                                e164PhoneNumber: e164PhoneNumber,
                                maskedCallerNumber: maskedCallerNumber,
                                requestId: requestId,
                                error: authError
                            )

                            dispatch(.auth(.set(.authenticating(.phone(phoneState)))))
                        }
                    }

                default:
                    // No API calls needed for entry and verification states
                    break
                }
            }

        }

        // Existing logic for other auth states...
        if case .notAuthenticated = authState {
            keychain.deleteDeviceID()
        }

        if case .authenticated(_, _) = authState {
            UIApplication.shared.registerForRemoteNotifications()
            if state.notifications.pushPermissionState == .notAsked {
                // In its own `Task` rather than awaited here: this call puts the system
                // permission alert on screen and does not return until the user answers it.
                // Middleware runs on the store's serial effect queue, so awaiting it inline
                // would stall every action behind it for as long as the alert is up.
                Task {
                    await pushPermissionService.requestAuthorization()
                }
            }
        }

    case .logout:
        if case .authenticated(let deviceId, _) = state.authState {
            Task {
                do {
                    let _ = try await apiService.logout(deviceId: deviceId)
                    AppLogger.info("Device successfully logged out from server")

                    dispatch(.auth(.set(.notAuthenticated)))
                } catch APIServiceError.unauthorized {
                    dispatch(.auth(.set(.notAuthenticated)))
                } catch {
                    AppLogger.error(error.localizedDescription)
                }
            }
        }
    }
}
