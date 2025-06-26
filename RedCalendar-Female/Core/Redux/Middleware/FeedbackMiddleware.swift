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
    case .setAuthState(.authenticating(.email(.entry(_, .some(_))))),
         .setAuthState(.authenticating(.email(.registration(_, _, _, .some(_))))),
         .setAuthState(.authenticating(.email(.codeEntry(_, _, _, .some(_))))):
        feedbackService.playError()
        
    // MARK: - Prepare Events
    case .logout,
        .setAuthState(.authenticating(.email(.checking))),
        .setAuthState(.authenticating(.email(.registering(_, _, _)))),
        .setAuthState(.authenticating(.email(.verifying(_, _, _)))):
        
        feedbackService.prepare()
        
    default:
        break
    }
    
    return []
}
