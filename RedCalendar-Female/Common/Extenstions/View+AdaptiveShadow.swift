//
//  View+AdaptiveShadow.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 06.09.2025.
//

import SwiftUI

extension View {
    /// The day card's lift off the page — and only in the light theme.
    ///
    /// The dark theme gets nothing here, deliberately. Black on a near-black page draws nothing,
    /// and the white glow that stood in for it was worse than nothing: it is composited beneath
    /// the card, so it haloed the top edge and — while the fill was still a material — bled
    /// through the surface it was meant to lift. The rim in `adaptiveBackground` does this job
    /// there instead, the same division the weekdays capsule already makes.
    @ViewBuilder
    func adaptiveShadow(colorScheme: ColorScheme) -> some View {
        if colorScheme == .dark {
            self
        } else {
            self
                .shadow(color: .black.opacity(0.1), radius: 10, x: -2, y: -5)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 2, y: -5)
        }
    }
}
