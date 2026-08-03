//
//  TapticFeedbackService.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 16.06.2025.
//

import UIKit

// MARK: - TapticFeedbackService Protocol
protocol TapticFeedbackServiceProtocol {
    func playSuccess()
    func playError()
    func playWarning()
    func playSelection()
    func prepare()
}

// MARK: - TapticFeedbackService Implementation
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
        onMain { self.notificationFeedbackGenerator.notificationOccurred(.success) }
    }

    /// Plays error haptic feedback
    func playError() {
        onMain { self.notificationFeedbackGenerator.notificationOccurred(.error) }
    }

    /// Plays warning haptic feedback
    func playWarning() {
        onMain { self.notificationFeedbackGenerator.notificationOccurred(.warning) }
    }

    /// Plays the light tick that marks a change of selection
    ///
    /// Nothing is re-armed afterwards. Arming the engine again on the way out of a tick did
    /// make a run of them crisper — days are chosen in runs, a swipe across the card walks
    /// them one at a time — but it is also one more activation per tap on an object whose
    /// activate/deactivate balance is what the crash below is counting. A tick that is a
    /// few milliseconds late is worth less than that risk.
    func playSelection() {
        onMain { self.selectionFeedbackGenerator.selectionChanged() }
    }

    /// Prepares haptic generators for immediate use
    func prepare() {
        onMain { self.notificationFeedbackGenerator.prepare() }
    }

    // MARK: - Private Methods

    /// Runs the work on the main thread, which is the only thread a `UIFeedbackGenerator` may
    /// be touched from.
    ///
    /// It is done here rather than at the call sites because of where those call sites are:
    /// `Middleware` is a plain `async` closure (`Store.swift`), so its body runs off the main
    /// actor no matter that the store awaiting it is `@MainActor` — every haptic in this app is
    /// therefore raised from a background thread unless something catches it. Off the main
    /// thread the generator's internal activation bookkeeping races, and the process is killed
    /// with `_UIFeedbackCoreHapticsHapticsOnlyEngine _internal_deactivate called more times
    /// than the feedback engine was activated`. It surfaces where the taps are frequent — the
    /// day selection tick — but every method here was exposed to it.
    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
