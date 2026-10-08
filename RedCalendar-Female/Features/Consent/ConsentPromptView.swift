//
//  ConsentPromptView.swift
//  RedCalendar-Female
//

import SwiftUI

/// The answer to `consent_required` (SYNC.md §21.5): a signed-in account that has not accepted the
/// current version — a session issued before §21, or one that predates a raised version.
///
/// `RootView` draws it in place of `HomeView` rather than presenting it over it. Home presents
/// sheets of its own, and on iOS 15 a second presentation asked for while one is up is refused
/// without a word; a screen in the root's place cannot be refused, and nothing gets past it. Sync
/// goes on underneath all the while — the server does not block it (§21.3), and the run is what
/// takes this screen down once the acceptance is on record.
///
/// Unlike the step before sign-in, this one is shown to someone who already has an account and
/// data in it, so it says the text changed and leaves them a way out other than agreeing: the
/// support address, and signing out or deleting the account, kept behind a menu.
struct ConsentPromptView: View {
    @EnvironmentObject var store: AppStore

    @State private var isPresentingDeleteAccount = false

    /// What `consent_required` named, or what a `CONSENT_OUTDATED` named since.
    let version: Int

    private var acceptance: ConsentState.Acceptance { store.state.consent.acceptance }

    var body: some View {
        ConsentFormView(
            accent: store.state.accentTheme.accent,
            // Whether a version was raised or a newer one landed while reading, the text the person
            // agreed to before is not the one in front of them now.
            isOutdated: true,
            isReady: !isSending,
            onAgree: {
                store.send(.consent(.accept(version: version)))
            }
        ) {
            VStack(spacing: 16) {
                status

                Text("Consent.Support.Footer")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        // A newer version is a new agreement, so the switch starts off again.
        .id(version)
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Consent.SignOut.Button") {
                    store.send(.auth(.logout))
                }

                Button("Consent.DeleteAccount.Button", role: .destructive) {
                    isPresentingDeleteAccount = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .imageScale(.large)
                    .foregroundColor(.secondary)
                    .padding()
            }
            .accessibilityLabel(Text("Consent.More.A11y"))
        }
        .background(Color("AppBackgroundColor"))
        .sheet(isPresented: $isPresentingDeleteAccount) {
            DeleteAccountSheet()
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var status: some View {
        switch acceptance {
        case .sending:
            ProgressView()
        // An invalid version is ours to fix, not the person's; what they can do is the same retry.
        case .failed, .refused(.invalid):
            Text("Consent.SendFailed.Message")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        case .idle, .accepted, .refused(.outdated):
            EmptyView()
        }
    }

    // MARK: - Private Methods

    private var isSending: Bool {
        if case .sending = acceptance { true } else { false }
    }
}
