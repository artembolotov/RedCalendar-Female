//
//  SettingsView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.07.2025.
//

import QuartzCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    @State private var versionTapCount = 0
    @State private var lastVersionTapTime: CFTimeInterval?

    private let devModeTapThreshold: CFTimeInterval = 0.5
    private let swatchSize: CGFloat = 22

    var body: some View {
        NavigationView {
            if let deviceId = store.state.deviceId {
                Form {
                    cycleLengthSection
                    periodLengthSection

                    accentThemeSection

                    Section("Теги") {
                        NavigationLink("Редактировать") {
                            TagsListView()
                        }
                    }

                    Section {
                        versionRow
                    }

                    if versionTapCount >= 8 {
                        DeveloperSectionView(
                            deviceId: deviceId,
                            todayDayStamp: store.state.calendarState.todayDayStamp,
                            analyticsActivated: store.state.analyticsActivated,
                            pushRegistered: store.state.notifications.pushPermissionState == .authorized
                                && store.state.notifications.apnsToken != nil
                        )
                    }

                    Section {
                        // The accent from the tint, not the system red a destructive button
                        // would take. Three rows above this one are reds the user chose between,
                        // and a fourth red answering to none of them reads as a fourth meaning.
                        // The warning that red would carry is not owed here anyway: logout drops
                        // the session, not the local database.
                        Button("Выйти") {
                            store.send(.auth(.logout))
                        }
                    }
                }
                .navigationTitle("Настройки")
                .navigationBarTitleDisplayMode(.inline)
                .closeButtonToolbar()
            }
        }
    }

    // MARK: - Private Views

    // The two values the calendar predicts with, first on the screen because they are the only
    // rows here that change what it draws.
    //
    // Committed on touch, with no Save button: every other row on this screen already works that
    // way, and there is nothing to confirm — the edit is local, reversible by the opposite tap,
    // and reported if it fails to save. The 2.0 screen this replaces did the same.
    //
    // Bound straight to the store rather than to `@State` seeded from it. The reducer applies the
    // edit synchronously (see `AppStore.send`), so the number moves in the same frame the stepper
    // does; a `@State` copy would additionally have to be kept honest against a value arriving
    // from another device, and against the rollback a failed write performs.
    private var cycleLengthSection: some View {
        Section {
            Stepper(
                value: cycleLengthBinding,
                in: Constants.Cycle.minCycleLength...Constants.Cycle.maxCycleLength
            ) {
                Text(Self.days(store.state.cycleSettings.cycleLength))
            }
            // The section header names the setting on screen but is not part of the control, so
            // VoiceOver would otherwise announce an adjustable "28 дней" belonging to nothing.
            .accessibilityLabel("Длина цикла")
            .accessibilityValue(Self.days(store.state.cycleSettings.cycleLength))
        } header: {
            Text("Длина цикла")
        } footer: {
            Text("Количество дней от начала одной менструации до первого дня следующей.")
        }
    }

    private var periodLengthSection: some View {
        Section("Длительность месячных") {
            Stepper(
                value: periodLengthBinding,
                in: Constants.Cycle.minPeriodLength...Constants.Cycle.maxPeriodLength
            ) {
                Text(Self.days(store.state.cycleSettings.periodLength))
            }
            .accessibilityLabel("Длительность месячных")
            .accessibilityValue(Self.days(store.state.cycleSettings.periodLength))
        }
    }

    // Nothing is dispatched on appear, and that is the point of writing the binding out rather
    // than reaching for `@State`. What the row shows is the stored value clamped into
    // `Constants.Cycle` — imported histories genuinely contain a `default_length` of 19, below
    // this app's own minimum (SYNC.md §4.5) — and clamping is a presentation decision until the
    // user touches the control. Only a tap writes.
    private var cycleLengthBinding: Binding<Int> {
        Binding(
            get: { store.state.cycleSettings.cycleLength },
            set: { store.send(.data(.setCycleLength($0))) }
        )
    }

    private var periodLengthBinding: Binding<Int> {
        Binding(
            get: { store.state.cycleSettings.periodLength },
            set: { store.send(.data(.setPeriodLength($0))) }
        )
    }

    /// «1 день», «2 дня», «5 дней» — the ordinary Russian rule, including the exception that
    /// 11 through 14 take the plural whatever their last digit is.
    private static func days(_ count: Int) -> String {
        let word: String
        switch (count % 100, count % 10) {
        case (11...14, _): word = "дней"
        case (_, 1):       word = "день"
        case (_, 2...4):   word = "дня"
        default:           word = "дней"
        }
        return "\(count) \(word)"
    }

    // Rows rather than a `Picker`: the thing being chosen is a colour, so each option has to
    // show its own colour at a size worth judging. A picker would collapse the three down to
    // their names.
    private var accentThemeSection: some View {
        Section("Оформление") {
            ForEach(AccentTheme.allCases) { theme in
                let isSelected = store.state.accentTheme == theme

                Button {
                    store.send(.appearance(.setAccentTheme(theme)))
                } label: {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: swatchSize, height: swatchSize)

                        Text(theme.title)
                            .foregroundColor(.primary)

                        Spacer()

                        // Always laid out, only faded: inserting and removing the glyph made the
                        // row taller the moment a theme was picked. Boxed to the swatch's size so
                        // it never drives the row height either — a checkmark's ascender is
                        // taller than the text line it sits next to.
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(theme.accent)
                            .frame(width: swatchSize, height: swatchSize)
                            .opacity(isSelected ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private var versionRow: some View {
        HStack {
            Text("Версия")
            Spacer()
            Text(Bundle.main.versionString)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard versionTapCount < 8 else { return }
            let now = CACurrentMediaTime()
            if let last = lastVersionTapTime, now - last > devModeTapThreshold {
                versionTapCount = 1
            } else {
                versionTapCount += 1
            }
            lastVersionTapTime = now
        }
    }

}

private struct DeveloperSectionView: View {
    let deviceId: String
    let todayDayStamp: Daystamp
    let analyticsActivated: Bool
    let pushRegistered: Bool

    var body: some View {
        Section("Developer") {
            HStack {
                Text("Device ID")
                Spacer()
                Text(deviceId)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack {
                Text("Today Daystamp")
                Spacer()
                Text("\(todayDayStamp.rawValue)")
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack {
                Text("AppMetrica")
                Spacer()
                statusCircle(active: analyticsActivated)
            }

            HStack {
                Text("Push-уведомления")
                Spacer()
                statusCircle(active: pushRegistered)
            }
        }
    }

    private func statusCircle(active: Bool) -> some View {
        Circle()
            .fill(active ? Color.green : Color.red)
            .frame(width: 10, height: 10)
    }
}

#Preview {
    SettingsView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "test-device-id"),
                    notifications: NotificationState(
                        apnsToken: APNSToken(value: "test-token", isSynced: true),
                        pushPermissionState: .authorized
                    ),
                    analyticsActivated: true
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
