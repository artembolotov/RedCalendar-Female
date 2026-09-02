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

                Divider().padding(.leading)

                // Shown and written whatever iOS has already been told on this phone: the answer
                // belongs to the account, not to the device, and a person who has denied
                // notifications here still gets to say what their next one does. `SettingsView`
                // is where a phone-level refusal is explained, because that is where somebody
                // wondering why nothing arrives will go looking.
                Toggle("Уведомления", isOn: $notificationsEnabled)
                    .padding()
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
        for action in CycleOnboardingCommit.actions(
            cycleLength: cycleLength,
            periodLength: periodLength,
            notificationsEnabled: notificationsEnabled
        ) {
            store.send(action)
        }
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

// MARK: - Commit

/// The onboarding screen's single commit, as an ordered list — extracted from the view only so
/// that the order can be pinned by a test, because the order is what makes it correct.
///
/// Each of the three writes comes back as its own profile observation, and
/// `.completedRegistrationOnboarding` has already cleared `isFreshRegistration` by the time the
/// first one lands: the reducer runs synchronously, the observation does not. A delivery carrying
/// the cycle numbers and no `notifications` key resolves to `NotificationPreference.enabled`, by
/// the rule that silence means on (every account imported from RedCalendar 2.0 is that shape),
/// and that is enough for `PushNotificationsMiddleware` to put the system alert on screen. So
/// somebody who had just switched notifications *off* here was asked anyway, a moment before
/// their own answer reached the observation. The switch goes first so that the first delivery is
/// the one carrying what they chose.
///
/// The alert follows from that write rather than from a call at the tap: the value comes back
/// through the profile observation and the middleware decides on the strength of it, so the
/// prompt appears once the calendar is on screen — by the same rule that covers a switch flicked
/// in Settings a month from now, or on another phone.
///
/// The two numbers are written even though nobody may have touched a stepper: unlike
/// `SettingsView`, where writing an unedited value would spend a sync revision for nothing, there
/// is no stored value yet here for "unchanged" to mean anything against. Tapping through with the
/// defaults is the choice being asked for — it is what turns the silent 28/5 fallback into
/// something this person actually confirmed.
enum CycleOnboardingCommit {
    static func actions(cycleLength: Int, periodLength: Int, notificationsEnabled: Bool) -> [AppAction] {
        [
            .data(.setNotificationsEnabled(notificationsEnabled)),
            .data(.setCycleLength(cycleLength)),
            .data(.setPeriodLength(periodLength)),
            .auth(.completedRegistrationOnboarding)
        ]
    }
}
