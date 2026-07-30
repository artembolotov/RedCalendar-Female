//
//  SpringInterpolation.swift
//  RedCalendar-Female
//

import Foundation

// Underdamped spring, evaluated on normalized progress: `t` runs 0…1 across whatever duration
// the caller animates over, so the curve always lands on its target and the duration alone
// sets how fast it gets there.
enum SpringInterpolation {
    private static let mass: Double = 1.0
    private static let stiffness: Double = 100.0

    /// - Parameter initialVelocity: the speed the animation starts at, in fractions of the
    ///   total distance per unit of progress — `velocity * duration / distance`. Zero starts
    ///   from rest; a flick hands its own speed over so the motion stays continuous.
    static func progress(_ t: Double, damping: Double, initialVelocity: Double = 0) -> Double {
        guard t > 0 else { return 0 }
        guard t < 1 else { return 1 }

        let c = damping * 2.0 * sqrt(mass * stiffness)
        let omega = sqrt(stiffness / mass)
        let zeta = c / (2.0 * sqrt(stiffness * mass))

        // The solution below leaves at -velocity, so the caller's sign is flipped here.
        let velocity = -initialVelocity

        if zeta < 1.0 {
            let omegaD = omega * sqrt(1.0 - zeta * zeta)
            let exponential = exp(-zeta * omega * t)
            let cosine = cos(omegaD * t)
            let sine = sin(omegaD * t)
            let A = 1.0
            let B = (zeta * omega + velocity) / omegaD

            return 1.0 - exponential * (A * cosine + B * sine)
        }

        // Critically damped fallback.
        return 1.0 - exp(-omega * t) * (1.0 + omega * t)
    }
}
