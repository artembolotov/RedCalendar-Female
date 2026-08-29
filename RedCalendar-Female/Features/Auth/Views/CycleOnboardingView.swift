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
