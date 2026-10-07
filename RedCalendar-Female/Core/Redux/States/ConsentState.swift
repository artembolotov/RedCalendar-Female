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

    enum Lookup: Equatable, Sendable {
        case idle
        case loading
        case loaded(version: Int)
        /// The error's description, for the log-shaped places that show it; the person's answer
        /// to any of them is the same retry.
        case failed(String)
    }

    enum Acceptance: Equatable, Sendable {
        case idle
        case sending(version: Int)
        case accepted(version: Int)
        case refused(ConsentRefusal)
        case failed(String)
    }
}
