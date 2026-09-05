//
//  LinearGradient+AppBackground.swift
//  RedCalendar-Female
//

import SwiftUI

extension LinearGradient {
    /// The page itself: a very shallow fall in luminance down the screen, enough to stop the
    /// background reading as a flat sheet.
    ///
    /// It is a shared value because it is now drawn twice. `HomeView` fills the screen with it,
    /// and the calendar's top band draws its own slice of it as the ground under the blurred
    /// copy of the grid — which only works while the two are the same gradient at the same
    /// extent. Two literals here meant the band would drift off the page it is standing on.
    ///
    /// The two stops are about four 8-bit levels apart, which is what lets flat
    /// `AppBackgroundColor` stand in for it elsewhere — the day indicator's ring, the band's
    /// scrim. Give it real range and every one of those becomes a halo; see the notes in
    /// `CalendarConstants`.
    static let appBackground = LinearGradient(
        colors: [Color("AppBackgroundColor"), Color("AppBackgroundEdgeColor")],
        startPoint: .top,
        endPoint: .bottom
    )
}
