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

    // MARK: - Top chrome
    // The band the grid scrolls under: the navigation bar's own height plus the weekday
    // strip. Below it the blur dissolves over `topChromeFadeHeight` instead of ending on a
    // line — that dissolve is what the strip's divider used to be, and it hangs *below* the
    // band rather than inside it, so it never crosses the weekday labels.
    //
    // Long, and it can afford to be. While the band was a material the dissolve faded paint,
    // which erased what lay under it — a row of numerals at the edge came out cut in half, so
    // the ramp had to stay short enough to fall between rows. It now crossfades a blurred copy
    // of the calendar into the sharp one, which only ever trades softness for focus, and the
    // length is what makes that trade read as depth instead of as an edge.
    static let topChromeFadeHeight: CGFloat = 40
    // How hard the calendar is blurred where it passes under the band. The one dial worth
    // turning here: higher and the numerals become anonymous smears, lower and the band stops
    // registering as anything at all.
    //
    // It has to be a radius we choose, because the system never exposes one: a
    // `UINavigationBarAppearance` background or a SwiftUI `Material` is a named `UIBlurEffect`
    // style, and there is no public API to say how much. Both also blur their *backdrop* — the
    // window behind them — which over this sparse calendar is mostly empty page, so they come
    // out as the grey plate this band exists to avoid. See `CalendarView.blurredBandLayer`.
    static let topChromeBlurRadius: CGFloat = 8

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
    // Drawn `.continuous` rather than circular: at this radius the corner curve reaches about
    // 1.5x the radius along each edge, which is what stops the bar reading as a stamped
    // rectangle. Kept well under half the height — a capsule would turn the bar into a pill
    // and start competing with the day indicator's circle.
    static let periodBarCornerRadius: CGFloat = 8
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
