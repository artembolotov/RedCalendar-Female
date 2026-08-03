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

    // How much of the page colour is laid under the weekday track before the fill goes on top.
    //
    // Effectively solid. Nothing legible survives the last three percent — this is not a
    // translucency anyone can see, and the number could be 1.0 without a visible difference. It
    // is held a hair short because the value is the one dial that decides how much of the
    // calendar reaches the track, and a dial parked at its stop stops reading as a decision.
    //
    // It used to be 0.55, so a period bar crossing under the strip arrived as a pale pink. That
    // is gone: the bar now stops dead at the capsule's edge.
    //
    // It matters only in the dark theme now, where the fill above is white at 0.13 and hides
    // nothing on its own. The light theme's fill is fully opaque, so this value is invisible
    // there — which is exactly why it must not be lowered on the strength of the light theme
    // looking fine.
    static let weekdaysBarBackingOpacity: Double = 0.97
    // One point, and a dark-theme device: `WeekdaysBarStrokeColor` is fully transparent in the
    // light theme, where the shadow below draws the edge instead — the menu button has no rim
    // either, its scan stepping straight from page to fill. Do not thicken it. The strip is
    // 370pt across, and a rim reading as a hairline on the ⌀36 button reads as a drawn box here.
    //
    // Drawn with `strokeBorder`, so it lands inside `weekdaysTrackHeight` rather than straddling
    // it and losing half its weight, exactly as the period bar's outline does.
    static let weekdaysBarStrokeWidth: CGFloat = 1

    // The shadow is what makes the track read in the light theme, and it is measured off the ⋯
    // menu button rather than invented. Around that button the page drops from (247,245,245) to
    // (239,237,237) at the very edge and is back to full about 20pt out, while the fill itself
    // sits only 6 levels above the page — so it is this ring, not the tone, that separates the
    // button from the calendar. These two values with `WeekdaysBarShadowColor`'s 0.10 rebuild it.
    //
    // It was argued here once that a shadow could not work over this calendar, having nothing
    // solid to fall on. The button disproves it: its shadow falls on exactly the same blurred,
    // moving grid and reads correctly.
    //
    // Both are inert in the dark theme, where the shadow colour is fully transparent: black on a
    // near-black page draws nothing, and the white rim does this job there instead.
    static let weekdaysBarShadowRadius: CGFloat = 8
    static let weekdaysBarShadowOffsetY: CGFloat = 2

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
    //
    // What it has to cover is the threshold above plus one frame of a fast fling, because the
    // anchor is only re-taken once a reported offset has travelled that far: ~120 + ~85pt at
    // 60Hz, call it 205. On a 850pt screen this is ~300, which clears that with half again to
    // spare. It is not a free dial — it is a share of *every* day cell drawn, in both the sharp
    // grid and the blurred copy — so it is sized off that arithmetic rather than upwards until
    // the seams stop showing. Raise `viewportUpdateThreshold` and this has to follow.
    static let dayVisibilityBufferRatio: CGFloat = 0.35
    // The same share, for the month walk that feeds the cull above. It only has to be wider
    // than `dayVisibilityBufferRatio` — the viewport and the anchor are rebuilt together, so
    // there is no drift between them to absorb, only the rounding to whole months.
    static let viewportBufferRatio: CGFloat = 0.6
    static let averageMonthHeight: CGFloat = 290

    // MARK: - Scroll flight
    // How far the calendar may actually travel when it is sent back to a day, in screens.
    // Anything beyond this is closed instantly first, and only this much is animated.
    //
    // A flight is a flight only while someone can follow it. The rail is sixty years from
    // today, and `InfiniteScrollContainer.spring(forDistance:)` gives every distance the same
    // 0.75s — from the far end that is 11,000pt in a single frame, thirteen screens, which is
    // not motion but a strobe. At two screens the fastest frame moves 72pt, a little over one
    // row. Nothing was lost by cutting the rest: it was never legible.
    //
    // It also decides the curve, and that is the part that will catch someone out.
    // `spring(forDistance:)` changes damping at 1400pt, and two screens is the first cap that
    // lands above it: at one and a half the flight would run at ζ=0.90 and settle with a
    // visible 2pt bounce, at two it runs at ζ=0.95 and simply arrives. Do not round this
    // number without checking which side of 1400 it leaves you on.
    //
    // The cap is never reached by the other thing that flies the calendar — a day selection
    // re-centring on the chosen row — because only a day already on screen can be tapped. It
    // needs no special case for that; the distance says it.
    static let flightCapScreens: CGFloat = 2

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
    //
    // 60 years either way, and the number is a cost as much as a range: the scroll rail is the
    // content-space position of these two months, and reaching it means measuring every month
    // in between — two `Calendar` calls each, once per `MonthCalculator`. At the ±200 years
    // this used to be, that was ~9600 of them on the frame the first drag started.
    // `MonthCalculator.getScrollLimits()` now keeps the answer, so the walk is paid once; this
    // is what keeps that once affordable.
    static let minMonthOffset: Int = -720
    static let maxMonthOffset: Int = 720
}
