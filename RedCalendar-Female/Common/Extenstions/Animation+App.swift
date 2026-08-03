//
//  Animation+App.swift
//  RedCalendar-Female
//

import SwiftUI

extension Animation {
    /// The curve the day card enters, leaves and pages with. Matches what `.bouncy` gives on
    /// iOS 17, spelled in the iOS 13 API so it is available on the deployment target.
    static let cardEntrance = Animation.spring(response: 0.5, dampingFraction: 0.7)

    /// The card moving from the level it inherited to the one its own content asks for. Calmer
    /// than the entrance: the top edge travels alone here, and a bounce on it reads as a glitch.
    static let cardLevelChange = Animation.spring(response: 0.35, dampingFraction: 0.9)

    /// The selection disc travelling along a row, over `travelDays` days.
    ///
    /// **The short curve is tied to the day card's settle, and the two were measured against
    /// each other rather than eyeballed.** A swipe across the card moves both — the card by its
    /// own display link, the disc by this — so they have to land together. `SpringInterpolation`
    /// is normalized (ζ=0.85, ω=10 across the whole duration), so at the card's
    /// `settleDuration` of 0.55 its real decay is 0.85·10/0.55 ≈ 15.5 s⁻¹ and it is within a
    /// couple of percent of its target at ~0.25s; the rest of the 0.55 is the tail
    /// `CardPagingAnimator.onArrival` exists to ignore. This spring's decay is
    /// 0.86·2π/0.32 ≈ 16.9 s⁻¹, arriving at ~0.23s. Move either number and check the other.
    ///
    /// What cannot be matched is the *start*: the card takes the flick's velocity into its
    /// spring and the disc always leaves from rest. Handing the gesture's speed over would mean
    /// choosing the animation at the call site, and `Store.send` defers the state change into a
    /// `Task`, so no `withAnimation` around a dispatch survives to reach the view. On a hard
    /// flick the card will leave first; that is structural, not a number to tune.
    ///
    /// Longer travel gets a longer, calmer curve, the same trade
    /// `InfiniteScrollContainer.spring(forDistance:)` makes for the calendar's own flight —
    /// and, as there, damping goes **up** with distance, never down: the fast peak velocity of
    /// a long throw is exactly what makes an overshoot read as a wobble. Below the threshold a
    /// move is a step — a swipe, or a tap on a neighbour — and the disc should keep the card's
    /// timing. Above it the move is a jump across the week, where the same duration would only
    /// mean a whippier disc.
    static func daySelection(travelDays: Int) -> Animation {
        travelDays >= 3
            ? .spring(response: 0.48, dampingFraction: 0.90)
            : .spring(response: 0.32, dampingFraction: 0.86)
    }
}
