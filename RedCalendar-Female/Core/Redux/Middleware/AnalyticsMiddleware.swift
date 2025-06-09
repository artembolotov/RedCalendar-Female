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
    
        
    default:
        break
    }
    
    return []
}
