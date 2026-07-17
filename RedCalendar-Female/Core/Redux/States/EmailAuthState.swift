//
//  EmailAuthState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

enum EmailAuthState {
    case entry(
        email: String? = nil,
        error: Error? = nil
    )
    case checking(
        email: String,
        name: String? = nil
    )
    case codeEntry(
        email: String,
        code: String? = nil,
        userName: String? = nil,
        error: AuthenticationError? = nil
    )
    case verifying(
        email: String,
        code: String,
        name: String? = nil
    )
    case registration(
        email: String,
        code: String? = nil,
        name: String? = nil,
        error: AuthenticationError? = nil
    )
    case registering(
        email: String,
        code: String,
        name: String?
    )
}

// Manual Equatable: `entry` carries an untyped Error, compared by description —
// the UI only ever shows the description, so this is the observable identity.
extension EmailAuthState: Equatable {
    static func == (lhs: EmailAuthState, rhs: EmailAuthState) -> Bool {
        switch (lhs, rhs) {
        case (.entry(let lEmail, let lError), .entry(let rEmail, let rError)):
            return lEmail == rEmail
                && lError?.localizedDescription == rError?.localizedDescription
        case (.checking(let lEmail, let lName), .checking(let rEmail, let rName)):
            return lEmail == rEmail && lName == rName
        case (.codeEntry(let lEmail, let lCode, let lName, let lError),
              .codeEntry(let rEmail, let rCode, let rName, let rError)):
            return lEmail == rEmail && lCode == rCode && lName == rName && lError == rError
        case (.verifying(let lEmail, let lCode, let lName),
              .verifying(let rEmail, let rCode, let rName)):
            return lEmail == rEmail && lCode == rCode && lName == rName
        case (.registration(let lEmail, let lCode, let lName, let lError),
              .registration(let rEmail, let rCode, let rName, let rError)):
            return lEmail == rEmail && lCode == rCode && lName == rName && lError == rError
        case (.registering(let lEmail, let lCode, let lName),
              .registering(let rEmail, let rCode, let rName)):
            return lEmail == rEmail && lCode == rCode && lName == rName
        default:
            return false
        }
    }
}
