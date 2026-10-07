//
//  AccountDeletedRefusal.swift
//  RedCalendar-Female
//

import Foundation

/// `410 ACCOUNT_DELETED` (SYNC.md §17.5): the account behind a phone number or a legacy id was
/// purged. `check-phone`, `verify-flash-call` and `migrate` all answer it, and no retry of any of
/// them can end differently — the way on is a new account.
///
/// Read out of `APIServiceError.refused` here and nowhere else, for the reason `ConsentRefusal` is.
struct AccountDeletedRefusal: Equatable, Sendable {
    /// The server's own text, already in the app's language (`X-App-Language`).
    let message: String

    init?(_ error: Error) {
        guard case APIServiceError.refused(let refusal) = error,
              refusal.error == "ACCOUNT_DELETED" else { return nil }
        message = refusal.displayMessage
    }
}
