//
//  CalendarGridView.swift
//  RedCalendar-Female
//

import SwiftUI

// Everything drawn on top of the scroll view: month titles, period bars, fertile lines and
// day cells.
//
// It is `Equatable` on purpose. Scrolling moves the whole layer with `.offset`, so a frame
// that only changed the scroll position leaves every input here identical and SwiftUI skips
// the body entirely — day cells are rebuilt only when the viewport is re-anchored or the
// data behind it changes.
struct CalendarGridView: View, Equatable {
    let viewport: ViewportData
    /// The scroll offset the viewport was built for. Visibility is decided against it, not
    /// against the live offset, so the layer stays stable between re-anchors.
    let anchorOffset: CGFloat
    let calculator: MonthCalculator
    let dayDisplayStates: [Daystamp: DayDisplayState]
    let selectedDayStamp: Daystamp?
    let today: Daystamp
    let width: CGFloat
    let height: CGFloat
    let theme: AccentTheme
    let reduceMotion: Bool
    /// How far the selection just moved, in days. Picks the disc's curve and nothing else.
    let selectionTravel: Int
    /// False in the blurred copy drawn into the top band — see `selectionAnimation`.
    let animatesSelection: Bool

    // Resolved at construction rather than read per day cell, for the same reason `Palette`
    // exists: a named asset is a lookup, not a literal. The explicit init is what buys that —
    // a computed property would resolve again on every bar and every numeral.
    private let accent: Color
    private let predictedText: Color

    init(
        viewport: ViewportData,
        anchorOffset: CGFloat,
        calculator: MonthCalculator,
        dayDisplayStates: [Daystamp: DayDisplayState],
        selectedDayStamp: Daystamp?,
        today: Daystamp,
        width: CGFloat,
        height: CGFloat,
        theme: AccentTheme,
        reduceMotion: Bool,
        selectionTravel: Int,
        animatesSelection: Bool
    ) {
        self.viewport = viewport
        self.anchorOffset = anchorOffset
        self.calculator = calculator
        self.dayDisplayStates = dayDisplayStates
        self.selectedDayStamp = selectedDayStamp
        self.today = today
        self.width = width
        self.height = height
        self.theme = theme
        self.accent = theme.accent
        self.predictedText = theme.predictedDayText
        self.reduceMotion = reduceMotion
        self.selectionTravel = selectionTravel
        self.animatesSelection = animatesSelection
    }

    // `theme` stands in for the two resolved colours — they are derived from it, and `Color`
    // is not usefully comparable anyway. Leaving it out would freeze the grid on the old
    // accent until some unrelated input changed.
    //
    // `selectionTravel` is deliberately absent, and it is the one input here that must stay
    // absent. It decides how a change animates, never what is drawn — so the update that
    // arrives *after* a selection has settled, carrying nothing but the travel falling back to
    // zero, has to compare equal and skip the body. Include it and every day chosen costs two
    // full rebuilds of the grid instead of one.
    static func == (lhs: CalendarGridView, rhs: CalendarGridView) -> Bool {
        lhs.calculator === rhs.calculator
            && lhs.reduceMotion == rhs.reduceMotion
            && lhs.animatesSelection == rhs.animatesSelection
            && lhs.anchorOffset == rhs.anchorOffset
            && lhs.width == rhs.width
            && lhs.height == rhs.height
            && lhs.today == rhs.today
            && lhs.selectedDayStamp == rhs.selectedDayStamp
            && lhs.theme == rhs.theme
            && lhs.viewport == rhs.viewport
            && lhs.dayDisplayStates == rhs.dayDisplayStates
    }

    private var dayWidth: CGFloat {
        (width - CalendarConstants.horizontalPadding) / 7
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(viewport.visibleMonths, id: \.monthOffset) { month in
                monthLayers(for: month)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func monthLayers(for month: VisibleMonth) -> some View {
        let content = monthContent(for: month)

        Text(calculator.getMonthName(for: month.monthOffset))
            .font(.title3)
            .fontWeight(.heavy)
            .foregroundColor(.secondary)
            .frame(width: width, height: CalendarConstants.monthHeaderHeight)
            .position(x: width / 2, y: month.yPosition + CalendarConstants.monthHeaderHeight / 2)

        // MARK: - Layer 1: Fertile window lines
        ForEach(content.fertileLines) { line in
            fertileLine(line)
        }

        // MARK: - Layer 2: Period rectangles
        ForEach(content.periodBars) { bar in
            periodBar(bar)
        }

        // MARK: - Layer 3: Day cells
        ForEach(content.cells) { cell in
            dayCell(cell)
        }

        // MARK: - Layer 4: Selection disc
        //
        // Its own layer above the cells, not a circle inside the selected one, and that is what
        // lets it travel: a disc belonging to no cell can move from one day to the next, and
        // the numeral it covers is inverted *by the disc* rather than by its own state — so a
        // disc halfway between two days leaves both neighbours reading correctly, which a pair
        // of cross-fading numerals cannot do.
        //
        // The disc animates on one condition: that it can stay where it is on screen. Within a
        // row it can — the calendar has no reason to move, since the row it centres on has not
        // changed — so the disc travels. A change of row is the opposite case: the calendar
        // flies to the new row, and anything the disc does during that flight is carried by a
        // moving grid on top of its own motion. That reads as the disc falling in rather than
        // as it being placed, whichever way the flight goes.
        //
        // Hence both of the pieces below, and neither is optional. The animation watches
        // `centerX` alone, so a move that changes the row cannot animate even when it changes
        // the column too; and the identity is the row, so such a move replaces the view rather
        // than reusing it. Without the identity the disc would fly the diagonal; without the
        // narrow value it would fly the vertical.
        //
        // A replacement is therefore instant, and deliberately so — no transition, and no
        // animated transaction for a default one to attach itself to. The disc simply is where
        // the selection is, exactly as it was before it could travel at all.
        if let marker = content.selection {
            selectionLayer(marker)
                .id(marker.rowID)
        }
    }

    @ViewBuilder
    private func fertileLine(_ line: FertileLine) -> some View {
        Group {
            if case .ovulation(let confirmed) = line.phase, !confirmed {
                // Same language as the period bar: a prediction is drawn as an outline, never
                // as a faded version of the confirmed colour.
                HorizontalRule()
                    .stroke(
                        Palette.ovulationLine,
                        style: StrokeStyle(
                            lineWidth: CalendarConstants.fertileLineHeight,
                            dash: CalendarConstants.predictedOvulationDash
                        )
                    )
            } else {
                RoundedCorners(radius: CalendarConstants.fertileLineHeight / 2, corners: line.corners)
                    .fill(line.phase.lineColor)
            }
        }
        .frame(width: dayWidth, height: CalendarConstants.fertileLineHeight)
        .position(x: line.centerX, y: line.centerY)
    }

    @ViewBuilder
    private func periodBar(_ bar: PeriodBar) -> some View {
        // Continuous corners exist only on `RoundedRectangle`, which rounds all four — there is
        // no per-corner API to match `RoundedCorners`. So the bar is drawn as a whole rounded
        // rectangle widened past the cell on every side where the run continues, then clipped
        // back to the cell: the corners that must stay square fall outside the clip and
        // neighbouring days meet flush. The overhang clears the corner's full reach (~1.5x the
        // radius) and, for the predicted bar, takes its vertical stroke out with it.
        let radius = CalendarConstants.periodBarCornerRadius
        let overhang = radius * 2
        let lead = bar.corners.contains(.topLeft) ? 0 : overhang
        let trail = bar.corners.contains(.topRight) ? 0 : overhang
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Group {
            if bar.isPredicted {
                // `strokeBorder`, not `stroke`: the outline stays inside `periodBarHeight`
                // instead of straddling the edge and losing half its weight to the clip.
                shape.strokeBorder(
                    accent,
                    lineWidth: CalendarConstants.predictedBarStrokeWidth
                )
            } else {
                shape.fill(accent)
            }
        }
        .frame(width: dayWidth + lead + trail, height: CalendarConstants.periodBarHeight)
        .offset(x: (trail - lead) / 2)
        .frame(width: dayWidth, height: CalendarConstants.periodBarHeight)
        .clipped()
        .position(x: bar.centerX, y: bar.centerY)
    }

    /// The mark on the day currently chosen: the page's own colour inverted into a ⌀28 disc,
    /// and the row's numerals showing through it.
    ///
    /// **Two things travel and the numerals are not among them.** They are laid out in the
    /// grid's own coordinates and stay on their days; what moves is the disc, and the hole in
    /// the inverted layer that the disc is drawn through. Laying the numerals out relative to
    /// the disc instead — which is smaller code, and was the first version of this — quietly
    /// makes the disc carry the *destination's* digit for the whole flight: a view's content is
    /// built once per body pass and only `.position` interpolates, so the disc would leave day
    /// 5 already showing a 6. The number would change before the motion rather than because of
    /// it.
    ///
    /// The two travelling pieces are separate views, so they are kept in step by construction
    /// rather than by hope: one animation value, one curve, and only `x` interpolating in
    /// either of them.
    private func selectionLayer(_ marker: SelectionMarker) -> some View {
        let size = CalendarConstants.dayIndicatorSize
        let animation = selectionAnimation

        return ZStack {
            // The ring is what punches the disc out of a solid period bar, exactly as the today
            // marker's does — and here it travels, so a run of period days is carved by a
            // moving hole rather than a blinking one.
            Circle()
                .fill(Palette.selected)
                .overlay(
                    Circle()
                        .stroke(Palette.background, lineWidth: 2)
                )
                .frame(width: size, height: size)
                .position(x: marker.centerX, y: marker.centerY)
                .animation(animation, value: marker.centerX)

            // The row's numerals again, in the page colour, revealed only where the disc is.
            // Only the row: the disc travels along one, so these are every digit it can pass
            // over, and seven of them cost nothing next to inverting the whole grid on the off
            // chance.
            //
            // Held to a strip one disc tall rather than left to fill the grid. A mask is an
            // offscreen pass over the bounds it is given, and this one runs on every frame of a
            // flight; over the whole grid that is a screen-sized buffer per frame to show a
            // ⌀28 hole.
            ZStack {
                ForEach(marker.rowDigits) { digit in
                    Text(digit.dayNumber)
                        .font(DayNumber.font(isToday: digit.isToday))
                        .foregroundColor(Palette.background)
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

    /// How the disc gets where it is going, or `nil` for straight there.
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

    @ViewBuilder
    private func dayCell(_ cell: RenderDay) -> some View {
        ZStack {
            if cell.isToday {
                // The ring is what keeps the marker readable on a solid period bar — without
                // it a red circle on red simply disappears.
                Circle()
                    .fill(accent)
                    .frame(width: CalendarConstants.dayIndicatorSize, height: CalendarConstants.dayIndicatorSize)
                    .overlay(
                        Circle()
                            .stroke(Palette.background, lineWidth: 2)
                    )
            }

            // Nothing here knows about the selection: the disc is a layer above, and it brings
            // its own inverted numeral with it.
            Text(cell.dayNumber)
                .font(DayNumber.font(isToday: cell.isToday))
                .foregroundColor(
                    cell.isToday ? .white :
                    cell.isPredictedPeriod ? predictedText :
                    cell.isInPeriod ? .white :
                    cell.daystamp > today ? Palette.futureDay :
                    .primary
                )

            if !cell.dotColors.isEmpty {
                HStack(spacing: CalendarConstants.tagDotSpacing) {
                    ForEach(cell.dotColors.indices, id: \.self) { index in
                        Circle()
                            .fill(cell.dotColors[index])
                            .frame(width: CalendarConstants.tagDotSize, height: CalendarConstants.tagDotSize)
                    }
                }
                .offset(y: CalendarConstants.tagDotsOffset)
            }
        }
        .position(x: cell.centerX, y: cell.centerY)
    }

    // MARK: - Private Methods

    // One pass per month: culls off-screen days and resolves each layer's geometry, so the
    // three ForEach layers only ever walk the elements they actually draw.
    private func monthContent(for month: VisibleMonth) -> MonthContent {
        let dayWidth = self.dayWidth
        let weekHeight = calculator.weekHeight
        let buffer = height * CalendarConstants.dayVisibilityBufferRatio

        var content = MonthContent()

        for day in month.visibleDays {
            let screenY = day.yPosition + anchorOffset
            guard screenY > -buffer && screenY < height + buffer else { continue }

            let centerX = day.xPosition + dayWidth / 2
            let centerY = day.yPosition + weekHeight / 2
            let state = dayDisplayStates[day.daystamp]

            var isInPeriod = false
            var isPredictedPeriod = false
            if case .period(let position, let isPredicted) = state?.cyclePhase {
                isInPeriod = true
                isPredictedPeriod = isPredicted
                content.periodBars.append(
                    PeriodBar(
                        id: day.daystamp.rawValue,
                        centerX: centerX,
                        centerY: centerY,
                        corners: position.corners,
                        isPredicted: isPredicted
                    )
                )
            }

            if let fertileWindow = state?.fertileWindow {
                content.fertileLines.append(
                    FertileLine(
                        id: day.daystamp.rawValue,
                        centerX: centerX,
                        centerY: centerY + CalendarConstants.fertileLineOffset,
                        corners: fertileWindow.position.corners,
                        phase: fertileWindow.phase
                    )
                )
            }

            content.cells.append(
                RenderDay(
                    daystamp: day.daystamp,
                    dayNumber: day.dayNumber,
                    isToday: day.isToday,
                    isInPeriod: isInPeriod,
                    isPredictedPeriod: isPredictedPeriod,
                    centerX: centerX,
                    centerY: centerY,
                    dotColors: dotColors(for: state)
                )
            )
        }

        content.selection = selectionMarker(in: content.cells)

        return content
    }

    /// Where the disc sits in this month, and what it may pass over on the way.
    ///
    /// Built from the cells this month has already resolved rather than from a second walk of
    /// the viewport: a day the cull dropped is off screen, and so is the row around it.
    private func selectionMarker(in cells: [RenderDay]) -> SelectionMarker? {
        guard let selectedDayStamp = selectedDayStamp,
              let selected = cells.first(where: { $0.daystamp == selectedDayStamp })
        else { return nil }

        // A row is the days sharing a centre line, and the comparison is exact because every
        // one of them was computed from the same `yPosition` by the same arithmetic.
        let row = cells.filter { $0.centerY == selected.centerY }

        return SelectionMarker(
            // The row's first day, so the identity survives everything that is not a change of
            // row — including the calculator re-origining at a month boundary, which moves
            // every position in this grid but changes no day's date.
            rowID: row.first?.id ?? selected.id,
            centerX: selected.centerX,
            centerY: selected.centerY,
            rowDigits: row
        )
    }

    private func dotColors(for state: DayDisplayState?) -> [Color] {
        guard let state = state, !state.tagCategories.isEmpty || state.hasComment else { return [] }

        var colors = state.tagCategories.sorted().map { Color.tagColor(for: $0) }
        if state.hasComment {
            colors.append(Palette.commentDot)
        }
        return colors
    }
}

// MARK: - Render Models

private struct MonthContent {
    var cells: [RenderDay] = []
    var periodBars: [PeriodBar] = []
    var fertileLines: [FertileLine] = []
    var selection: SelectionMarker?
}

private struct SelectionMarker {
    /// The row the disc belongs to. Its identity in the view tree, and so the whole of the
    /// glide-or-bloom rule: same row, same view, the position animates.
    let rowID: Int
    let centerX: CGFloat
    let centerY: CGFloat
    /// Every day the disc can travel over — the cells of its own row.
    let rowDigits: [RenderDay]
}

// Stable identity (daystamp) keeps SwiftUI diffing cheap while the viewport shifts.
private struct RenderDay: Identifiable {
    let daystamp: Daystamp
    let dayNumber: String
    let isToday: Bool
    let isInPeriod: Bool
    let isPredictedPeriod: Bool
    let centerX: CGFloat
    let centerY: CGFloat
    let dotColors: [Color]

    var id: Int { daystamp.rawValue }
}

private struct PeriodBar: Identifiable {
    let id: Int
    let centerX: CGFloat
    let centerY: CGFloat
    let corners: UIRectCorner
    let isPredicted: Bool
}

private struct FertileLine: Identifiable {
    let id: Int
    let centerX: CGFloat
    let centerY: CGFloat
    let corners: UIRectCorner
    let phase: FertilePhase
}

// A single horizontal rule across the rect, so the ovulation day can be stroked (and dashed)
// rather than filled.
private struct HorizontalRule: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - Palette

// The colours that do not depend on the chosen accent, resolved once instead of per day cell —
// named assets and UIColor bridging are lookups, not literals. Dynamic colors still resolve
// against the current trait collection.
//
// The accent-derived pair — the period bar, the today marker, the predicted outline and the
// numeral inside it — cannot live here: they follow `AccentTheme`, so they are stored on the
// view and resolved in its init.
// Built once rather than per numeral, for the same reason `Palette` exists: the grid draws
// upwards of forty of these on a pass, and every one of them was constructing a `Font` from
// scratch. The selected row draws its digits a second time inside the disc's layer, and that
// one runs on a flight.
private enum DayNumber {
    static let regular = Font.system(size: 16, weight: .medium)
    static let today = Font.system(size: 16, weight: .bold)

    static func font(isToday: Bool) -> Font {
        isToday ? today : regular
    }
}

private enum Palette {
    static let selected = Color("SelectedDayColor")
    static let background = Color("AppBackgroundColor")
    static let futureDay = Color(UIColor.secondaryLabel)
    static let commentDot = Color(UIColor.secondaryLabel)
    // Assets rather than literals: these carry their weight in a 2pt line, and both the
    // fertile line's alpha and the ovulation orange read very differently against white and
    // against a near-black background, so each needs its own light/dark variant.
    static let fertileLine = Color("FertileLineColor")
    static let ovulationLine = Color("OvulationLineColor")
}

private extension SegmentPosition {
    var corners: UIRectCorner {
        switch self {
        case .start:  return [.topLeft, .bottomLeft]
        case .end:    return [.topRight, .bottomRight]
        case .middle: return []
        case .single: return .allCorners
        }
    }
}

private extension FertilePhase {
    var lineColor: Color {
        switch self {
        case .fertile:   return Palette.fertileLine
        case .ovulation: return Palette.ovulationLine
        }
    }
}
