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
    /// The fill is `DayCardBackgroundColor`: the weekday bar's surface, flattened to one opaque
    /// colour — `WeekdaysBarColor` over the page, as the bar is measured on screen: #FDFCFC in the
    /// light theme, (23,23,24) in the dark one. The groups on it (`DayCardGroup`) are white and
    /// carry the bar's shadow in the light theme, and a step lighter than the card in the dark one.
    ///
    /// Opaque because the card, unlike the bar, has a sharp calendar under it rather than the
    /// blurred band. Built the bar's way, layer for layer, the dark theme showed the grid's digits
    /// through it; over a material instead, the light card went grey and the blurred grid — thin
    /// digits, nothing solid — barely showed at all. The bar reads as glass because of the blurred
    /// band around it, not because of its own fill, and there is no such band around the card.
    ///
    /// The rim finishes the dark card's edge at the low alpha a full-width card needs — the
    /// weekday bar's 0.34 reads as a drawn box at this size.
    @ViewBuilder
    func adaptiveBackground(colorScheme: ColorScheme) -> some View {
        if colorScheme == .dark {
            fill(Color("DayCardBackgroundColor"))
                .overlay(strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        } else {
            fill(Color("DayCardBackgroundColor"))
        }
    }
}
