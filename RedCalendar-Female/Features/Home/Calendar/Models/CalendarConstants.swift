//
//  CalendarConstants.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 09.08.2025.
//
import Foundation

enum CalendarConstants {
    static let weekdaysHeaderHeight: CGFloat = 38
    static let horizontalPadding: CGFloat = 24

    // MARK: - Weekday strip
    // Measured off App Store Connect's segmented control, which is what this strip has always
    // been echoing: a 32pt track with a 16pt radius — an exact capsule, not a rounded rectangle,
    // since sampling its corner against the circle equation fits inside a sixth of a point at
    // every height. Only the container is borrowed. That control also marks a selected segment
    // with a pill, and nothing here does anything per column: the strip is a legend for the
    // grid, and all seven weekdays are drawn identically.
    //
    // The track no longer borrows `periodBarHeight` and `periodBarCornerRadius`. That sharing
    // was only ever a way of saying "the same shape as the period bar", and at 30pt against the
    // bar's 22 it stops saying it — an 8pt radius reads as a different object on a taller box,
    // so matching the reference means the radius follows the height, which means a capsule.
    // Nothing is lost by cutting the link: the track is 7 columns wide and could never be
    // mistaken for a day's bar at any radius.
    //
    // 30 rather than the reference's 32, and that is the ceiling rather than a rounding. App
    // Store Connect's control is tappable and carries a touch target; this one is a label track,
    // and it sits directly above a row of days whose indicator is ⌀28. Past 30 the track starts
    // reading as the same weight as a row of days rather than as the chrome above them.
    static let weekdaysTrackHeight: CGFloat = 30

    // How much of the page colour is laid under the weekday track before the grey goes on top.
    //
    // Not 1.0, for the same reason the scrim above is not: an opaque backing turns the track
    // into a plate, and the strip stops being part of the band it stands on. It cannot go much
    // below this either — the backing is what stops day numbers ghosting up between the labels,
    // and the blur under the strip is the band's thinnest (`topChromeScrimOpacityBottom`), so
    // the track gets less help from the band here than anywhere else along it. At this level a
    // period bar crossing under the strip registers as a warm shift in the grey rather than as
    // a red shape, which is the whole point of the translucency.
    static let weekdaysBarBackingOpacity: Double = 0.55
    // The outline is what a weakened fill costs, paid back. Below full opacity the fill can no
    // longer draw its own edge — the capsule's boundary was carried by the density step against
    // the page, and thinning the fill thins that step — so the shape is stated by a hairline
    // instead. One point, not the predicted bar's 1.5: this is chrome, and an outline heavy
    // enough to notice makes the track read as a control that can be tapped.
    //
    // Drawn with `strokeBorder`, so it lands inside `weekdaysTrackHeight` rather than straddling
    // it and losing half its weight, exactly as the period bar's outline does.
    static let weekdaysBarStrokeWidth: CGFloat = 1

    // MARK: - Top chrome
    // The band the grid scrolls under: the navigation bar's own height plus the weekday
    // strip. Below it the blur dissolves over `topChromeFadeHeight` instead of ending on a
    // line — that dissolve is what the strip's divider used to be, and it hangs *below* the
    // band rather than inside it, so it never crosses the weekday labels.
    //
    // Short, and it has to be. At 40 the dissolve swallowed a whole row of days: digits a
    // full row below the bar sat half-blurred and half-washed, which reads as a rendering
    // mistake, not as depth — a crossfade only trades softness for focus, but a *parked* row
    // caught mid-trade looks broken in a way a moving one never does. The transition now
    // completes in the gap between the strip and the first row that can land under it, so a
    // resting row is either under the band or entirely itself.
    static let topChromeFadeHeight: CGFloat = 18
    // How hard the calendar is blurred where it passes under the band.
    //
    // One radius, and the count is a measured budget, not a stylistic choice. An iOS 26-style
    // ramp of radii — heavy behind the navigation bar, light at the dissolve — was built here
    // and withdrawn: every radius is one more copy of the whole grid rendered offscreen on
    // every frame of a scroll, and even a single extra copy, cropped to the band, cost
    // visible frames on an iPhone 17 Pro (band disabled: flawless; enabled: stutter). One
    // blurred copy per frame is the whole budget. What the heavier top of the ramp was
    // *for* — anonymity behind the navigation bar — is carried by the scrim's density
    // gradient instead, which costs nothing per frame; see the scrim opacities below.
    //
    // It has to be a radius we choose, because the system never exposes one: a
    // `UINavigationBarAppearance` background or a SwiftUI `Material` is a named `UIBlurEffect`
    // style, and there is no public API to say how much. Both also blur their *backdrop* — the
    // window behind them — which over this sparse calendar is mostly empty page, so they come
    // out as the grey plate this band exists to avoid. See `CalendarView.blurredBandLayer`.
    static let topChromeBlurRadius: CGFloat = 3
    // How far the band washes what passes under it toward the page's own colour.
    //
    // Blur alone was not enough: it takes a period bar's shape away but not its colour, so a
    // red run crossing the band arrived as a red smear behind the title at full strength — the
    // band read as a window someone had breathed on rather than as chrome. The wash is what
    // takes the *density* out, and it is drawn in `AppBackgroundColor` precisely so that it
    // cannot become the grey plate this band has spent three attempts avoiding: over the empty
    // page it is the page, and only where content passes does it do anything at all.
    //
    // The page is a gradient and this is a flat colour, the same trade the day indicator's ring
    // makes — the two stops are about four 8-bit levels apart and the band covers the top fifth
    // of the screen, so the mismatch at the bottom of the dissolve is under a level. If the
    // gradient ever gains real range, this has to sample it.
    //
    // Not 1.0, and it should not be. At full opacity the calendar stops existing under the bar
    // and a month title sliding upward pops out rather than sinks; the ghost left at this level
    // is what says the grid carries on up there.
    //
    // Two opacities, because the wash is what is left of the blur ramp. The variable blur the
    // system's soft edge uses is unaffordable here (each radius is an extra offscreen render
    // of the grid per frame — see the blur radius above), but what the heavy top of a ramp
    // reads as is mostly *density*, and density in a wash is free: the band is nearly opaque
    // behind the navigation bar and thin by the weekday strip, so days ghost through under
    // the labels the way the system's soft edge lets them. The old single flat 0.82 was the
    // opposite failure — milk across the whole band, with the smear reading as dirt under it.
    static let topChromeScrimOpacityTop: Double = 0.85
    static let topChromeScrimOpacityBottom: Double = 0.3

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
