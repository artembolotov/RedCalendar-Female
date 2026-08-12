//
//  AnalyticsMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

// MARK: - Analytics Middleware
let analyticsMiddleware: Middleware = { state, action, dispatch in
    @Injected var analytics: AnalyticsServiceProtocol

    guard case .analytics(let analyticsAction) = action else { return }

    switch analyticsAction {

    case .checkStatus:
        dispatch(.analytics(.setActivated(analytics.isActivated)))

    case .setActivated:
        break
    }
}
