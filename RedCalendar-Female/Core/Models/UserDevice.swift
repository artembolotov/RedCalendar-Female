//
//  UserDevice.swift
//  RedCalendar-Female
//

import Foundation

/// One session on the account — a row of `user_devices`, as `GET /auth/devices` reports it
/// (SYNC.md §19).
///
/// It is not a record: nothing about it is stored on this phone, and nothing syncs. The list is
/// server truth, read while the screen is open and dropped when it closes.
struct UserDevice: Equatable, Sendable, Identifiable {
    /// The session's `device_id`. Compared against `AppState.deviceId` to find this phone in the
    /// list — the server sends no flag for it, because a field repeating what the reader already
    /// knows is a field that can disagree with it.
    let id: String
    /// Already resolved by the server: "iPhone 16 Plus", or the bare identifier when its table
    /// does not know one yet (§19.1). Never empty.
    let name: String
    /// `last_seen_at`, written on every sync run (§4.3, step 5). `nil` for a device that signed
    /// in and never completed one — rare, since signing in starts an undebounced run, but the
    /// row then has nothing to show but its name.
    let lastSeenAt: Date?
}
