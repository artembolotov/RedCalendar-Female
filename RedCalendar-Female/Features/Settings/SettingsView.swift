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
    @State private var isPresentingDeleteAccount = false

    private let devModeTapThreshold: CFTimeInterval = 0.5
    private let swatchSize: CGFloat = 22

    var body: some View {
        NavigationView {
            if let deviceId = store.state.deviceId {
                Form {
                    accountSection

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
                                && store.state.notifications.apnsToken != nil,
                            userName: store.state.userProfile?.name,
                            userEmail: store.state.userProfile?.email,
                            userPhoneNumber: store.state.userProfile?.phoneNumber
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

                    // Its own section and the system red, unlike the row above: this one really
                    // does destroy the account, not just the session, and the fourth-red argument
                    // that keeps "Выйти" tinted does not apply to it.
                    Section {
                        Button("Удалить аккаунт", role: .destructive) {
                            isPresentingDeleteAccount = true
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
                .sheet(isPresented: $isPresentingDeleteAccount) {
                    DeleteAccountSheet()
                }
            }
        }
    }

    // MARK: - Private Views

    // One navigable row, name over email — the Apple-ID-style header rather than a settings row
    // proper, and first on the screen for that reason: it identifies whose settings these are
    // before getting to what they are. The name line is left out entirely when there is none
    // (a device that has never had one pulled, or a 2.0 account that never set one) rather than
    // shown as a placeholder — unlike email, an unset name is not something this screen is asking
    // the user to go and fix.
    //
    // Email is always shown, real or as "Укажите email" — RedCalendar 2.0 accounts signed in by
    // phone can reach this screen with no email on the row at all, and that placeholder is what
    // tells them the row leads somewhere before the binding it promises actually exists.
    // `AccountView` is where that placeholder is explained; this row only names it.
    private var accountSection: some View {
        Section {
            NavigationLink {
                AccountView()
            } label: {
                let name = store.state.userProfile?.name.flatMap { $0.isEmpty ? nil : $0 }

                VStack(alignment: .leading, spacing: 2) {
                    if let name {
                        Text(name)
                    }
                    // Secondary and smaller under a name, same as the row leads with; standing
                    // alone with nothing above it, it is the row's only content and reads as such.
                    Text(store.state.userProfile?.email ?? "Укажите email")
                        .foregroundColor(name == nil ? .primary : .secondary)
                        .font(name == nil ? .body : .subheadline)
                }
                .padding(.vertical, 2)
            }
        }
    }

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

            // A row in the section's own content, not `footer:` — tried keeping the real footer
            // with `.fixedSize(horizontal: false, vertical: true)` on its text first (asks for
            // the ideal height directly instead of negotiating one with the table's proposed
            // size, the standard remedy for self-sizing table header/footer views coming back
            // wrong), and the jitter was unchanged. That rules out the footer's own content
            // sizing as the cause: a `Section` footer is a distinct supplementary view with a
            // relayout path separate from its rows', and it is that separate path — not how its
            // text sizes itself — that comes back from a background/foreground cycle unstable.
            // Nothing found lets that path be fixed directly (no in-app footer/table styling,
            // and this matches a documented class of footer self-sizing bugs on Apple's own
            // developer forums, just not this exact trigger) — folding the text into the same
            // pass as the row above it is what actually holds.
            Text("Количество дней от начала одной менструации до первого дня следующей.")
                .font(.footnote)
                .foregroundColor(.secondary)
        } header: {
            Text("Длина цикла")
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
    let userName: String?
    let userEmail: String?
    let userPhoneNumber: String?

    // The placeholder for a field the profile row simply has nothing in — a device never writes
    // `name`/`email`/`phone_number` itself (§4.4), so an unset one here means the server has
    // never sent a value, not that this screen failed to read it.
    //
    // `fileprivate`, not `private`: `Optional.orPlaceholder` below reads it from an extension on
    // a different type, and same-file `private` access only reaches extensions of the *same*
    // type, not another type's extension living in the same file.
    fileprivate static let unsetPlaceholder = "—"

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
                Text("Имя")
                Spacer()
                Text(userName.orPlaceholder)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack {
                Text("Почта")
                Spacer()
                Text(userEmail.orPlaceholder)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack {
                Text("Телефон")
                Spacer()
                Text(userPhoneNumber.orPlaceholder)
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

private extension Optional where Wrapped == String {
    // A field can also come back empty rather than absent — an empty string is not a value
    // either, so it gets the same dash a `nil` does.
    var orPlaceholder: String {
        guard let self, !self.isEmpty else { return DeveloperSectionView.unsetPlaceholder }
        return self
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
                    analyticsActivated: true,
                    userProfile: UserDetails(
                        userId: "test-user-id",
                        name: "Анна",
                        email: "anna@example.com",
                        phoneNumber: nil,
                        settings: nil
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}

#Preview("Без имени и email (RedCalendar 2.0)") {
    SettingsView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "test-device-id"),
                    notifications: NotificationState(
                        apnsToken: APNSToken(value: "test-token", isSynced: true),
                        pushPermissionState: .authorized
                    ),
                    analyticsActivated: true,
                    userProfile: UserDetails(
                        userId: "test-user-id",
                        name: nil,
                        email: nil,
                        phoneNumber: "+70000000000",
                        settings: nil
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
