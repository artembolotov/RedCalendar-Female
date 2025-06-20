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
    case checking(email: String)
    case codeEntry(
        email: String,
        userName: String?,
        error: AuthenticationError?
    )
    case verifying(
        email: String,
        code: String
    )
    case registration(
        email: String,
        code: String?,
        error: AuthenticationError?
    )
    case registering(
        email: String,
        code: String,
        name: String
    )
}
