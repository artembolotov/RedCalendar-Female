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
    @Environment(\.dismiss) private var dismiss

    @State private var versionTapCount = 0
    @State private var lastVersionTapTime: CFTimeInterval?

    // What the steppers show while the user is still tapping, and `nil` whenever they are not —
    // see `cycleLength` below. The same shape `CommentSheetView` and `TagsSheetView` use: the
    // screen owns the value being edited, and the store hears about it once the tapping stops.
    @State private var draftCycleLength: Int?
    @State private var draftPeriodLength: Int?

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
                // Committed before the dismissal rather than after it, for the reason
                // `CommentSheetView` gives: `onDisappear` fires at the *end* of the dismiss
                // animation, and the calendar underneath would redraw its predictions a beat
                // after the screen it was changed on had gone.
                .closeButtonToolbar {
                    commitDrafts()
                    dismiss()
                }
                // The swipe down never reaches the close button, so this is the safety net for a
                // tap that fell inside the debounce window. Calling it twice costs nothing: the
                // guards compare against what the store already holds.
                .onDisappear(perform: commitDrafts)
                // One timer per stepper, restarted by every tap — `.task(id:)` cancels the
                // previous sleep — so only the pause after the last tap reaches the store. What
                // that buys is one transaction and one `dirty_seq` per settled value instead of
                // one per tap: holding a stepper from 28 to 90 is sixty-two taps, and every one
                // of them would otherwise be a GRDB write, a stamped row and a sync trigger.
                .task(id: draftCycleLength) { await commitAfterPause() }
                .task(id: draftPeriodLength) { await commitAfterPause() }
            }
        }
    }

    // MARK: - Private Views

    // The two values the calendar predicts with, first on the screen because they are the only
    // rows here that change what it draws.
    //
    // Saved by the pause after the last tap, with no Save button: the 2.0 screen this replaces
    // committed on touch, and so do the other editors here — the difference is only that the
    // intermediate values of a held stepper are worth no more than the intermediate values of a
    // half-typed comment, and neither is worth a transaction.
    private var cycleLengthSection: some View {
        Section {
            Stepper(
                value: cycleLengthBinding,
                in: Constants.Cycle.minCycleLength...Constants.Cycle.maxCycleLength
            ) {
                Text(cycleLength.russianDays)
            }
            // The section header names the setting on screen but is not part of the control, so
            // VoiceOver would otherwise announce an adjustable "28 дней" belonging to nothing.
            .accessibilityLabel("Длина цикла")
            .accessibilityValue(cycleLength.russianDays)
        } header: {
            Text("Длина цикла")
        } footer: {
            // `.fixedSize(vertical:)` because a `Section` footer is measured through its own
            // self-sizing pass, separate from its rows', and that pass came back from a
            // background/foreground cycle with a stale height that then animated to the correct
            // one, carrying every section below it along (this was the only section with a
            // footer, and the whole table below it visibly jittered). `.fixedSize` asks for the
            // text's own ideal height directly instead of negotiating one with the table's
            // proposed size — the standard fix for self-sizing table header/footer views that
            // come back wrong, going back to plain UIKit.
            Text("Количество дней от начала одной менструации до первого дня следующей.")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var periodLengthSection: some View {
        Section("Длительность месячных") {
            Stepper(
                value: periodLengthBinding,
                in: Constants.Cycle.minPeriodLength...Constants.Cycle.maxPeriodLength
            ) {
                Text(periodLength.russianDays)
            }
            .accessibilityLabel("Длительность месячных")
            .accessibilityValue(periodLength.russianDays)
        }
    }

    // The draft when there is one, the stored value otherwise — rather than a `@State` seeded on
    // appear, which would show its own placeholder for the first render pass and then have to be
    // kept honest afterwards. Falling back like this, the row shows the disk until the moment the
    // user touches it and their own value from then on.
    //
    // What the row shows before that is the stored value **clamped** into `Constants.Cycle`.
    // Nothing validates that column: §4.5 checks the profile for shape, not contents, so the
    // server will store and hand back any number a client ever wrote there. Clamping is therefore
    // a presentation decision — and it stays one until the user touches the control. Nothing is
    // dispatched on appear, and only a tap writes: a value this build would clamp is still the
    // value that person chose, and writing our version of it back is not ours to do.
    private var cycleLength: Int { draftCycleLength ?? store.state.cycleSettings.cycleLength }
    private var periodLength: Int { draftPeriodLength ?? store.state.cycleSettings.periodLength }

    private var cycleLengthBinding: Binding<Int> {
        Binding(get: { cycleLength }, set: { draftCycleLength = $0 })
    }

    private var periodLengthBinding: Binding<Int> {
        Binding(get: { periodLength }, set: { draftPeriodLength = $0 })
    }

    private func commitAfterPause() async {
        // `Task.sleep(for:)` is iOS 16+; the deployment target is 15.4, hence the nanoseconds
        // form. The same constant the comment and tag editors wait on — this is the same pause.
        try? await Task.sleep(nanoseconds: Constants.Sheets.autosaveDebounceNanoseconds)
        guard !Task.isCancelled else { return }
        commitDrafts()
    }

    /// Each half guarded against what the store already holds, so this is safe to call from all
    /// three places that call it and safe to call repeatedly. A draft equal to the stored value —
    /// tapped up and back down — is not an edit and dispatches nothing.
    private func commitDrafts() {
        if let draft = draftCycleLength, draft != store.state.cycleSettings.cycleLength {
            store.send(.data(.setCycleLength(draft)))
        }
        if let draft = draftPeriodLength, draft != store.state.cycleSettings.periodLength {
            store.send(.data(.setPeriodLength(draft)))
        }
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
