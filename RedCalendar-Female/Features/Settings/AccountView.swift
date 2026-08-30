//
//  AccountView.swift
//  RedCalendar-Female
//

import SwiftUI

/// Pushed from `SettingsView`'s account row — the name field first, because it is the one thing
/// here that can actually be edited today; the email section under it is a placeholder for the
/// binding/change flow SYNC.md leaves undesigned (that work needs the server too, see
/// `Constants` and this file's own comments below).
struct AccountView: View {
    @EnvironmentObject var store: AppStore

    // Same shape `SettingsView`'s steppers hold their drafts in: `nil` until the user has typed
    // something, so the field shows the stored name (or nothing) until touched and the user's own
    // text from then on, and a value equal to what is already stored commits nothing.
    @State private var draftName: String?
    @FocusState private var isNameFieldFocused: Bool

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
        }
        .navigationTitle("Аккаунт")
        .navigationBarTitleDisplayMode(.inline)
        // No close button to commit from — this is a push, not a sheet — so `onDisappear` (the
        // swipe-back included) is the only safety net for a tap that fell inside the debounce
        // window, same as `SettingsView`'s own belt-and-braces call.
        .onDisappear(perform: commitDraft)
        .task(id: draftName) { await commitAfterPause() }
    }

    // MARK: - Private Methods

    // The stored name, or nothing, until the draft says otherwise — see `SettingsView.cycleLength`
    // for the same fallback and the same reason: nothing is dispatched on appear, only on a real
    // edit.
    private var name: String { draftName ?? (store.state.userProfile?.name ?? "") }

    private var nameBinding: Binding<String> {
        Binding(get: { name }, set: { draftName = $0 })
    }

    private func commitAfterPause() async {
        // The constant the comment, tag and cycle-settings editors already wait on.
        try? await Task.sleep(nanoseconds: Constants.Sheets.autosaveDebounceNanoseconds)
        guard !Task.isCancelled else { return }
        commitDraft()
    }

    /// Guarded against what the store already holds, so this is safe to call from both places
    /// that call it and safe to call repeatedly — the same guard `SettingsView.commitDrafts` uses.
    private func commitDraft() {
        guard let draft = draftName else { return }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (store.state.userProfile?.name ?? "") else { return }
        // An empty field clears the name rather than storing `""` — the same tombstone shape
        // every other soft-deleted field in this app uses (see `DatabaseService.updateName`).
        store.send(.data(.setName(trimmed.isEmpty ? nil : trimmed)))
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        AccountView()
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
        AccountView()
            .environmentObject(
                AppStore(
                    initialState: AppState(authState: .authenticated(deviceId: "test-device-id")),
                    reducer: appReducer,
                    middlewares: []
                )
            )
    }
}
