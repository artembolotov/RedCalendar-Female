//
//  Shape+AdaptiveBackground.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on [current date].
//

import SwiftUI

extension InsettableShape {
    /// The day card's surface: opaque in both themes, with the dark theme's separation carried
    /// by a rim rather than by a shadow.
    ///
    /// The dark fill used to be `.regularMaterial`, which is what made the card read as clouded.
    /// A material is translucent by definition, so two things came through it: the blurred
    /// calendar grid behind the card, and — because a shadow is composited *beneath* the view
    /// the material then samples — the white glow `adaptiveShadow` drew above it. The card is a
    /// sheet standing on the page, not a pane to see the page through, and the light theme has
    /// always drawn it opaque.
    ///
    /// `secondarySystemBackground` is (28,28,30) in dark against the page's (18,18,20): a step
    /// small enough to stay quiet and large enough to read across a surface this size. The rim
    /// finishes the top edge, at the low alpha a full-width card needs — the weekdays capsule's
    /// 0.34 is sized for a ⌀36-scale shape over the busy grid and would read as a drawn box here.
    @ViewBuilder
    func adaptiveBackground(colorScheme: ColorScheme) -> some View {
        if colorScheme == .dark {
            fill(Color(.secondarySystemBackground))
                .overlay(strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        } else {
            fill(Color(.systemBackground))
        }
    }
}
