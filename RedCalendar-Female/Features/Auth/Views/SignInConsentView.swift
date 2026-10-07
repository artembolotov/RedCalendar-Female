//
//  SignInConsentView.swift
//  RedCalendar-Female
//

import SwiftUI

/// The consent step in front of every sign-in (SYNC.md §21.4): the first screen of the sign-in
/// sheet, and what an upgrading RedCalendar 2.0 install sees before it is migrated.
///
/// The version is read from the server when the step appears, never kept in the app, and the
/// sign-in carries back exactly that number. Until it has arrived there is nothing to agree to, so
/// the button stays off — a sign-in is never sent without one. What happens after agreeing differs
/// between the two places this is shown, so it is the caller's `onAgree`.
struct SignInConsentView: View {
    @EnvironmentObject var store: AppStore

    let onAgree: (Int) -> Void

    private var consent: ConsentState { store.state.consent }

    var body: some View {
        ConsentFormView(
            accent: store.state.accentTheme.accent,
            isOutdated: consent.signInRetry != nil,
            isReady: loadedVersion != nil,
            onAgree: {
                if let loadedVersion {
                    onAgree(loadedVersion)
                }
            }
        ) {
            versionStatus
        }
        .onAppear {
            // Read when the step is shown. Not again over a version already here: after a
            // `CONSENT_OUTDATED` the refusal itself named the current one.
            if case .idle = consent.current {
                store.send(.consent(.fetchCurrent))
            }
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var versionStatus: some View {
        switch consent.current {
        case .idle, .loading:
            ProgressView()
        case .failed:
            VStack(spacing: 12) {
                Text("Consent.LoadFailed.Message")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Button("Common.Retry") {
                    store.send(.consent(.fetchCurrent))
                }
            }
            .padding(.horizontal, 32)
        case .loaded:
            EmptyView()
        }
    }

    // MARK: - Private Methods

    private var loadedVersion: Int? {
        if case .loaded(let version) = consent.current { version } else { nil }
    }
}
