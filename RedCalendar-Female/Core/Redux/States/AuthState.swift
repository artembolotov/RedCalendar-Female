//
//  AuthState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.06.2025.
//

nonisolated enum AuthState: Equatable, Sendable {
    case notAuthenticated
    case authenticated(deviceId: String, userDetails: UserDetails?)
    case migrating(userId: String, error: MigrationError? = nil)
    case authenticating(AuthenticationMethod)
}
