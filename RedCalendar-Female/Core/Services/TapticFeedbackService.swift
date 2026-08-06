//
//  TapticFeedbackService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 16.06.2025.
//

import UIKit

// MARK: - TapticFeedbackService Protocol

/// Main-actor isolated because a `UIFeedbackGenerator` may only be touched from the main
/// thread, and this is now the whole of that guarantee.
///
/// It used to be enforced by hand — every method routed through a private `onMain` that
/// checked `Thread.isMainThread` and hopped if it had to — because `Middleware` was an
/// unisolated `async` type and every haptic in the app was therefore raised from the
/// cooperative pool. Off the main thread the generator's activation bookkeeping races and
/// the process is killed with `_UIFeedbackCoreHapticsHapticsOnlyEngine _internal_deactivate
/// called more times than the feedback engine was activated`. Now that `Middleware` is
/// `@MainActor`, the callers are already where they need to be and the compiler says so.
@MainActor
protocol TapticFeedbackServiceProtocol {
    func playSuccess()
    func playError()
    func playWarning()
    func playSelection()
    func prepare()
}

// MARK: - TapticFeedbackService Implementation
@MainActor
final class TapticFeedbackService: TapticFeedbackServiceProtocol {

    // MARK: - Private Properties
    private let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
    // Its own generator, and a different class of one: a selection is not a notification.
    // `UISelectionFeedbackGenerator` is the tick a picker gives — light enough to fire on
    // every day the user swipes past, where a notification haptic would be a thud.
    private let selectionFeedbackGenerator = UISelectionFeedbackGenerator()

    // MARK: - Initialization
    init() {
        // Initialize without preparation - call prepare() manually when needed
    }

    // MARK: - Public Methods

    /// Plays success haptic feedback
    func playSuccess() {
        notificationFeedbackGenerator.notificationOccurred(.success)
    }

    /// Plays error haptic feedback
    func playError() {
        notificationFeedbackGenerator.notificationOccurred(.error)
    }

    /// Plays warning haptic feedback
    func playWarning() {
        notificationFeedbackGenerator.notificationOccurred(.warning)
    }

    /// Plays the light tick that marks a change of selection
    ///
    /// Nothing is re-armed afterwards. Arming the engine again on the way out of a tick did
    /// make a run of them crisper — days are chosen in runs, a swipe across the card walks
    /// them one at a time — but it is also one more activation per tap on an object whose
    /// activate/deactivate balance is what the crash below is counting. A tick that is a
    /// few milliseconds late is worth less than that risk.
    func playSelection() {
        selectionFeedbackGenerator.selectionChanged()
    }

    /// Prepares haptic generators for immediate use
    func prepare() {
        notificationFeedbackGenerator.prepare()
    }
}
