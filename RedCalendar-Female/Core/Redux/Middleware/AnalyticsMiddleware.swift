//
//  AnalyticsMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

// MARK: - Analytics Middleware
let analyticsMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
    @Injected var analytics: AnalyticsServiceProtocol
    
    switch action {
    case .login:
        analytics.trackEvent("user_login")
    case .logout:
        analytics.trackEvent("user_logout")
    case .migrationCompleted:
        analytics.trackEvent("migration_completed")
    case .migrationFailed:
        analytics.trackEvent("migration_failed")
    default:
        break
    }
    
    return []
}
