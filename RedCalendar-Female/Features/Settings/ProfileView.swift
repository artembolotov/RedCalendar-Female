//
//  ProfileView.swift
//  RedCalendar-Female
//

import SwiftUI

/// Pushed from `SettingsView`'s profile row. Everything that identifies the account or shapes
/// how the calendar predicts lives here — name, email, the two cycle numbers, and the account's
/// own destructive action — rather than spread across the top-level Settings list next to
/// unrelated rows like the theme picker and the sign-out button.
///
/// The name and the two cycle numbers are edited in place, debounced; the email row opens the
/// two-step flow of SYNC.md §18 in a sheet, because it is not an edit this device may make — the
/// address is written by the server, against a code sent to it, and only reaches this screen back
/// down the sync pull.
struct ProfileView: View {
    @EnvironmentObject var store: AppStore

    // Same shape `SettingsView`'s steppers used to hold their drafts in, and still do here: `nil`
    // until the user has touched the control, so each field shows the stored value (or nothing)
    // until then and the user's own edit from that point on. A draft equal to what is already
    // stored commits nothing — see `commitDrafts` below.
    @State private var draftName: String?
    @State private var draftCycleLength: Int?
    @State private var draftPeriodLength: Int?
    @FocusState private var isNameFieldFocused: Bool

    @State private var isPresentingDeleteAccount = false

    var body: some View {
        Form {
            Section {
                TextField("Имя", text: nameBinding)
                    .textContentType(.name)
                    .autocapitalization(.words)
                    .disableAutocorrection(true)
                    .submitLabel(.done)
                    .focused($isNameFieldFocused)
                    .onSubmit { isNameFieldFocused = false }
            } header: {
                Text("Имя")
            }

            // The row opens the flow of SYNC.md §18 — one sheet for both edges of it, because
            // binding an address and changing the one on the account are the same write to the
            // same column and the same endpoint answers both.
            //
            // The placeholder value is red rather than the usual `.secondary`: unlike the name
            // field, an unset email is not merely incomplete, it is a countdown, and the value
            // should look like one from the moment the screen opens rather than only once the
            // person has read as far as the footer.
            Section {
                Button {
                    store.send(.emailBinding(.set(.entry())))
                } label: {
                    HStack {
                        Text("Email")
                            .foregroundColor(.primary)
                        Spacer()
                        if let email = store.state.userProfile?.email {
                            Text(email)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Укажите email")
                                .foregroundColor(.red)
                        }
                        // The chevron a `NavigationLink` would have drawn for itself. This is a
                        // sheet rather than a push — the flow has its own two-step back — so the
                        // affordance has to be put back by hand.
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }
            } footer: {
                if store.state.userProfile?.email == nil {
                    // Phone sign-in is on the way out (SYNC.md §12, items 14–16 retire Firebase
                    // and the phone lookup it backs) — an account with no email on file is an
                    // account with no way back in once that lands.
                    Text("Скоро вход по номеру телефона перестанет работать. Привяжите email, чтобы сохранить доступ к аккаунту.")
                } else {
                    Text("По этому адресу вы входите в аккаунт.")
                }
            }

            cycleLengthSection
            periodLengthSection

            // Its own section and the system red: this really does destroy the account, not just
            // the session `SettingsView`'s "Выйти" ends, and it sits at the bottom of the one
            // screen the account's own identity and cycle data live on, rather than next to
            // unrelated rows like the accent picker.
            Section {
                Button("Удалить аккаунт", role: .destructive) {
                    isPresentingDeleteAccount = true
                }
            }
        }
        .navigationTitle("Профиль")
        .navigationBarTitleDisplayMode(.inline)
        // No close button to commit from — this is a push, not a sheet — so `onDisappear` (the
        // swipe-back included) is the only safety net for a tap that fell inside the debounce
        // window, for all three drafts below.
        .onDisappear(perform: commitDrafts)
        .task(id: draftName) { await commitAfterPause() }
        .task(id: draftCycleLength) { await commitAfterPause() }
        .task(id: draftPeriodLength) { await commitAfterPause() }
        // A draft outlives its own write on purpose, and is dropped here — when the write comes
        // back down the profile observation and the store agrees with it. Dropping it in
        // `commitDrafts` instead would put the stored value back on screen for the length of the
        // GRDB round trip, so a stepper would count down again under the finger.
        //
        // Held any longer than that, a draft stops describing an edit and starts overwriting one.
        // These two numbers have a writer that is not the user: the forecast measured off the
        // recorded cycles (`CycleForecast`), which a pull from another device can land at any
        // moment this screen is open. A draft equal to what is already stored would then hide the
        // new value here and `onDisappear` would commit the old one back over it.
        .onChange(of: store.state.cycleSettings) { settings in
            if draftCycleLength == settings.cycleLength { draftCycleLength = nil }
            if draftPeriodLength == settings.periodLength { draftPeriodLength = nil }
        }
        // The same for the name, whose other writer is the same pull. Trimmed on both sides of
        // the comparison, and against `""` for the cleared name, so it matches what
        // `commitDrafts` actually sent.
        .onChange(of: store.state.userProfile?.name) { name in
            guard let draft = draftName else { return }
            if draft.trimmingCharacters(in: .whitespacesAndNewlines) == (name ?? "") { draftName = nil }
        }
        .sheet(isPresented: $isPresentingDeleteAccount) {
            DeleteAccountSheet()
        }
        // Presented from the state rather than from a local flag, for the reason
        // `EmailBindingView` gives: the flow outlives the sheet — a confirmation that lands has a
        // sync run to ask for. Dismissing by swipe therefore has to clear the state too, which is
        // what the binding's setter is for.
        .sheet(isPresented: emailBindingPresented) {
            EmailBindingView()
        }
    }

    // MARK: - Private Views

    // The two values the calendar predicts with. Ported from `SettingsView` verbatim — same
    // debounce, same clamped-for-display fallback, same reasoning: see `cycleLength` below.
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

            // A row in the section's own content, not `footer:` — see `SettingsView`'s original
            // comment on this same text for why: a `Section` footer's relayout path comes back
            // from a background/foreground cycle unstable in a way folding the text into the row
            // above does not.
            //
            // The forecast note is folded into this sentence rather than stacked under it: two
            // rows in the same footnote grey, with a separator between them, read as one
            // paragraph broken in half. `periodLengthSection` has no description to fold into and
            // carries the note as a row of its own.
            Text("Количество дней от начала одной менструации до первого дня следующей. \(Self.forecastNote)")
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

            Text(Self.forecastNote)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    /// Both numbers are measured back off the recorded cycles once there are enough of them
    /// (`CycleForecast`), so a value typed here can change by itself once a later cycle is
    /// recorded. Said in both sections, and said before it happens: a number that moves on its
    /// own reads as an edit that failed to save unless the screen has already claimed it as
    /// behaviour.
    ///
    /// Present tense and no threshold in the wording, because the sentence has to be true on both
    /// sides of one: for the person whose value is already being measured, and for the person
    /// whose first cycles are still governed by the number they typed.
    private static let forecastNote = "Значение уточняется автоматически по отмеченным циклам."

    // MARK: - Private Methods

    // The stored name, or nothing, until the draft says otherwise — see `cycleLength` below for
    // the same fallback and the same reason: nothing is dispatched on appear, only on a real edit.
    private var name: String { draftName ?? (store.state.userProfile?.name ?? "") }

    // What the row shows before the user touches it is the stored value **clamped** into
    // `Constants.Cycle`. Nothing validates that column: §4.5 checks the profile for shape, not
    // contents, so the server will store and hand back any number a client ever wrote there.
    // Clamping is therefore a presentation decision — and it stays one until the user touches the
    // control. Nothing is dispatched on appear, and only a tap writes: a value this build would
    // clamp is still the value that person chose, and writing our version of it back is not ours
    // to do.
    private var cycleLength: Int { draftCycleLength ?? store.state.cycleSettings.cycleLength }
    private var periodLength: Int { draftPeriodLength ?? store.state.cycleSettings.periodLength }

    private var emailBindingPresented: Binding<Bool> {
        Binding(
            get: { store.state.emailBinding != nil },
            set: { isPresented in
                if !isPresented, store.state.emailBinding != nil {
                    store.send(.emailBinding(.set(nil)))
                }
            }
        )
    }

    private var nameBinding: Binding<String> {
        Binding(get: { name }, set: { draftName = $0 })
    }

    private var cycleLengthBinding: Binding<Int> {
        Binding(get: { cycleLength }, set: { draftCycleLength = $0 })
    }

    private var periodLengthBinding: Binding<Int> {
        Binding(get: { periodLength }, set: { draftPeriodLength = $0 })
    }

    private func commitAfterPause() async {
        // The constant the comment and tag editors wait on too.
        try? await Task.sleep(nanoseconds: Constants.Sheets.autosaveDebounceNanoseconds)
        guard !Task.isCancelled else { return }
        commitDrafts()
    }

    /// Each draft guarded against what the store already holds, so this is safe to call from all
    /// four places that call it and safe to call repeatedly. A draft equal to the stored value is
    /// not an edit and dispatches nothing.
    ///
    /// Such a draft is dropped here instead, because the `onChange` above cannot reach it: with
    /// nothing dispatched there is no write, no observation and no change of store for it to
    /// watch — and tapping + and back to − is enough to produce one. Dropping it costs nothing
    /// visually, since it holds the value already on screen, and leaving it would let a stale
    /// draft outlive the edit it never was.
    private func commitDrafts() {
        if let draft = draftName {
            let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            // An empty field clears the name rather than storing `""` — the same tombstone shape
            // every other soft-deleted field in this app uses (see `DatabaseService.updateName`).
            if trimmed != (store.state.userProfile?.name ?? "") {
                store.send(.data(.setName(trimmed.isEmpty ? nil : trimmed)))
            } else {
                draftName = nil
            }
        }
        if let draft = draftCycleLength {
            if draft != store.state.cycleSettings.cycleLength {
                store.send(.data(.setCycleLength(draft)))
            } else {
                draftCycleLength = nil
            }
        }
        if let draft = draftPeriodLength {
            if draft != store.state.cycleSettings.periodLength {
                store.send(.data(.setPeriodLength(draft)))
            } else {
                draftPeriodLength = nil
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        ProfileView()
            .environmentObject(
                AppStore(
                    initialState: AppState(
                        authState: .authenticated(deviceId: "test-device-id"),
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
}

#Preview("Без имени и email") {
    NavigationView {
        ProfileView()
            .environmentObject(
                AppStore(
                    initialState: AppState(authState: .authenticated(deviceId: "test-device-id")),
                    reducer: appReducer,
                    middlewares: []
                )
            )
    }
}
