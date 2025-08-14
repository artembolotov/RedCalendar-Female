//
//  AuthState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.06.2025.
//

enum AuthState {
    case notAuthenticated
    case authenticated(deviceId: String, userDetails: UserDetails?, calendarState: CalendarState)
    case migrating(userId: String, error: Error? = nil)
    case authenticating(AuthenticationMethod)
}
