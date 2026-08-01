//
//  CalendarConstants.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.08.2025.
//
import Foundation

enum CalendarConstants {
    static let weekdaysHeaderHeight: CGFloat = 31
    static let horizontalPadding: CGFloat = 24

    // MARK: - Month Header
    static let monthHeaderHeight: CGFloat = 60

    // MARK: - Grid
    static let gridVerticalSpacing: CGFloat = 4
    static let bottomSpacing: CGFloat = 20

    // MARK: - Viewport
    // How far the calendar may slide before its day cells are rebuilt for a new anchor.
    // Must stay well below the buffer below, which is what keeps the leading edge covered
    // in the meantime.
    static let viewportUpdateThreshold: CGFloat = 120
    // Day cells are built for the screen plus this share of its height above and below.
    // It absorbs the drift between two rebuilds — a tighter buffer shows empty rows
    // sliding in at the leading edge of a fast scroll.
    static let dayVisibilityBufferRatio: CGFloat = 0.6
    static let averageMonthHeight: CGFloat = 290

    // MARK: - Day rendering
    // Only the day indicator and the dot row share the 25pt below a cell's centre (half of the
    // smallest week height) — the fertile window is a band drawn behind the day, not a line
    // under it, so it costs that strip nothing. Current split: circle -15…+15, dots +18…+24,
    // and the next week's own indicator starts at +39.
    static let periodBarHeight: CGFloat = 22
    static let periodBarCornerRadius: CGFloat = 6
    // The band is deliberately taller than the period bar and pulled in at its caps: the bar is
    // opaque and drawn above it, so those 2pt of lilac above and below — and the 4pt the caps
    // stop short — are the only thing the window has left to show for itself where the two
    // overlap. 26 is also the ceiling: the band has to stay under the ⌀28 day indicator.
    static let fertileBandHeight: CGFloat = 26
    static let fertileBandCornerRadius: CGFloat = 7
    static let fertileBandCapInset: CGFloat = 4
    static let dayIndicatorSize: CGFloat = 28
    static let tagDotSize: CGFloat = 6
    static let tagDotSpacing: CGFloat = 3
    static let tagDotsOffset: CGFloat = 21

    // MARK: - Day card
    // What the day card's height is taken to be before one has been measured. Only the very
    // first opening of a session uses it; afterwards the previous card's height is the guess.
    static let assumedCardHeight: CGFloat = 260
    // A height that differs from the assumed one by less than this is not worth a correction:
    // the error moves the scroll target by half of it.
    static let cardHeightTolerance: CGFloat = 12

    // MARK: - Month limits for infinite scroll
    static let minMonthOffset: Int = -2400
    static let maxMonthOffset: Int = 2400
}
