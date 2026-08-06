//
//  CardPagingAnimator.swift
//  RedCalendar-Female
//

import SwiftUI

// Drives the day card's horizontal offset frame by frame instead of handing it to SwiftUI.
// A SwiftUI animation never tells anyone where it currently is, so a swipe that grabs the card
// mid-settle has nothing to continue from; here the offset is always a value that can be read,
// and a new drag simply picks it up.
final class CardPagingAnimator: ObservableObject {
    @Published private(set) var offset: CGFloat = 0

    // `nonisolated(unsafe)` only so that `deinit` can invalidate it. A `deinit` is nonisolated,
    // and this class is main-actor like the rest of the module, so the last release would
    // otherwise be unable to reach the one property it has to clean up. Every other access is on
    // the main actor, and the display link itself only ever fires there.
    nonisolated(unsafe) private var displayLink: CADisplayLink?
    private var startOffset: CGFloat = 0
    private var targetOffset: CGFloat = 0
    private var startTime: CFTimeInterval = 0
    private var duration: TimeInterval = 0
    private var damping: Double = 0
    private var initialVelocity: Double = 0
    private var completion: (() -> Void)?
    private var onArrival: (() -> Void)?

    // A flick that has almost nowhere left to travel would normalize into an absurd starting
    // speed; past this the spring is velocity-dominated anyway.
    private let maxInitialVelocity: Double = 6
    // Below this the card is where it was going. The same number decides that an animation has
    // nowhere to travel at all, so "arrived" and "nothing to do" mean one thing.
    private let restingTolerance: CGFloat = 0.5

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Driving

    func setOffset(_ value: CGFloat) {
        cancel()
        offset = value
    }

    /// - Parameter onArrival: called the first frame the card is within `restingTolerance` of
    ///   its target, which the curve reaches well before `duration` is up — the rest of it is
    ///   a tail too small to see. Anything timed against the card standing still belongs here
    ///   rather than in `completion`.
    func animate(
        to target: CGFloat,
        duration: TimeInterval,
        damping: Double,
        velocity: CGFloat,
        onArrival: (() -> Void)? = nil,
        completion: @escaping () -> Void
    ) {
        cancel()

        let distance = target - offset

        guard duration > 0, abs(distance) > restingTolerance else {
            offset = target
            onArrival?()
            completion()
            return
        }

        startOffset = offset
        targetOffset = target
        startTime = CACurrentMediaTime()
        self.duration = duration
        self.damping = damping
        self.completion = completion
        self.onArrival = onArrival

        // Into the curve's own 0…1 progress space, so the spring leaves at the speed the
        // finger did.
        let normalized = Double(velocity) * duration / Double(distance)
        initialVelocity = min(max(normalized, -maxInitialVelocity), maxInitialVelocity)

        let link = CADisplayLink(target: self, selector: #selector(step))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    // Stops wherever the animation had got to, dropping both callbacks — the caller taking
    // over is responsible for what happens next.
    func cancel() {
        displayLink?.invalidate()
        displayLink = nil
        completion = nil
        onArrival = nil
    }

    // MARK: - Frames

    @objc private func step() {
        let elapsed = CACurrentMediaTime() - startTime

        guard elapsed < duration else {
            offset = targetOffset
            let arrived = onArrival
            let finished = completion
            cancel()
            // A curve that never came within the tolerance still arrives at its end, so the
            // signal is sent exactly once either way.
            arrived?()
            finished?()
            return
        }

        let progress = SpringInterpolation.progress(
            elapsed / duration,
            damping: damping,
            initialVelocity: initialVelocity
        )

        offset = startOffset + (targetOffset - startOffset) * CGFloat(progress)

        if let arrived = onArrival, abs(targetOffset - offset) <= restingTolerance {
            onArrival = nil
            arrived()
        }
    }
}
