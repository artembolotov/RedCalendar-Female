//
//  PhoneAuthState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

enum PhoneAuthState {
    case entry                                        // Enter phone number
    case requesting(phoneNumber: String)              // Requesting flash call
    case verification(                               // Waiting for call verification
        phoneNumber: String,
        maskedCallerNumber: String,                  // e.g., "+7 XXX XXX XX34"
        error: AuthenticationError? = nil
    )
    case verifying(                                  // Verifying entered digits
        phoneNumber: String,
        verificationCode: String
    )
}
