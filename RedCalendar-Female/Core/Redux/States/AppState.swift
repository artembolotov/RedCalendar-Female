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
    var analyticsActivated: Bool = false
}

extension AppState {
    var isAuthenticated: Bool {
        if case .authenticated = authState { true } else { false }
    }
}
