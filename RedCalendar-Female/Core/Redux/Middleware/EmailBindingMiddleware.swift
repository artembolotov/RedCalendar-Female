//
//  EmailBindingMiddleware.swift
//  RedCalendar-Female
//

import Foundation

/// Binding an address to the account, and changing the one it has (SYNC.md §18).
///
/// It owns the `emailBinding` domain, so the inner switch is exhaustive — and the two transient
/// states are the whole of it: `.requesting` asks for a code, `.confirming` sends it back. Both
/// answer by dispatching the next state, exactly the way `AuthMiddleware` drives sign-in.
let emailBindingMiddleware: Middleware = { state, action, dispatch in
    @Injected var apiService: APIServiceProtocol

    guard case .emailBinding(let bindingAction) = action else { return }

    switch bindingAction {

    case .set(let bindingState):
        guard let bindingState else { return }

        // Every endpoint here is behind the device token, so a screen open without a session has
        // nothing to send. It cannot normally happen — the screen is two pushes inside Settings —
        // and if it does, the state is left exactly where it is rather than replaced with an
        // error about something the person did not do.
        guard let deviceId = state.deviceId else { return }

        switch bindingState {

        case .requesting(let email):
            Task {
                do {
                    let response = try await apiService.requestEmailBinding(deviceId: deviceId, email: email)

                    guard response.success, let data = response.data else {
                        throw APIServiceError.serverError(response.message ?? "Email binding request failed")
                    }

                    // Nothing was sent, because nothing needed to be: the address is already on
                    // this account (§18.4). There is no code coming, so the code screen would be
                    // a field that can only ever fail — the flow ends here instead, saying the
                    // true thing.
                    if data.alreadyYours {
                        dispatch(.emailBinding(.set(.done(
                            email: data.email,
                            changed: false,
                            previousNotified: false
                        ))))
                    } else {
                        dispatch(.emailBinding(.set(.codeEntry(
                            email: data.email,
                            isChange: data.isChange
                        ))))
                    }

                } catch {
                    dispatch(.emailBinding(.set(.entry(
                        email: email,
                        error: EmailBindingError.from(error)
                    ))))
                }
            }

        case .confirming(let email, let code, let isChange):
            Task {
                do {
                    let response = try await apiService.confirmEmailBinding(
                        deviceId: deviceId,
                        email: email,
                        code: code
                    )

                    guard response.success, let data = response.data else {
                        throw APIServiceError.serverError(response.message ?? "Email confirmation failed")
                    }

                    AppLogger.info(
                        "Email binding confirmed (changed=\(data.changed), revertWindowOpened=\(data.revertWindowOpened), previousNotified=\(data.previousNotified))"
                    )

                    dispatch(.emailBinding(.set(.done(
                        email: data.email,
                        changed: data.changed,
                        previousNotified: data.previousNotified
                    ))))

                    // The address is the server's to write (§4.4), so the only way it reaches
                    // this device's `user_profile` row — and from there `AppState.userProfile`,
                    // and the screen the person is about to go back to — is a pull. §18.12 is
                    // right that nothing needs *reloading*; what it does need is the ordinary run
                    // to happen now rather than whenever the next one would have been.
                    if data.changed {
                        dispatch(.sync(.requested(.emailChanged)))
                    }

                } catch {
                    let bindingError = EmailBindingError.from(error)

                    // A burnt request has no code left to accept — three wrong tries, an expired
                    // one, or none on the account at all — so the screen hands back to the
                    // address rather than leaving a field that can only fail again. Everything
                    // else keeps the code screen and the address it belongs to: a wrong digit is
                    // a wrong digit, and `PENDING_ADDRESS_CHANGED` is answered by the newest
                    // letter, which is in the same mailbox (§18.4).
                    let next: EmailBindingState = bindingError.burnsPendingRequest
                        ? .entry(email: email, error: bindingError)
                        : .codeEntry(email: email, isChange: isChange, code: code, error: bindingError)

                    dispatch(.emailBinding(.set(next)))
                }
            }

        case .entry, .codeEntry, .done:
            break
        }
    }
}
