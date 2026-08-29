//
//  PushNotificationMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.06.2025.
//

import Foundation

/// Main-actor isolated because it remembers one thing between actions, and by the rule in
/// `CLAUDE.md` a middleware that keeps state has to say where that state lives.
///
/// What it remembers is the registration currently in flight. Without it the token was sent
/// twice on every single launch: `didRegisterForRemoteNotificationsWithDeviceToken` dispatches
/// `.setAPNSToken(isSynced: false)`, `scenePhase == .active` dispatches `.retryFailedTasks` a
/// moment later, and `isSynced` does not flip until the first request comes *back* — so the
/// retry re-dispatched an action whose work had already started. Two POSTs, two
/// `Apns token synced`, every time, and one more for every return from the background while a
/// registration was slow.
@MainActor
final class PushNotificationsMiddleware {
    static let shared = PushNotificationsMiddleware()

    @Injected private var apiService: APIServiceProtocol
    @Injected private var pushPermissionService: PushPermissionServiceProtocol

    /// Keyed by device **and** token, not by token alone. The same token is handed back by APNs
    /// after a new sign-in, and a guard that only knew the string would mistake the new device's
    /// registration for the one still in flight for the old one — and skip it for good.
    private struct Registration: Equatable {
        let deviceId: String
        let token: String
    }

    private var inFlight: Registration?

    private init() {}

    func handle(state: AppState, action: AppAction, dispatch: @escaping Dispatch) async {
        switch action {

        // Owned domain — exhaustive, no `default`.
        case .push(let pushAction):
            switch pushAction {

            case .setAPNSToken(let token):
                guard case .authenticated(let deviceId, _) = state.authState, !token.isSynced else { break }

                let registration = Registration(deviceId: deviceId, token: token.value)
                guard inFlight != registration else { break }
                inFlight = registration

                Task {
                    defer { if inFlight == registration { inFlight = nil } }
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

            case .checkPermissionState:
                Task {
                    let status = await pushPermissionService.getState()
                    dispatch(.push(.setPermissionState(status)))
                }

            case .setPermissionState:
                break
            }

        // The retry the guard above is actually for: a registration that failed leaves the token
        // `isSynced == false` and nothing in flight, so the next foreground sends it again.
        case .retryFailedTasks:
            if state.isAuthenticated, let token = state.notifications.apnsToken, token.isSynced == false {
                dispatch(.push(.setAPNSToken(token)))
            }

        // The request outlives the session it was made in, and its `defer` would then clear a
        // slot the next sign-in has already claimed. Dropping it here is what lets the same
        // token be registered again for the new device.
        case .auth(.set(.notAuthenticated)), .auth(.logout):
            inFlight = nil

        default:
            break
        }
    }
}
