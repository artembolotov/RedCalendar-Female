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
    /// Where the spinner for the version goes: top-leading either way, but the sign-in sheet has a
    /// navigation bar with that slot free, and the step in front of a migration has no bar at all.
    enum IndicatorPlacement {
        case navigationBar
        case topRow
    }

    @EnvironmentObject var store: AppStore

    let indicatorPlacement: IndicatorPlacement
    let onAgree: (Int) -> Void

    @State private var isIndicatorVisible = false

    private var consent: ConsentState { store.state.consent }

    var body: some View {
        switch indicatorPlacement {
        case .navigationBar:
            form
                .modifier(LeadingIndicatorToolbar(isIndicatorVisible: isIndicatorVisible) {
                    indicator
                })
        case .topRow:
            // Above the form rather than over it, as the consent prompt's menu row is: the form
            // scrolls on a small screen or at a large text size.
            VStack(spacing: 0) {
                HStack {
                    indicator
                        .padding()

                    Spacer()
                }

                form
            }
        }
    }

    // MARK: - Private Views

    private var form: some View {
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
            loadFailure
        }
        .onAppear {
            // Read when the step is shown. Not again over a version already here: after a
            // `CONSENT_OUTDATED` the refusal itself named the current one.
            if case .idle = consent.current {
                store.send(.consent(.fetchCurrent))
            }
        }
    }

    private var indicator: some View {
        DelayedProgressView(
            isActive: isLoading,
            appearDelayNanoseconds: Constants.Consent.indicatorAppearDelayNanoseconds,
            tint: store.state.accentTheme.accent,
            isVisible: $isIndicatorVisible
        )
    }

    // The wait itself is `indicator`, not a view here: a spinner put into the form and taken out
    // again moved everything below it.
    @ViewBuilder
    private var loadFailure: some View {
        switch consent.current {
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
        case .idle, .loading, .loaded:
            EmptyView()
        }
    }

    // MARK: - Private Methods

    private var isLoading: Bool {
        switch consent.current {
        case .idle, .loading: true
        case .failed, .loaded: false
        }
    }

    private var loadedVersion: Int? {
        if case .loaded(let version) = consent.current { version } else { nil }
    }
}

/// Same reason as `DevicesToolbar` (`DevicesView.swift`): `.sharedBackgroundVisibility` (iOS 26+)
/// is a `ToolbarContent` modifier, and the glass behind an item is keyed off whether it has content
/// at all, so the `.toolbar {}` call itself has to branch on `#available` to hide it while idle.
private struct LeadingIndicatorToolbar<Indicator: View>: ViewModifier {
    let isIndicatorVisible: Bool
    @ViewBuilder let indicator: Indicator

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    indicator
                }
                .sharedBackgroundVisibility(isIndicatorVisible ? .visible : .hidden)
            }
        } else {
            content.toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    indicator
                }
            }
        }
    }
}
