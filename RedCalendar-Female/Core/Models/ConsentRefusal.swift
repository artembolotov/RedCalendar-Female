//
//  ConsentRefusal.swift
//  RedCalendar-Female
//

import Foundation

/// The two refusals every endpoint that takes a consent version answers alike (SYNC.md §21.3):
/// the three sign-ins and `POST /auth/consent`.
///
/// Read out of `APIServiceError.refused` here and nowhere else, so that the sign-in screens, the
/// migration and the prompt after sign-in all agree on what the server said. Both refusals are
/// answered before anything is spent — an emailed code, a Flash Call attempt — so the request
/// that drew one can be sent again as it was, with the version named here.
enum ConsentRefusal: Equatable, Sendable {
    /// `409 CONSENT_OUTDATED`: a newer text was published while the person was reading. They have
    /// to read it and accept `version`, which is the current one.
    case outdated(version: Int)
    /// `400 INVALID_CONSENT_VERSION`: the request carried no version, or one the server never had.
    /// A client bug, not something the person can answer; `version` is the current one.
    case invalid(version: Int?)

    init?(_ error: Error) {
        guard case APIServiceError.refused(let refusal) = error else { return nil }

        switch refusal.error {
        // Without the version there is nothing to send back, so it is not a refusal this can act on.
        case "CONSENT_OUTDATED":
            guard let version = refusal.data?.version else { return nil }
            self = .outdated(version: version)
        case "INVALID_CONSENT_VERSION":
            self = .invalid(version: refusal.data?.version)
        default:
            return nil
        }
    }
}
