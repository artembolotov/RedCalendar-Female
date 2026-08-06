//
//  AuthenticationMethod.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

nonisolated enum AuthenticationMethod: Equatable, Sendable {
    case phone(PhoneAuthState)
    case email(EmailAuthState)
}
