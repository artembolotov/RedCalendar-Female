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
