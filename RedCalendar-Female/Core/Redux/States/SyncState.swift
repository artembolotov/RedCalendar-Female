//
//  SyncState.swift
//  RedCalendar-Female
//

import Foundation

/// What the sync indicator (SYNC.md §9, §12 item 12) will draw, and nothing more.
///
/// **Offline is not an error.** The app is built to work without a network, so a run that could
/// not reach the server is `.pending` — there is something to send and it will go when it can —
/// and never `.failed`. `.failed` is kept for the case the user genuinely cannot wait out: a 4xx
/// on the whole request, which retrying does not fix (§5.7).
///
/// A rejected *row* appears nowhere here. The server won that argument and its version is already
/// on the disk; there is nothing for the user to decide.
enum SyncState: Equatable, Sendable {
    case idle
    case syncing
    case pending
    case failed
}

extension SyncState {
    /// The two rows of §9's table the Firebase import owns (§10.4): a run that ends while the
    /// server is still importing stays `.syncing` instead of dropping to an idle indicator over
    /// an empty calendar, and an import that failed is a warning rather than "there is nothing".
    ///
    /// The status stays a `String` on the wire and in `sync_state` — a value this build does not
    /// know has to survive the round trip rather than be rewritten to one it does — so it is
    /// interpreted here and nowhere else. Anything unrecognised, `done` and `nil` included, is
    /// `.idle`: the run itself succeeded, and that is all the indicator has left to say.
    init(afterImport status: String?) {
        switch status {
        case "running": self = .syncing
        case "failed": self = .failed
        default: self = .idle
        }
    }
}
