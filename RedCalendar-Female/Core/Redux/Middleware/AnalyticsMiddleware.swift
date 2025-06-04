//
//  AnalyticsMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

// MARK: - Analytics Middleware
let analyticsMiddleware: Middleware<AppState, AppAction> = { state, action in
    @Injected var analytics: AnalyticsServiceProtocol
    
    switch action {
    case .login:
        analytics.trackEvent("user_login")
    case .logout:
        analytics.trackEvent("user_logout")
    default:
        break
    }
    
    return []
}
