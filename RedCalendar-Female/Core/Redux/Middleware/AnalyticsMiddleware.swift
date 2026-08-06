//
//  AnalyticsMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

// MARK: - Analytics Middleware
let analyticsMiddleware: Middleware = { state, action, dispatch in
    @Injected var analytics: AnalyticsServiceProtocol
    
    switch action {

    case .checkAnalyticsStatus:
        return [.setAnalyticsActivated(analytics.isActivated)]

    default:
        break
    }
    
    return []
}
