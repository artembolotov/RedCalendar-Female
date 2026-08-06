//
//  EmailAuthState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

enum EmailAuthState: Equatable, Sendable {
    case entry(
        email: String? = nil,
        error: AuthenticationError? = nil
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
