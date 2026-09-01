//
//  PushNotificationMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.06.2025.
//

import Foundation
import UIKit

/// Main-actor isolated because it remembers things between actions, and by the rule in
/// `CLAUDE.md` a middleware that keeps state has to say where that state lives.
///
/// The first thing it remembers is the registration currently in flight. Without it the token was sent
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

    /// The second thing: whether iOS has already been asked in *this* process.
    ///
    /// Not merely an in-flight guard, though it is that too — two triggers do arrive back to back
    /// (the preference landing, and the permission state being re-read on a foreground), and
    /// without it both would call `requestAuthorization` while the first alert is still up. It
    /// never resets, because a second ask in one session can never be useful: the alert is shown
    /// once per install, and an answered one leaves `pushPermissionState` at `.authorized` or
    /// `.denied`, which the condition below already refuses.
    ///
    /// What that buys is a loop that cannot happen. The request dispatches
    /// `.checkPermissionState` when it returns, and that comes back as `.setPermissionState` —
    /// the very trigger that asks again. A request that failed without the user answering
    /// anything (a thrown `requestAuthorization`) leaves the state at `.notAsked`, and the two
    /// would otherwise chase each other for as long as the app is open.
    private var hasRequestedPermissionThisSession = false

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

            // One of the two halves of the condition below has just been answered, so the
            // question is worth asking again. This is also what makes the rule self-healing:
            // every return to the foreground re-reads the system state (`RedCalendarApp`
            // dispatches `.checkPermissionState` on `.active`), so a request skipped because the
            // app was in the background is retried the moment somebody is actually looking.
            case .setPermissionState:
                requestSystemPermissionIfNeeded(state: state, dispatch: dispatch)
            }

        // The retry the guard above is actually for: a registration that failed leaves the token
        // `isSynced == false` and nothing in flight, so the next foreground sends it again.
        case .retryFailedTasks:
            if state.isAuthenticated, let token = state.notifications.apnsToken, token.isSynced == false {
                dispatch(.push(.setAPNSToken(token)))
            }

        // The other half of the condition, arriving from the profile observation — a preference
        // this account chose here, on the onboarding screen, or on another phone entirely. All
        // three reach this line identically, which is the point: nothing that flips the switch
        // has to remember to ask iOS as well.
        case .data(.setNotificationPreference):
            requestSystemPermissionIfNeeded(state: state, dispatch: dispatch)

        // Registering for remote notifications is not the same question as asking the user, and
        // it is not conditional on the answer: the token is what carries the silent sync push
        // (SYNC.md §7, §8), which a muted account still wants. So it happens on every sign-in —
        // including the one `.check` produces on every cold launch — whatever the switch says.
        case .auth(.set(.authenticated)):
            UIApplication.shared.registerForRemoteNotifications()

        // The request outlives the session it was made in, and its `defer` would then clear a
        // slot the next sign-in has already claimed. Dropping it here is what lets the same
        // token be registered again for the new device.
        case .auth(.set(.notAuthenticated)), .auth(.logout):
            inFlight = nil

        default:
            break
        }
    }

    // MARK: - Private Methods

    /// The one place in the app that may put the system permission alert on screen.
    ///
    /// It used to be `AuthMiddleware`, on `.authenticated` and on nothing else, which asked
    /// everybody exactly once — at the moment the app knows least. A returning user's profile has
    /// not been pulled yet at sign-in, so the question went to people who had already turned
    /// notifications off on another device; and the person who turns the switch *on* a week later
    /// was never asked at all, because the one moment that could ask had passed.
    ///
    /// Both halves of the condition therefore live in state and this is called whenever either
    /// one changes: `preference == .enabled` (the account asked for it, and `.unknown` is not
    /// enough — see `NotificationPreference`) and `pushPermissionState == .notAsked` (iOS still
    /// has an answer to give; `.denied` is final and only the Settings app can undo it).
    private func requestSystemPermissionIfNeeded(state: AppState, dispatch: @escaping Dispatch) {
        guard state.isAuthenticated,
              state.notifications.shouldRequestSystemPermission,
              !hasRequestedPermissionThisSession else { return }

        // An alert nobody is looking at is the one way to waste a question that is asked once per
        // install: a silent push can wake the app in the background, and a sync run in that wake
        // pulls the very profile that satisfies the condition above. The foreground
        // `.checkPermissionState` brings the request back when there is somebody to answer it.
        guard UIApplication.shared.applicationState == .active else { return }

        hasRequestedPermissionThisSession = true

        // In its own `Task` rather than awaited inline: this call does not return until the user
        // answers, and middleware runs on the store's serial effect queue — awaiting it here
        // would stall every action behind it for as long as the alert is up.
        Task {
            await pushPermissionService.requestAuthorization()
            // The answer is read back from the system rather than taken from the return value:
            // a request that threw also returns `false`, and recording that as `.denied` would
            // leave the state claiming a refusal the user never made — and, worse, one this rule
            // would then never ask about again.
            dispatch(.push(.checkPermissionState))
        }
    }
}
