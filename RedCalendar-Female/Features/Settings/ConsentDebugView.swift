//
//  ConsentDebugView.swift
//  RedCalendar-Female
//

import SwiftUI

/// Developer → Consent: the consent requests (SYNC.md §21), driven by hand before any sign-in or
/// prompt depends on them. Temporary — it goes once the consent flows are in place.
///
/// Developer-only like the section it is reached from, so it is English and `Text(verbatim:)`
/// throughout, and nothing here reaches Localizable.xcstrings.
struct ConsentDebugView: View {
    @EnvironmentObject var store: AppStore

    private var consent: ConsentState { store.state.consent }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text(verbatim: "Current version")
                    Spacer()
                    currentValue
                }

                HStack {
                    Text(verbatim: "consent_required (last sync)")
                    Spacer()
                    Text(verbatim: consent.required.map(String.init) ?? "null")
                        .foregroundColor(.secondary)
                }

                Button {
                    store.send(.consent(.fetchCurrent))
                } label: {
                    Text(verbatim: "Reload current version")
                }
            } header: {
                Text(verbatim: "Server")
            }

            Section {
                Button {
                    if case .loaded(let version) = consent.current {
                        store.send(.consent(.accept(version: version)))
                    }
                } label: {
                    Text(verbatim: "Accept current")
                }
                .disabled(!canAcceptCurrent)

                Button {
                    store.send(.consent(.accept(version: 0)))
                } label: {
                    Text(verbatim: "Send invalid (0)")
                }
                .disabled(isSending)

                Link(destination: Constants.URLs.consent) {
                    Text(verbatim: "Open text")
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "Last result")
                    Spacer()
                    Text(verbatim: acceptanceText)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text(verbatim: "Accept")
            }

            Section {
                Toggle(isOn: promptEnabled) {
                    Text(verbatim: "Show prompt on consent_required")
                }

                // An account that already accepted gets `null` from every run, so this is the
                // only way to see the prompt there. Local only: the next run puts the server's
                // answer back, and accepting sends the current version, which is idempotent.
                Button {
                    if case .loaded(let version) = consent.current {
                        store.send(.consent(.setRequired(version)))
                    }
                } label: {
                    Text(verbatim: "Set consent_required to current locally")
                }
                .disabled(!isCurrentLoaded)
            } header: {
                Text(verbatim: "Prompt")
            }
        }
        .navigationTitle(Text(verbatim: "Consent"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.consent(.fetchCurrent))
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var currentValue: some View {
        switch consent.current {
        case .idle:
            Text(verbatim: "—")
                .foregroundColor(.secondary)
        case .loading:
            ProgressView()
        case .loaded(let version):
            Text(verbatim: "\(version)")
                .foregroundColor(.secondary)
        case .failed(let message):
            Text(verbatim: message)
                .foregroundColor(.red)
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Private Methods

    private var promptEnabled: Binding<Bool> {
        Binding(
            get: { consent.promptEnabled },
            set: { store.send(.consent(.setPromptEnabled($0))) }
        )
    }

    private var isCurrentLoaded: Bool {
        if case .loaded = consent.current { true } else { false }
    }

    private var isSending: Bool {
        if case .sending = consent.acceptance { true } else { false }
    }

    private var canAcceptCurrent: Bool {
        isCurrentLoaded && !isSending
    }

    private var acceptanceText: String {
        switch consent.acceptance {
        case .idle:
            "—"
        case .sending(let version):
            "Sending \(version)…"
        case .accepted(let version):
            "Accepted \(version)"
        case .refused(.outdated(let version)):
            "CONSENT_OUTDATED, current \(version)"
        case .refused(.invalid(let version)):
            "INVALID_CONSENT_VERSION, current \(version.map(String.init) ?? "—")"
        case .failed(let message):
            message
        }
    }
}
