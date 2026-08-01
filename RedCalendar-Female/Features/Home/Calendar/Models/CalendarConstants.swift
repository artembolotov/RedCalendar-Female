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
    // The day indicator, the fertile line and the dot row are stacked below a cell's centre in
    // that order, so the four values below only move together — shrink one gap and the line
    // ends up under the selected day's circle or against the dots.
    // Current split: circle -15…+15, fertile line +18…+20, dots +23…+29, and the next week's
    // own indicator starts at +39.
    static let periodBarHeight: CGFloat = 22
    static let periodBarCornerRadius: CGFloat = 6
    // A predicted period is drawn as an outline rather than a faded fill, so its weight is a
    // stroke width and not an opacity. Drawn inward — the bar's own height is unchanged.
    static let predictedBarStrokeWidth: CGFloat = 1.5
    static let fertileLineHeight: CGFloat = 2
    static let fertileLineOffset: CGFloat = 19
    // A predicted ovulation day is dashed where a confirmed one is solid.
    static let predictedOvulationDash: [CGFloat] = [4, 3]
    static let dayIndicatorSize: CGFloat = 28
    static let tagDotSize: CGFloat = 6
    static let tagDotSpacing: CGFloat = 3
    static let tagDotsOffset: CGFloat = 26

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
