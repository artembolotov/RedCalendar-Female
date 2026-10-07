//
//  ConsentFormView.swift
//  RedCalendar-Female
//

import SwiftUI

/// The consent form (SYNC.md §21): the link to the text, the switch and the button. Drawn by both
/// screens that ask for consent — the step before sign-in and the prompt after it — so the wording
/// a person agrees to is one set of strings, not two that could drift.
///
/// It knows nothing about where the version came from or what agreeing sends; the caller says
/// whether there is something to agree to yet (`isReady`) and what to do once agreed.
struct ConsentFormView<Status: View>: View {
    let accent: Color
    /// The text changed while this person was reading it, and the form says so.
    let isOutdated: Bool
    /// Off while there is no version to agree to, or while an answer is on its way.
    let isReady: Bool
    let onAgree: () -> Void
    let status: Status

    /// Off whenever the form appears, including after the text changed: an agreement given to the
    /// previous text is not one given to this.
    @State private var agreed = false

    init(
        accent: Color,
        isOutdated: Bool,
        isReady: Bool,
        onAgree: @escaping () -> Void,
        @ViewBuilder status: () -> Status
    ) {
        self.accent = accent
        self.isOutdated = isOutdated
        self.isReady = isReady
        self.onAgree = onAgree
        self.status = status()
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()

                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield")
                            .font(.system(size: 56))
                            .foregroundColor(accent)

                        Text("Consent.Heading")
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
                                Text("Consent.Document.Button")
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.footnote.weight(.semibold))
                            }
                            .padding()
                        }

                        Divider().padding(.leading)

                        Toggle("Consent.Agree.Title", isOn: $agreed)
                            .padding()
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal, 24)

                    status

                    Spacer()

                    PrimaryButton("Consent.Continue.Button", isEnabled: agreed && isReady, accent: accent) {
                        if agreed && isReady {
                            onAgree()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
                .frame(minHeight: geometry.size.height)
            }
        }
    }

    // MARK: - Private Methods

    private var subtitle: LocalizedStringKey {
        isOutdated ? "Consent.Outdated.Message" : "Consent.Subtitle"
    }
}
