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

    private var displayLink: CADisplayLink?
    private var startOffset: CGFloat = 0
    private var targetOffset: CGFloat = 0
    private var startTime: CFTimeInterval = 0
    private var duration: TimeInterval = 0
    private var damping: Double = 0
    private var initialVelocity: Double = 0
    private var completion: (() -> Void)?

    // A flick that has almost nowhere left to travel would normalize into an absurd starting
    // speed; past this the spring is velocity-dominated anyway.
    private let maxInitialVelocity: Double = 6

    deinit {
        displayLink?.invalidate()
    }

    // MARK: - Driving

    func setOffset(_ value: CGFloat) {
        cancel()
        offset = value
    }

    func animate(
        to target: CGFloat,
        duration: TimeInterval,
        damping: Double,
        velocity: CGFloat,
        completion: @escaping () -> Void
    ) {
        cancel()

        let distance = target - offset

        guard duration > 0, abs(distance) > 0.5 else {
            offset = target
            completion()
            return
        }

        startOffset = offset
        targetOffset = target
        startTime = CACurrentMediaTime()
        self.duration = duration
        self.damping = damping
        self.completion = completion

        // Into the curve's own 0…1 progress space, so the spring leaves at the speed the
        // finger did.
        let normalized = Double(velocity) * duration / Double(distance)
        initialVelocity = min(max(normalized, -maxInitialVelocity), maxInitialVelocity)

        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    // Stops wherever the animation had got to, dropping the completion — the caller taking
    // over is responsible for what happens next.
    func cancel() {
        displayLink?.invalidate()
        displayLink = nil
        completion = nil
    }

    // MARK: - Frames

    @objc private func step() {
        let elapsed = CACurrentMediaTime() - startTime

        guard elapsed < duration else {
            offset = targetOffset
            let finished = completion
            cancel()
            finished?()
            return
        }

        let progress = SpringInterpolation.progress(
            elapsed / duration,
            damping: damping,
            initialVelocity: initialVelocity
        )

        offset = startOffset + (targetOffset - startOffset) * CGFloat(progress)
    }
}
