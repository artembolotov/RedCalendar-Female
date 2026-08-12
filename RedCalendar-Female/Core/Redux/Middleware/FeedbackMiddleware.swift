//
//  FeedbackMiddleware.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 16.06.2025.
//

import Foundation

// MARK: - Feedback Middleware
//
// Observes every domain and owns none, so it matches the cases it plays a tick for and takes a
// `default` for the rest. An exhaustive switch here would be a list of everything the app can do,
// annotated with silence.
let feedbackMiddleware: Middleware = { state, action, dispatch in
    @Injected var feedbackService: TapticFeedbackServiceProtocol

    switch action {

    // MARK: - Success Events
//    case .auth(.set(.authenticated)):

        //feedbackService.playSuccess()

    // MARK: - Selection Events
    // Only a day being chosen, never one being let go: dismissing the card is also a
    // `.selectDay(nil)`, and a tick for tapping empty space is a tick for nothing.
    case .calendar(.selectDay(.some)):

        feedbackService.playSelection()

    // MARK: - Error Events
    case .auth(.set(.authenticating(.email(.entry(_, .some(_)))))),
         .auth(.set(.authenticating(.email(.registration(_, _, _, .some(_)))))),
         .auth(.set(.authenticating(.email(.codeEntry(_, _, _, .some(_)))))),
         .auth(.set(.authenticating(.phone(.entry(_, .some(_)))))),
         .auth(.set(.authenticating(.phone(.verification(_, _, _, _, .some(_)))))),
         // A write the database refused is the same kind of event: something the user did did
         // not take, and they are about to be told so.
         .data(.writeFailed):

        feedbackService.playError()

    // MARK: - Prepare Events
    case .auth(.logout),
        .auth(.set(.authenticating(.email(.checking)))),
        .auth(.set(.authenticating(.email(.registering(_, _, _))))),
        .auth(.set(.authenticating(.email(.verifying(_, _, _))))),
        .auth(.set(.authenticating(.phone(.requesting(_, _))))),
        .auth(.set(.authenticating(.phone(.verifying(_, _, _, _, _))))):

        feedbackService.prepare()

    default:
        break
    }

}
