//
//  AuthenticationError.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import Foundation

enum AuthenticationError: Error, LocalizedError, Equatable {
    // Phone errors
    case phoneNotRegistered                        // Not a RedCalendar 2.0 user
    case phoneCallFailed                          // Flash call request failed
    case phoneVerificationFailed                  // Wrong verification digits
    case phoneCallTimeout                         // Call didn't arrive

    // Code verification errors
    case invalidVerificationCode                  // Wrong 6-digit code
    case verificationCodeExpired                  // Code expired
    case verificationCodeLimitExceeded            // Too many attempts

    // Registration errors
    case registrationFailed                       // Account creation failed
    case deviceIdStorageFailed                    // Signed in, but device_id never reached the keychain
    case emailVerificationFailed                  // Email verification failed
    
    // Network/Server errors
    case networkError(String)                     // Network connectivity issues
    case serverError(String)                      // Server-side errors
    case unknownError(String)                     // Fallback error
    
    // Key per case, mechanically: the type's name and the case's own. Nothing to invent, and a
    // case added without a string is visible in the same glance as the switch itself.
    var errorDescription: String? {
        switch self {
        case .phoneNotRegistered:
            return String(localized: "AuthError.PhoneNotRegistered")
        case .phoneCallFailed:
            return String(localized: "AuthError.PhoneCallFailed")
        case .phoneVerificationFailed:
            return String(localized: "AuthError.PhoneVerificationFailed")
        case .phoneCallTimeout:
            return String(localized: "AuthError.PhoneCallTimeout")
        case .invalidVerificationCode:
            return String(localized: "AuthError.InvalidVerificationCode")
        case .verificationCodeExpired:
            return String(localized: "AuthError.VerificationCodeExpired")
        case .verificationCodeLimitExceeded:
            return String(localized: "AuthError.VerificationCodeLimitExceeded")
        case .deviceIdStorageFailed:
            return String(localized: "AuthError.DeviceIdStorageFailed")
        case .registrationFailed:
            return String(localized: "AuthError.RegistrationFailed")
        case .emailVerificationFailed:
            return String(localized: "AuthError.EmailVerificationFailed")
        case .networkError(let message):
            return message
        case .serverError(let message):
            return message
        case .unknownError(let message):
            return message
        }
    }
}

extension AuthenticationError {
    static func from(_ error: Error) -> AuthenticationError {
        switch error {
        // Already one of ours — thrown by a sign-in path that failed on something other than the
        // network. Passing it through keeps its case; the `default` below would flatten it into
        // `.unknownError` and lose everything but the string.
        case let authError as AuthenticationError:
            return authError

        case APIServiceError.serverError(let message):
            return .serverError(message)
        // The refusal is carried whole now (see `APIServiceError.refused`), but nothing on the
        // sign-in paths tells one code from another — the message is what it always was.
        case APIServiceError.refused(let refusal):
            return .serverError(refusal.displayMessage)
        case APIServiceError.rateLimited(_, let refusal):
            return .serverError(refusal?.displayMessage ?? String(localized: "AuthError.RateLimited"))
        case APIServiceError.serverUnavailable(let status, let message):
            return .serverError(message ?? String.localized("AuthError.ServerUnavailable", status))
        case APIServiceError.networkError(let networkError):
            return .networkError(networkError.localizedDescription)
        default:
            return .unknownError(error.localizedDescription)
        }
    }
}
