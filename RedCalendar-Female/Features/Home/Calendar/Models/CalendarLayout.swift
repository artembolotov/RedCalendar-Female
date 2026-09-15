//
//  CalendarLayout.swift
//  RedCalendar-Female
//

import CoreGraphics

/// Where the calendar sits on the screen, as arithmetic rather than as view state.
///
/// Every number here used to be a computed property or a `@State` on `CalendarView`, mixed in
/// among the scroll handling, the flight scheduling and the two grid layers. They are three
/// inputs and six answers, and none of the six needs a view to be worked out — which is the whole
/// argument for the type: the questions this file answers are the ones that get subtly wrong
/// (which height a week is measured against, whether the band counts, what "today is off screen"
/// means), and they are much easier to check when they are eight lines of arithmetic in a row
/// than when they are scattered down eight hundred.
///
/// It is a companion to `CalendarBandGeometry`, not a replacement: that one owns the band's own
/// measurements and the layers drawn from them, this one owns everything measured *against* the
/// band.
struct CalendarLayout: Equatable {
    /// The whole screen. The grid is drawn edge to edge and scrolls under the chrome, so this is
    /// deliberately not the space left below the bar.
    let screenHeight: CGFloat

    /// Navigation bar plus weekday strip — `CalendarBandGeometry.barHeight`.
    let chromeHeight: CGFloat

    /// Zero until the calculator exists, which is what the two guards below are for.
    let weekHeight: CGFloat

    /// What a *week* is sized against: the height left under the bar. A week's height answers to
    /// how much of it can be read, not to how much of it is drawn.
    var visibleHeight: CGFloat {
        max(0, screenHeight - chromeHeight)
    }

    /// Where today's week centre lands at rest: the middle of the screen, and not the middle of
    /// the area under the bar.
    ///
    /// Those are the same thing only if the bar is opaque, and it is not — the calendar carries
    /// on behind it. Centring under the band would push today half a row down the screen from
    /// where it has always sat, to buy alignment with an edge nobody can see. An open card is the
    /// one case where the band does count; see `selectionShift(cardHeight:)`.
    var restingCenterY: CGFloat {
        screenHeight / 2
    }

    /// The ceiling on the day card's own box (`DayDetailsView.reportedHeight`'s unit — the card
    /// excluding the elastic hang-off below the screen).
    ///
    /// The calendar centres the selected week in the readable strip between the band and the
    /// card, so the strip is what this is written against: the card gets the screen, less the
    /// band, less the weeks the strip has to keep standing. How many weeks that is, and why it is
    /// not the number the geometry alone would allow, is `CalendarConstants.minWeeksAboveCard`.
    ///
    /// A card asking for more is clipped to this by `DayDetailsView` rather than pushing the
    /// centring point up under the band, which is what let an unbounded multi-line comment grow
    /// the card to cover the whole screen.
    ///
    /// `.infinity` before there is a calculator — the very first geometry pass, which no card can
    /// be open during — so nothing is clipped against a limit that has no meaning yet.
    var maxCardHeight: CGFloat {
        guard weekHeight > 0, screenHeight > 0 else { return .infinity }
        return max(0, screenHeight - chromeHeight - weekHeight * CalendarConstants.minWeeksAboveCard)
    }

    /// How far off the resting centre the selected week has to sit while a card is open.
    ///
    /// The card eats the bottom of the screen and the band eats the top, so the middle of the
    /// strip left between them rises by half the card and falls by half the band.
    func selectionShift(cardHeight: CGFloat) -> CGFloat {
        (cardHeight - chromeHeight) / 2
    }

    /// The scroll offset that puts today's week in the middle of the screen with nothing open.
    func restingOffset(todayWeekCenterY: CGFloat) -> CGFloat {
        restingCenterY - todayWeekCenterY
    }

    /// The offset the calendar should be at: today's week centred at rest, the selected week
    /// centred in the strip above the card when one is open.
    func offset(todayWeekCenterY: CGFloat, selectionOffset: CGFloat, cardHeight: CGFloat) -> CGFloat {
        let resting = restingOffset(todayWeekCenterY: todayWeekCenterY)
        guard cardHeight > 0 else { return resting }
        return resting - selectionOffset - selectionShift(cardHeight: cardHeight)
    }

    /// Which way the floating button has to point for today to be reachable.
    ///
    /// Read off where today actually is rather than off a threshold: the resting offset is where
    /// today's week centre sits when nothing is open, and the scroll has carried it `deviation`
    /// from there.
    ///
    /// The two edges are not symmetric, and should not be: a week that has passed the bottom of
    /// the screen is gone, while one that has reached `chromeHeight` is behind the band — visible
    /// in outline, but not readable, which is the same thing to someone looking for today.
    func todayButtonState(scrollOffset: CGFloat, todayWeekCenterY: CGFloat) -> FloatingButtonState {
        let deviation = scrollOffset - restingOffset(todayWeekCenterY: todayWeekCenterY)
        let todayCenterY = restingCenterY + deviation

        if todayCenterY > screenHeight { return .arrowDown }
        if todayCenterY < chromeHeight { return .arrowUp }
        return .plus
    }
}
