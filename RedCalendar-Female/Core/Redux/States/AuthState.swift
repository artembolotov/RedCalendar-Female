//
//  AuthState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.06.2025.
//

enum AuthState: Equatable {
    case notAuthenticated
    case authenticated(deviceId: String)
    case migrating(userId: String, error: MigrationError? = nil)
    case authenticating(AuthenticationMethod)
}
