//
//  FeedbackMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 16.06.2025.
//

import Foundation

// MARK: - Feedback Middleware
let feedbackMiddleware: Middleware<AppState, AppAction> = { state, action, dispatch in
    @Injected var feedbackService: TapticFeedbackServiceProtocol
    
    switch action {
    
    // MARK: - Success Events
    case .setAuthState(.authenticated):
        feedbackService.playSuccess()
        
    case .logout:
        feedbackService.prepare()
        
    default:
        break
    }
    
    return []
}
