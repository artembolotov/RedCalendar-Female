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
    
    // MARK: - Error Events
    case .setAuthState(.authenticating(.email(.entry(_, let error)))) where error != nil:
        feedbackService.playError()
        
    // MARK: - Prepare Events
    case .logout,
        .setAuthState(.authenticating(.email(.checking))):
        feedbackService.prepare()
        
    default:
        break
    }
    
    return []
}
