//
//  DeleteAccountSheet.swift
//  RedCalendar-Female
//

import SwiftUI

/// The destructive sheet SYNC.md §17.8 asks for: what gets deleted, that it is not instant, and
/// that logging back in during the grace period undoes it. No second confirmation behind it —
/// the button below *is* the confirmation, same conclusion §17.1 reaches for a code from email.
///
/// Deliberately the simple half of that section, not the two-step one: the exact date this build
/// could show only exists in the server's answer to the very request that starts the deletion, so
/// showing it would mean holding the person on a receipt screen after they already asked to leave.
/// The button below calls `.auth(.deleteAccount)` and that is the whole interaction — success or
/// failure, the sign-out that follows is unconditional (D4, the same trade `.logout` makes), so
/// there is nothing this screen could still be waiting to tell them once it has been tapped.
struct DeleteAccountSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.red)

                Text("DeleteAccount.Message")
                    .font(.body)

                Text(String.localized("DeleteAccount.Grace.Footer", Constants.Account.deletionGraceDays.localizedDays))
                    .font(.body)
                    .foregroundColor(.secondary)

                Spacer()

                PrimaryButton("DeleteAccount.Confirm.Button", accent: .red) {
                    store.send(.auth(.deleteAccount))
                    dismiss()
                }
            }
            .padding(20)
            .navigationTitle("DeleteAccount.Title")
            .navigationBarTitleDisplayMode(.inline)
            .closeButtonToolbar()
        }
    }
}

#Preview {
    DeleteAccountSheet()
        .environmentObject(
            AppStore(
                initialState: AppState(authState: .authenticated(deviceId: "test-device-id")),
                reducer: appReducer,
                middlewares: []
            )
        )
}
