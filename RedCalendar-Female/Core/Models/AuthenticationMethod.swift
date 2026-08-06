//
//  AuthenticationMethod.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

enum AuthenticationMethod: Equatable {
    case phone(PhoneAuthState)
    case email(EmailAuthState)
}
