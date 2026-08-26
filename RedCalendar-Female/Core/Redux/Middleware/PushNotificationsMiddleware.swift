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

    // Owned domain — exhaustive, no `default`.
    case .push(let pushAction):
        switch pushAction {

        case .setAPNSToken(let token):
            if case .authenticated(let deviceId) = state.authState, token.isSynced == false {
                Task {
                    do {
                        let _ = try await apiService.updateAPNSToken(deviceId: deviceId, apnsToken: token.value)
                        dispatch(.push(.setAPNSToken(APNSToken(value: token.value, isSynced: true))))

                        AppLogger.info("Apns token synced")
                    } catch APIServiceError.unauthorized {
                        dispatch(.auth(.set(.notAuthenticated)))
                    } catch {
                        AppLogger.error(error.localizedDescription)
                    }
                }
            }

        case .setPermissionState(let permissionState):
            if permissionState == nil {
                Task {
                    let status = await pushPermissionService.getState()
                    dispatch(.push(.setPermissionState(status)))
                }
            }
        }

    case .retryFailedTasks:
        if state.isAuthenticated, let token = state.notifications.apnsToken, token.isSynced == false {
            dispatch(.push(.setAPNSToken(token)))
        }

    default:
        break
    }
}
