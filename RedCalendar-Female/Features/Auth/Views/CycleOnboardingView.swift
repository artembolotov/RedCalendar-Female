//
//  CycleOnboardingView.swift
//  RedCalendar-Female
//

import SwiftUI

/// Shown once, right after a brand-new email registration finishes — never on a returning login,
/// and never for phone auth. `RootView` reaches this from `AuthState.authenticated`'s
/// `isFreshRegistration` flag, which only `AuthMiddleware` sets, only from
/// `EmailAuthState.registering`.
///
/// Phone sign-in has no registration path to begin with: `checkPhone` on an unknown number
/// answers `.phoneNotRegistered` (an error, not a way in — see `PhoneAuthState`), because
/// RedCalendar 2.0 was phone-only. Reaching this app by phone therefore always means an existing
/// 2.0 account, and its `settings` already crossed over verbatim during the Firebase import
/// (SYNC.md §10.2 — `user.settings` → `users_female.settings`, same shape) before this device
/// ever pulled it. Asking again here would ask a returning person to guess what they already told
/// the old app. A brand-new email account is the one case with nothing to migrate from.
struct CycleOnboardingView: View {
    @EnvironmentObject var store: AppStore

    @State private var cycleLength = Constants.Cycle.defaultCycleLength
    @State private var periodLength = Constants.Cycle.defaultPeriodLength
    /// On by default, like the two numbers above are at their fallbacks: this screen exists to
    /// turn silent defaults into an answer somebody actually gave.
    @State private var notificationsEnabled = true

    private var accent: Color { store.state.accentTheme.accent }

    /// iOS has already been told no for this install, so the switch would be a promise nothing
    /// can keep. It is left out of the screen rather than shown greyed out: a first-run screen is
    /// the wrong place to explain a setting the person cannot act on from here, and nothing is
    /// written for it either — an account whose profile carries no `notifications` key still
    /// means "on", which is the right answer for the phone they read this on next.
    /// `SettingsView` is where the explanation and the way out live.
    private var canOfferNotifications: Bool { !store.state.notifications.isBlockedBySystem }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 56))
                    .foregroundColor(accent)

                Text("Расскажите о своём цикле")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("Это нужно для прогнозов в календаре — можно ответить примерно, значения всегда можно будет изменить в настройках.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 0) {
                onboardingRow(
                    title: "Длина цикла",
                    value: $cycleLength,
                    bounds: Constants.Cycle.minCycleLength...Constants.Cycle.maxCycleLength
                )

                Divider().padding(.leading)

                onboardingRow(
                    title: "Длительность месячных",
                    value: $periodLength,
                    bounds: Constants.Cycle.minPeriodLength...Constants.Cycle.maxPeriodLength
                )

                if canOfferNotifications {
                    Divider().padding(.leading)

                    Toggle("Уведомления", isOn: $notificationsEnabled)
                        .padding()
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .padding(.horizontal, 24)

            Spacer()

            PrimaryButton("Продолжить", accent: accent, action: complete)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color("AppBackgroundColor"))
    }

    // MARK: - Private Views

    // Same split as `SettingsView`'s rows: a caption names the setting, the stepper's own label
    // shows only the value, and `accessibilityLabel` reunites the two for VoiceOver — a stepper
    // announcing a bare "28 дней" belongs to nothing without it.
    @ViewBuilder
    private func onboardingRow(title: String, value: Binding<Int>, bounds: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Stepper(value: value, in: bounds) {
                Text(value.wrappedValue.russianDays)
            }
            .accessibilityLabel(title)
            .accessibilityValue(value.wrappedValue.russianDays)
        }
        .padding()
    }

    // MARK: - Private Methods

    private func complete() {
        // Written even though nobody may have touched a stepper: unlike `SettingsView`, where
        // writing an unedited value would spend a sync revision for nothing, there is no stored
        // value yet here for "unchanged" to mean anything against. Tapping through with the
        // defaults is the choice being asked for — it is what turns the silent 28/5 fallback into
        // something this person actually confirmed.
        store.send(.data(.setCycleLength(cycleLength)))
        store.send(.data(.setPeriodLength(periodLength)))
        // The system permission alert follows from this, and not from a call here: the write
        // comes back through the profile observation as `.enabled`, and
        // `PushNotificationsMiddleware` asks iOS on the strength of that. So the prompt appears
        // once the calendar is on screen — after this screen has done its job — and it appears by
        // the same rule that covers a switch flicked in Settings a month from now, or on another
        // phone entirely.
        if canOfferNotifications {
            store.send(.data(.setNotificationsEnabled(notificationsEnabled)))
        }
        store.send(.auth(.completedRegistrationOnboarding))
    }
}

// MARK: - Preview

#Preview {
    CycleOnboardingView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "test-device-id", isFreshRegistration: true)
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
