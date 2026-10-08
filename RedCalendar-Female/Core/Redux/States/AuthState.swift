//
//  AuthState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.06.2025.
//

enum AuthState: Equatable {
    case notAuthenticated
    /// `isFreshRegistration` is true for exactly one dispatch: the moment `AuthMiddleware`
    /// finishes a brand-new email registration (`EmailAuthState.registering`). It is what tells
    /// `RootView` to show `CycleOnboardingView` instead of `HomeView` — every other route to this
    /// case (a returning login, a phone sign-in, `.check` on cold launch, `MigrationMiddleware`)
    /// leaves it at the default `false`. Not persisted anywhere but this run's Redux state: a
    /// force-quit before the onboarding screen's button is tapped lands on `HomeView` on the next
    /// launch, showing the same silent 28/5 fallback every build before this one already did.
    case authenticated(deviceId: String, isFreshRegistration: Bool = false)
    case migrating(userId: String, error: MigrationError? = nil)
    case authenticating(AuthenticationMethod)
}

/// Which way out of the session is under way, between the request and the `.notAuthenticated`
/// that ends it. The first one asked for is the one taken: a deletion asked for after a sign-out
/// would go out under the device id that sign-out has just revoked, be answered 401 — read as
/// "already gone" — and leave the account unmarked.
///
/// The screens that offer either one stop offering both while it is set, and `AuthMiddleware`
/// ignores the other one if it arrives anyway. Nothing else checks it: the wipe and the rest of
/// what `.logout` and `.deleteAccount` set off are the same for both, so a second action only
/// repeats them. Neither does anything hold back a repeat of the *same* one, which can only come
/// from a second tap inside the frame before the button is drawn disabled.
enum SessionEnding: Equatable, Sendable {
    case signOut
    case deletion
}
