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
    
    // Email errors
    case emailNotFound                            // Email doesn't exist (new user)
    case emailAlreadyExists                       // Email taken during registration
    
    case passwordMismatch                         // Password confirmation doesn't match
    
    // Code verification errors
    case invalidVerificationCode                  // Wrong 6-digit code
    case verificationCodeExpired                  // Code expired
    case verificationCodeLimitExceeded            // Too many attempts
    
    // Registration errors
    case registrationFailed                       // Account creation failed
    case nameRequired                             // Name field is empty
    case emailVerificationFailed                  // Email verification failed
    
    // Network/Server errors
    case networkError(String)                     // Network connectivity issues
    case serverError(String)                      // Server-side errors
    case unknownError(String)                     // Fallback error
    
    var errorDescription: String? {
        switch self {
        case .phoneNotRegistered:
            return "This feature is only for RedCalendar 2.0 users. New users should sign in with email."
        case .phoneCallFailed:
            return "Failed to request verification call. Please try again."
        case .phoneVerificationFailed:
            return "Incorrect verification digits. Please try again."
        case .phoneCallTimeout:
            return "Verification call didn't arrive. Please request a new call."
        case .emailNotFound:
            return "Email not found. Please check or create a new account."
        case .emailAlreadyExists:
            return "This email is already registered. Please sign in instead."
        case .passwordMismatch:
            return "Passwords don't match. Please try again."
        case .invalidVerificationCode:
            return "Invalid verification code. Please try again."
        case .verificationCodeExpired:
            return "Verification code has expired. Please request a new one."
        case .verificationCodeLimitExceeded:
            return "Too many attempts. Please try again later."
        case .registrationFailed:
            return "Failed to create account. Please try again."
        case .nameRequired:
            return "Please enter your name."
        case .emailVerificationFailed:
            return "Failed to verify email. Please try again."
        case .networkError(let message):
            return "\(message)"
        case .serverError(let message):
            return "\(message)"
        case .unknownError:
            return "An unknown error occurred. Please try again."
        }
    }
}

extension AuthenticationError {
    static func from(_ error: Error) -> AuthenticationError {
        switch error {
        case APIServiceError.serverError(let message):
            return .serverError(message)
        case APIServiceError.networkError(let networkError):
            return .networkError(networkError.localizedDescription)
        default:
            return .unknownError(error.localizedDescription)
        }
    }
}
