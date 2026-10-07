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

    /// Off whenever the step appears, including after the text changed under a sign-in: an
    /// agreement given to the previous text is not one given to this.
    @State private var agreed = false

    let onAgree: (Int) -> Void

    private var accent: Color { store.state.accentTheme.accent }
    private var consent: ConsentState { store.state.consent }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 56))
                            .foregroundColor(accent)

                        Text("SignInConsent.Heading")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)

                        Text(subtitle)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }

                    VStack(spacing: 0) {
                        Link(destination: Constants.URLs.consent) {
                            HStack {
                                Text("SignInConsent.Document.Button")
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.footnote.weight(.semibold))
                            }
                            .padding()
                        }

                        Divider().padding(.leading)

                        Toggle("SignInConsent.Agree.Title", isOn: $agreed)
                            .padding()
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 24)

                    versionStatus

                    Spacer()

                    PrimaryButton("SignInConsent.Continue.Button", isEnabled: canContinue, accent: accent) {
                        if agreed, case .loaded(let version) = consent.current {
                            onAgree(version)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .frame(minHeight: geometry.size.height)
            }
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
                Text("SignInConsent.LoadFailed.Message")
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

    /// A step shown again because the text changed under a sign-in says so.
    private var subtitle: LocalizedStringKey {
        consent.signInRetry == nil ? "SignInConsent.Subtitle" : "SignInConsent.Outdated.Message"
    }

    private var canContinue: Bool {
        guard agreed, case .loaded = consent.current else { return false }
        return true
    }
}
