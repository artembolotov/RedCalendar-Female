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

    /// The selection disc travelling along a row, over `travelDays` days — or `nil` for straight
    /// there, which is every move but one.
    ///
    /// **Only a single step slides.** The disc travels when the selection moves by exactly one
    /// day and stays in its row; every other move places it. That is not a threshold that could
    /// have been drawn anywhere — a one-day move is the only one a gesture produces, because the
    /// day card pages by ±1 and nothing else (`DayDetailsPagerView.commit(shift:)`), so it is the
    /// only move where the disc is following something the hand is already doing. Tapping a day
    /// four columns over is not a movement the user made; it is a choice, and drawing a line
    /// across the week to illustrate it is the calendar explaining itself to someone who was not
    /// asking.
    ///
    /// It also ends the strobe, which is what the flight actually cost. The disc is a mask, so
    /// every numeral it crosses inverts to the page colour and back on the way past — a jump
    /// across the week flickered five digits in sequence, and that, rather than the disc, is what
    /// was tiring to watch. Speeding the sweep up only shortens each flash; not crossing the
    /// intervening days at all removes them. A single step passes over nothing, which is why it
    /// is the one case that survives.
    ///
    /// This is the same judgement `CalendarConstants.flightCapScreens` makes about the calendar's
    /// own flight, and the one the row identity in `CalendarSelectionLayer` already made about a
    /// change of row: motion that cannot be followed is not motion, and a placement reads as
    /// deliberate where an unfollowable flight reads as a glitch.
    ///
    /// A midnight rollover is **not** one of these cases, though it looks like it should be:
    /// `.updateTodayDayStamp` moves `todayDayStamp` alone and never touches `selectedDayStamp`,
    /// so the disc does not move at all when the day turns over. What moves is the today marker
    /// inside the grid, which is drawn per-cell and has no animation of its own.
    ///
    /// **The curve is tied to the day card's settle, and the two were measured against
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
    /// choosing the animation at the call site. That is now possible in principle — the store
    /// runs its reducer synchronously, so a `withAnimation` around a dispatch does reach the
    /// view — but nothing in the app does it yet, and adopting it here is a change to how the
    /// disc moves rather than a change to this number. On a hard flick the card still leaves
    /// first.
    ///
    /// There is one curve now, and that is a consequence rather than a simplification: the only
    /// distance it is ever asked to cover is one cell. A second, calmer curve for long throws
    /// lived here and is gone with the throws themselves — it was tuned against a wobble that a
    /// 50pt slide cannot produce.
    ///
    /// `travelDays` is `0` for a first selection, which takes the same path as a long jump and
    /// for the same reason: a disc appearing has nowhere to have come from.
    static func daySelection(travelDays: Int) -> Animation? {
        travelDays == 1 ? .spring(response: 0.32, dampingFraction: 0.86) : nil
    }
}
