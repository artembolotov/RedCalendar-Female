//
//  ConsentState.swift
//  RedCalendar-Female
//

/// Consent to the processing of personal data (SYNC.md §21): what the server last said about it,
/// and the two requests that ask it something.
///
/// Nothing here is a number the client decided. `required` is the last sync run's
/// `consent_required`, `current` is `GET /auth/consent`, and an acceptance carries back exactly
/// the version one of those two named.
struct ConsentState: Equatable, Sendable {
    /// `consent_required` from the last sync response. `nil` both when the current version is on
    /// record and before the first response of this launch has arrived.
    var required: Int?
    var current: Lookup = .idle
    var acceptance: Acceptance = .idle
    /// The version accepted on the consent step before sign-in — email, phone or the 2.0 migration
    /// (§21.4). While it is `nil` that step is what is on screen, and no sign-in request is sent.
    /// Left in place once signed in, so the sheet sliding away does not flash the step again; the
    /// sign-out that ends the session resets this whole state.
    var signInVersion: Int?
    /// The sign-in request a `CONSENT_OUTDATED` turned back, to be sent again unchanged — the same
    /// code included — once the newer version is accepted. The server checks the version before
    /// the code, so nothing of that request was spent. Also what tells the step to say the text
    /// has changed.
    var signInRetry: AuthState?

    enum Lookup: Equatable, Sendable {
        case idle
        case loading
        case loaded(version: Int)
        /// Why is in the log; the person's answer to any of it is the same retry.
        case failed
    }

    enum Acceptance: Equatable, Sendable {
        case idle
        case sending(version: Int)
        case accepted(version: Int)
        case refused(ConsentRefusal)
        case failed
    }
}
