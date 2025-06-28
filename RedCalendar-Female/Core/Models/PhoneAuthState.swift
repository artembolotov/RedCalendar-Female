//
//  PhoneAuthState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

enum PhoneAuthState {
    case entry(
        prettyPhoneNumber: String? = nil,
        error: AuthenticationError? = nil
    )
    case requesting(
        prettyPhoneNumber: String,
        e164PhoneNumber: String,
    )
    case verification(
        prettyPhoneNumber: String,
        e164PhoneNumber: String,
        maskedCallerNumber: String,
        error: AuthenticationError? = nil
    )
    case verifying(
        prettyPhoneNumber: String,
        e164PhoneNumber: String,
        verificationCode: String
    )
}
