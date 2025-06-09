//
//  AppState.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

struct AppState {
    var apnsToken: APNSToken?
    var authState: AuthState?
    var pushPermissionState: PushPermissionState?
}

extension AppState {
    var isAuthenticated: Bool {
        if case .authenticated = authState { true } else { false }
    }
}
