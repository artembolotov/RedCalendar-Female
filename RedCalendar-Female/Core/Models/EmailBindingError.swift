//
//  EmailBindingError.swift
//  RedCalendar-Female
//

import Foundation

/// What can go wrong while binding an address to the account, or changing the one it has
/// (SYNC.md §18.4). Its own type rather than more cases on `AuthenticationError`: these arrive
/// from a person who is already signed in, and three of them exist only here — an address held
/// by somebody else, a request overtaken from a second device, and a code that ran out of tries.
///
/// Concrete like every other error in the state tree, for the reason `AppState`'s own comment
/// gives: it is stored in `EmailBindingState`, and an `any Error` payload there would take the
/// synthesized `==` with it.
enum EmailBindingError: Error, LocalizedError, Equatable {
    /// The single arbiter of an address being free is the `UNIQUE` at the moment of the write
    /// (§18.1), so this can arrive from *either* step: the check before the code is sent, and
    /// again after the code comes back, if somebody won the race in between.
    ///
    /// `availableAfter` is set only when the holder is an account inside its deletion grace
    /// period. Without the date, a person frees the address by deleting their other account and
    /// walks straight back into this same refusal with nothing to explain why (§18.5).
    case emailTaken(availableAfter: Date?)
    case invalidEmail
    /// A code for a *different* address was requested from another device after this letter went
    /// out. Its own case, and its own text, because "неверный код" on a correct code is the kind
    /// of screen people re-read three times (§18.4).
    case pendingAddressChanged
    case invalidCode(remainingAttempts: Int?)
    case codeExpired
    /// Three wrong codes burn the request — the next step is a new one, not another try.
    case tooManyAttempts
    /// No request on the account at all: it expired, or it was already spent.
    case requestNotFound
    /// Both budgets of §18.10 land here — the per-address one and the per-user one — and so does
    /// a failed occupancy check, which deliberately costs the same as a send.
    case rateLimited(String?)
    /// A 401. The device token is still being sent, and the account behind it is gone.
    case accountUnavailable
    case networkError(String)
    /// Anything the server explained that this build has no branch for, its message included.
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .emailTaken(let availableAfter):
            if let availableAfter {
                return "Этот адрес принадлежит аккаунту, который удаляется. Он освободится после \(Self.dateText(availableAfter))."
            }
            return "Этот адрес уже используется другим аккаунтом RedCalendar. Войдите в тот аккаунт или укажите другой адрес."
        case .invalidEmail:
            return "Неверный формат email."
        case .pendingAddressChanged:
            return "Код запрашивали для другого адреса. Введите код из последнего письма или запросите новый."
        case .invalidCode(let remainingAttempts):
            guard let remainingAttempts, remainingAttempts > 0 else { return "Неверный код." }
            return "Неверный код. Осталось попыток: \(remainingAttempts)."
        case .codeExpired:
            return "Код истёк. Запросите новый."
        case .tooManyAttempts:
            return "Слишком много попыток. Запросите новый код."
        case .requestNotFound:
            return "Код не найден. Запросите новый."
        case .rateLimited(let message):
            return message ?? "Слишком много запросов. Попробуйте позже."
        case .accountUnavailable:
            return "Аккаунт недоступен. Войдите в приложение заново."
        case .networkError(let message), .serverError(let message):
            return message
        }
    }

    /// Whether the pending request is gone and the flow has to start over from the address. The
    /// code screen has nothing left to accept in these three, so it hands back to the entry
    /// screen rather than leaving a field that can only fail.
    var burnsPendingRequest: Bool {
        switch self {
        case .tooManyAttempts, .codeExpired, .requestNotFound: true
        default: false
        }
    }
}

extension EmailBindingError {
    /// Reads the server's refusal *code*, not its message. The messages are already localized by
    /// `X-App-Language` and would render fine — what they cannot do is decide where the screen
    /// goes next, which is the whole reason `APIServiceError.refused` carries the envelope.
    static func from(_ error: Error) -> EmailBindingError {
        switch error {
        case let bindingError as EmailBindingError:
            return bindingError

        // `validateHTTPResponse` turns every 401 into this before the body is read, so the
        // server's own `USER_NOT_FOUND` and a device token that is simply no longer valid arrive
        // as the same thing — and they have the same answer.
        case APIServiceError.unauthorized:
            return .accountUnavailable

        case APIServiceError.refused(let refusal):
            switch refusal.error {
            case "EMAIL_TAKEN":
                return .emailTaken(availableAfter: refusal.availableAfter.flatMap(parseTimestamp))
            case "INVALID_EMAIL", "MISSING_EMAIL":
                return .invalidEmail
            case "PENDING_ADDRESS_CHANGED":
                return .pendingAddressChanged
            case "INVALID_CODE", "INVALID_CODE_FORMAT", "MISSING_CODE":
                return .invalidCode(remainingAttempts: refusal.remainingAttempts)
            case "CODE_EXPIRED":
                return .codeExpired
            case "TOO_MANY_ATTEMPTS":
                return .tooManyAttempts
            case "TOKEN_NOT_FOUND":
                return .requestNotFound
            case "RATE_LIMITED":
                return .rateLimited(refusal.message)
            case "USER_NOT_FOUND":
                return .accountUnavailable
            default:
                return .serverError(refusal.displayMessage)
            }

        // 429 is thrown before the 4xx branch and carries the same envelope, so the two codes
        // that can arrive under it are read here rather than lost to a generic "too many".
        case APIServiceError.rateLimited(_, let refusal):
            if refusal?.error == "TOO_MANY_ATTEMPTS" { return .tooManyAttempts }
            return .rateLimited(refusal?.message)

        case APIServiceError.networkError(let networkError):
            return .networkError(networkError.localizedDescription)

        case APIServiceError.serverError(let message):
            return .serverError(message)

        default:
            return .serverError(error.localizedDescription)
        }
    }

    /// The server sends `toISOString()`, which always carries milliseconds — but the formatter
    /// without `.withFractionalSeconds` rejects exactly that, so both are tried.
    private static func parseTimestamp(_ value: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func dateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
