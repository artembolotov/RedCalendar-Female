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
    case deviceIdStorageFailed                    // Signed in, but device_id never reached the keychain
    case nameRequired                             // Name field is empty
    case emailVerificationFailed                  // Email verification failed
    
    // Network/Server errors
    case networkError(String)                     // Network connectivity issues
    case serverError(String)                      // Server-side errors
    case unknownError(String)                     // Fallback error
    
    var errorDescription: String? {
        switch self {
        case .phoneNotRegistered:
            return "Этот способ входа — только для пользователей RedCalendar 2.0. Новым пользователям нужно войти по email."
        case .phoneCallFailed:
            return "Не удалось запросить звонок для подтверждения. Попробуйте ещё раз."
        case .phoneVerificationFailed:
            return "Неверные цифры звонка. Попробуйте ещё раз."
        case .phoneCallTimeout:
            return "Звонок для подтверждения не пришёл. Запросите новый."
        case .emailNotFound:
            return "Такой email не найден. Проверьте адрес или зарегистрируйте новый аккаунт."
        case .emailAlreadyExists:
            return "Этот email уже зарегистрирован. Войдите вместо регистрации."
        case .passwordMismatch:
            return "Пароли не совпадают. Попробуйте ещё раз."
        case .invalidVerificationCode:
            return "Неверный код подтверждения. Попробуйте ещё раз."
        case .verificationCodeExpired:
            return "Код подтверждения истёк. Запросите новый."
        case .verificationCodeLimitExceeded:
            return "Слишком много попыток. Попробуйте позже."
        case .deviceIdStorageFailed:
            return "Не удалось завершить вход на этом устройстве. Попробуйте ещё раз."
        case .registrationFailed:
            return "Не удалось создать аккаунт. Попробуйте ещё раз."
        case .nameRequired:
            return "Введите имя."
        case .emailVerificationFailed:
            return "Не удалось подтвердить email. Попробуйте ещё раз."
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
            return .serverError(refusal?.displayMessage ?? "Too many requests. Please try again later.")
        case APIServiceError.serverUnavailable(let status, let message):
            return .serverError(message ?? "Server unavailable (HTTP \(status)).")
        case APIServiceError.networkError(let networkError):
            return .networkError(networkError.localizedDescription)
        default:
            return .unknownError(error.localizedDescription)
        }
    }
}
