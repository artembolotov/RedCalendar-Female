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
/// The name field is the one thing here that can actually be edited today; the email section
/// under it is a placeholder for the binding/change flow SYNC.md leaves undesigned (that work
/// needs the server too, see `Constants` and this file's own comments below).
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

            // No control here yet — only a report of what the row on Settings already showed.
            // Linking or changing the email needs the server (checking it is free, changing it on
            // an account that already has one is not), so this section is a placeholder until
            // that work exists rather than a disabled-looking field promising something the app
            // cannot do.
            Section {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(store.state.userProfile?.email ?? "Укажите email")
                        .foregroundColor(.secondary)
                }
            } footer: {
                Text("Привязка и изменение email появятся здесь позже.")
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
        .sheet(isPresented: $isPresentingDeleteAccount) {
            DeleteAccountSheet()
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
    private func commitDrafts() {
        if let draft = draftName {
            let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            // An empty field clears the name rather than storing `""` — the same tombstone shape
            // every other soft-deleted field in this app uses (see `DatabaseService.updateName`).
            if trimmed != (store.state.userProfile?.name ?? "") {
                store.send(.data(.setName(trimmed.isEmpty ? nil : trimmed)))
            }
        }
        if let draft = draftCycleLength, draft != store.state.cycleSettings.cycleLength {
            store.send(.data(.setCycleLength(draft)))
        }
        if let draft = draftPeriodLength, draft != store.state.cycleSettings.periodLength {
            store.send(.data(.setPeriodLength(draft)))
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
