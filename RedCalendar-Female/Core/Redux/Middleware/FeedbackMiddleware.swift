//
//  FeedbackMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 16.06.2025.
//

import Foundation

// MARK: - Feedback Middleware
let feedbackMiddleware: Middleware = { state, action, dispatch in
    @Injected var feedbackService: TapticFeedbackServiceProtocol
    
    switch action {
    
    // MARK: - Success Events
//    case .setAuthState(.authenticated):
        
        //feedbackService.playSuccess()
    
    // MARK: - Selection Events
    // Only a day being chosen, never one being let go: dismissing the card is also a
    // `.setSelectedDayStamp(nil)`, and a tick for tapping empty space is a tick for nothing.
    case .setSelectedDayStamp(.some):

        feedbackService.playSelection()

    // MARK: - Error Events
    case .setAuthState(.authenticating(.email(.entry(_, .some(_))))),
         .setAuthState(.authenticating(.email(.registration(_, _, _, .some(_))))),
         .setAuthState(.authenticating(.email(.codeEntry(_, _, _, .some(_))))),
         .setAuthState(.authenticating(.phone(.entry(_, .some(_))))),
         .setAuthState(.authenticating(.phone(.verification(_, _, _, _, .some(_))))):
        
        feedbackService.playError()
        
    // MARK: - Prepare Events
    case .logout,
        .setAuthState(.authenticating(.email(.checking))),
        .setAuthState(.authenticating(.email(.registering(_, _, _)))),
        .setAuthState(.authenticating(.email(.verifying(_, _, _)))),
        .setAuthState(.authenticating(.phone(.requesting(_, _)))),
        .setAuthState(.authenticating(.phone(.verifying(_, _, _, _, _)))):
        
        feedbackService.prepare()
        
    default:
        break
    }
    
}
