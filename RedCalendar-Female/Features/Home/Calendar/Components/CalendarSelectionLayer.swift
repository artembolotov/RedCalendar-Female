//
//  CalendarSelectionLayer.swift
//  RedCalendar-Female
//

import SwiftUI

/// The mark on the day currently chosen: the page's own colour inverted into a ⌀28 disc, and
/// the row's numerals showing through it.
///
/// **The disc belongs to no day, which is what lets it move.** It is drawn above the cells
/// rather than as a circle inside the selected one, and a numeral it covers is inverted *by the
/// disc* — the row's numerals are drawn again in the page colour and revealed only through it —
/// rather than by the cell's own state. That is what makes a disc halfway between two days
/// correct: cross-fading two cells' numerals instead would wash both of them out at the
/// midpoint, when the disc is over neither.
///
/// **It is a view of its own so that choosing a day costs only this.** It lived inside
/// `CalendarGridView` when it was first written, which meant `selectedDayStamp` was one of that
/// view's inputs — so every tap and every card swipe rebuilt several hundred day cells, in both
/// copies of the grid, to move one circle by a column. Split out, the grid no longer knows a
/// selection exists and the two layers redraw on entirely separate occasions. Nothing may put
/// `selectedDayStamp` back into the grid's inputs.
///
/// **The numerals do not travel; the hole does.** They are positioned in grid coordinates, in a
/// strip one disc tall, and the disc is the mask over it. Laying them out relative to the disc
/// is smaller code and was the first version of this, and it is wrong in motion: a view's
/// content is built once per body pass while only `.position` interpolates, so the disc would
/// carry the *destination's* digit for the whole flight and leave day 5 already showing a 6 —
/// the number changing before the motion rather than because of it. The strip's height is not
/// incidental either. A mask is an offscreen pass over the bounds it is given, and this one runs
/// every frame of a flight; over the whole grid that is a screen-sized buffer per frame to show
/// a ⌀28 hole.
struct CalendarSelectionLayer: View, @MainActor Equatable {
    let viewport: ViewportData
    /// The scroll offset the viewport was built for — the same anchor the grid culls against,
    /// and never the live offset. See `CalendarGridView`.
    let anchorOffset: CGFloat
    let calculator: MonthCalculator
    let selectedDayStamp: Daystamp?
    let width: CGFloat
    let height: CGFloat
    let reduceMotion: Bool
    /// How far the selection just moved, in days. Picks the disc's curve and nothing else.
    let selectionTravel: Int
    /// False in the blurred copy drawn into the top band — see `selectionAnimation`.
    let animatesSelection: Bool

    // `selectionTravel` is deliberately absent, exactly as it is from the grid's own
    // comparison: it decides how a change animates, never what is drawn — so the update that
    // arrives once a selection has settled, carrying nothing but the travel falling back to
    // zero, has to compare equal and skip the body.
    //
    // Whether a day is today rides along inside `viewport`, so there is no `today` here to
    // compare: the viewport is rebuilt when it changes.
    static func == (lhs: CalendarSelectionLayer, rhs: CalendarSelectionLayer) -> Bool {
        lhs.calculator === rhs.calculator
            && lhs.reduceMotion == rhs.reduceMotion
            && lhs.animatesSelection == rhs.animatesSelection
            && lhs.anchorOffset == rhs.anchorOffset
            && lhs.width == rhs.width
            && lhs.height == rhs.height
            && lhs.selectedDayStamp == rhs.selectedDayStamp
            && lhs.viewport == rhs.viewport
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let marker = marker {
                // The disc animates on one condition: that it can stay where it is on screen.
                // Within a row it can — the calendar has no reason to move, since the row it
                // centres on has not changed — so the disc travels. A change of row is the
                // opposite case: the calendar flies to the new row, and anything the disc does
                // during that flight is carried by a moving grid on top of its own motion. That
                // reads as the disc falling in rather than as it being placed, whichever way
                // the flight goes.
                //
                // Hence both of the pieces here, and neither is optional. The animation watches
                // `centerX` alone, so a move that changes the row cannot animate even when it
                // changes the column too; and the identity is the row, so such a move replaces
                // the view rather than reusing it. Without the identity the disc would fly the
                // diagonal; without the narrow value it would fly the vertical.
                //
                // A replacement is therefore instant, and deliberately so — no transition, and
                // no animated transaction for a default one to attach itself to.
                disc(marker)
                    .id(marker.rowID)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The two travelling pieces are separate views, so they are kept in step by construction
    /// rather than by hope: one animation value, one curve, and only `x` interpolating in
    /// either of them.
    private func disc(_ marker: SelectionMarker) -> some View {
        let size = CalendarConstants.dayIndicatorSize
        let animation = selectionAnimation

        return ZStack {
            // The ring is what punches the disc out of a solid period bar, exactly as the today
            // marker's does — and here it travels, so a run of period days is carved by a
            // moving hole rather than a blinking one.
            Circle()
                .fill(CalendarPalette.selected)
                .overlay(
                    Circle()
                        .stroke(CalendarPalette.background, lineWidth: 2)
                )
                .frame(width: size, height: size)
                .position(x: marker.centerX, y: marker.centerY)
                .animation(animation, value: marker.centerX)

            // The row's numerals again, in the page colour, revealed only where the disc is.
            // Only the row: the disc travels along one, so these are every digit it can pass
            // over, and seven of them cost nothing next to inverting the whole grid on the off
            // chance.
            ZStack {
                ForEach(marker.rowDigits) { digit in
                    Text(digit.dayNumber)
                        .font(DayNumberFont.font(isToday: digit.isToday))
                        .foregroundColor(CalendarPalette.background)
                        .position(x: digit.centerX, y: size / 2)
                }
            }
            .frame(width: width, height: size)
            .mask {
                Circle()
                    .frame(width: size, height: size)
                    .position(x: marker.centerX, y: size / 2)
                    .animation(animation, value: marker.centerX)
            }
            .position(x: width / 2, y: marker.centerY)
        }
    }

    /// How the disc gets where it is going, or `nil` for straight there — which is the usual
    /// answer. Only a one-day move slides; see `Animation.daySelection(travelDays:)`.
    ///
    /// Nil in the blurred copy of the grid, and that is a performance decision rather than a
    /// visual one: a disc animating inside `CalendarView.blurredBandLayer` recomputes that
    /// band's gaussian on every frame it moves, which is the one cost `CalendarConstants`
    /// budgets the whole band against. Under a 3pt blur and a 0.85/0.3 wash the difference
    /// between travelling and arriving is not visible anyway.
    private var selectionAnimation: Animation? {
        guard animatesSelection, !reduceMotion else { return nil }
        return .daySelection(travelDays: selectionTravel)
    }

    // MARK: - Private Methods

    /// Where the disc sits, and what it may pass over on the way.
    ///
    /// Culled on the same terms the grid's day cells are, and against the same anchor: a day
    /// the cull would have dropped is off screen, and so is the row around it.
    private var marker: SelectionMarker? {
        guard let selectedDayStamp = selectedDayStamp else { return nil }

        let buffer = height * CalendarConstants.dayVisibilityBufferRatio
        let dayWidth = (width - CalendarConstants.horizontalPadding) / 7
        let weekHeight = calculator.weekHeight

        for month in viewport.visibleMonths {
            guard let selected = month.visibleDays.first(where: { $0.daystamp == selectedDayStamp })
            else { continue }

            let screenY = selected.yPosition + anchorOffset
            guard screenY > -buffer && screenY < height + buffer else { return nil }

            // A row is the days sharing a centre line, and the comparison is exact because
            // every one of them was computed from the same `yPosition` by the same arithmetic.
            let row = month.visibleDays.filter { $0.yPosition == selected.yPosition }

            return SelectionMarker(
                // The row's first day, so the identity survives everything that is not a change
                // of row — including the calculator re-origining at a month boundary, which
                // moves every position in this layer but changes no day's date.
                rowID: (row.first ?? selected).daystamp.rawValue,
                centerX: selected.xPosition + dayWidth / 2,
                centerY: selected.yPosition + weekHeight / 2,
                rowDigits: row.map { day in
                    RowDigit(
                        id: day.daystamp.rawValue,
                        dayNumber: day.dayNumber,
                        isToday: day.isToday,
                        centerX: day.xPosition + dayWidth / 2
                    )
                }
            )
        }

        return nil
    }
}

// MARK: - Render Models

private struct SelectionMarker {
    /// The row the disc belongs to. Its identity in the view tree, and so the whole of the
    /// glide-or-bloom rule: same row, same view, the position animates.
    let rowID: Int
    let centerX: CGFloat
    let centerY: CGFloat
    /// Every day the disc can travel over — the days of its own row.
    let rowDigits: [RowDigit]
}

private struct RowDigit: Identifiable {
    let id: Int
    let dayNumber: String
    let isToday: Bool
    let centerX: CGFloat
}
