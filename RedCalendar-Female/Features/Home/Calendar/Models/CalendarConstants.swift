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
    // The day indicator, the dot row and the fertile line share the 25pt below a cell's centre
    // (half of the smallest week height), so the four values below only move together: shrink
    // the gaps and the dots end up inside the selected day's circle or under the dashed line.
    // Current split: circle -15…+15, dots +16.5…+21.5, fertile line +23…+25.
    static let periodBarHeight: CGFloat = 26
    static let periodBarCornerRadius: CGFloat = 8
    static let dayIndicatorSize: CGFloat = 28
    static let fertileLineBottomInset: CGFloat = 1
    static let fertileLineWidth: CGFloat = 2
    static let tagDotSize: CGFloat = 5
    static let tagDotSpacing: CGFloat = 3
    static let tagDotsOffset: CGFloat = 19

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
