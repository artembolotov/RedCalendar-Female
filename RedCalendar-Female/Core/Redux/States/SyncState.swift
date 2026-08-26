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
