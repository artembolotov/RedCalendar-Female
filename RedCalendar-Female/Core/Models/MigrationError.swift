//
//  MigrationError.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

/// Lives here rather than next to `MigrationMiddleware` because `AuthState.migrating` carries it:
/// a state type may not reach into a middleware file for its payload.
///
/// `serverError` is also the catch-all. The middleware's `do` block can throw anything —
/// `APIServiceError`, a `URLError`, a decoding failure — and `AuthState` has to stay `Sendable`,
/// which an untyped `any Error` is not. Wrapping the description loses nothing the UI had: it only
/// ever renders `errorDescription`, which is why the old hand-written `==` compared these by
/// `localizedDescription` in the first place.
nonisolated enum MigrationError: Error, LocalizedError, Equatable, Sendable {
    case noUserIdFound
    case keychainSaveError
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .noUserIdFound:
            return "No user ID found for migration"
        case .keychainSaveError:
            return "Failed to save device ID to keychain"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

nonisolated extension MigrationError {
    /// Passes a `MigrationError` through unchanged and wraps everything else.
    static func from(_ error: any Error) -> MigrationError {
        error as? MigrationError ?? .serverError(error.localizedDescription)
    }
}
