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
//
// **It does not know a selection exists**, and that is load-bearing rather than tidy. The disc
// is `CalendarSelectionLayer`, drawn above this one; while it lived here, `selectedDayStamp`
// was an input, so every tap and every card swipe rebuilt every day cell in both copies of the
// grid to move one circle. Do not reintroduce it here.
struct CalendarGridView: View, @MainActor Equatable {
    let viewport: ViewportData
    /// The scroll offset the viewport was built for. Visibility is decided against it, not
    /// against the live offset, so the layer stays stable between re-anchors.
    let anchorOffset: CGFloat
    let calculator: MonthCalculator
    let dayDisplayStates: [Daystamp: DayDisplayState]
    /// Stands in for `dayDisplayStates` in `==`. See `CalendarState.dayDisplayStatesVersion`
    /// for why the dictionary itself is not what gets compared.
    let dayDisplayStatesVersion: Int
    let today: Daystamp
    let width: CGFloat
    let height: CGFloat
    let theme: AccentTheme

    // Resolved at construction rather than read per day cell, for the same reason
    // `CalendarPalette` exists: a named asset is a lookup, not a literal. The explicit init is
    // what buys that — a computed property would resolve again on every bar and every numeral.
    private let accent: Color
    private let predictedText: Color

    init(
        viewport: ViewportData,
        anchorOffset: CGFloat,
        calculator: MonthCalculator,
        dayDisplayStates: [Daystamp: DayDisplayState],
        dayDisplayStatesVersion: Int,
        today: Daystamp,
        width: CGFloat,
        height: CGFloat,
        theme: AccentTheme
    ) {
        self.viewport = viewport
        self.anchorOffset = anchorOffset
        self.calculator = calculator
        self.dayDisplayStates = dayDisplayStates
        self.dayDisplayStatesVersion = dayDisplayStatesVersion
        self.today = today
        self.width = width
        self.height = height
        self.theme = theme
        self.accent = theme.accent
        self.predictedText = theme.predictedDayText
    }

    // `theme` stands in for the two resolved colours — they are derived from it, and `Color`
    // is not usefully comparable anyway. Leaving it out would freeze the grid on the old
    // accent until some unrelated input changed.
    //
    // `dayDisplayStates` is compared, but by proxy. This runs twice on every frame of a scroll,
    // and walking a map of the whole loaded range to learn that nothing in it moved is the most
    // expensive way to answer that. The reducer stamps a version when it writes the map, so the
    // question costs one integer instead.
    static func == (lhs: CalendarGridView, rhs: CalendarGridView) -> Bool {
        lhs.calculator === rhs.calculator
            && lhs.anchorOffset == rhs.anchorOffset
            && lhs.width == rhs.width
            && lhs.height == rhs.height
            && lhs.today == rhs.today
            && lhs.theme == rhs.theme
            && lhs.viewport == rhs.viewport
            && lhs.dayDisplayStatesVersion == rhs.dayDisplayStatesVersion
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

        // Culled on the same terms its days are. The viewport reaches further than the cull
        // does, so the outermost months contribute nothing but a title — and a title parked a
        // screen and a half off the top is still a laid-out, positioned `Text`.
        if isHeaderVisible(for: month) {
            Text(calculator.getMonthName(for: month.monthOffset))
                .font(.title3)
                .fontWeight(.heavy)
                .foregroundColor(.secondary)
                .frame(width: width, height: CalendarConstants.monthHeaderHeight)
                .position(x: width / 2, y: month.yPosition + CalendarConstants.monthHeaderHeight / 2)
        }

        // MARK: - Layer 1: Fertile window lines
        ForEach(content.fertileLines) { line in
            fertileLine(line)
        }

        // MARK: - Layer 2: Period rectangles
        ForEach(content.periodBars) { bar in
            periodBar(bar)
        }

        // MARK: - Layer 3: Day cells
        //
        // The last layer this view draws. The selection disc stands above it, in
        // `CalendarSelectionLayer`, and is a sibling of this whole grid rather than part of it.
        ForEach(content.cells) { cell in
            dayCell(cell)
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
                        CalendarPalette.ovulationLine,
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
                            .stroke(CalendarPalette.background, lineWidth: 2)
                    )
            }

            // Nothing here knows about the selection: the disc is a layer above, and it brings
            // its own inverted numeral with it.
            Text(cell.dayNumber)
                .font(DayNumberFont.font(isToday: cell.isToday))
                .foregroundColor(
                    cell.isToday ? .white :
                    cell.isPredictedPeriod ? predictedText :
                    cell.isInPeriod ? .white :
                    cell.daystamp > today ? CalendarPalette.futureDay :
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

    /// How far past the screen's own edges a thing is still built for. Measured against
    /// `anchorOffset` — the offset the layer was drawn for — and never the live scroll, which
    /// is what lets a scroll frame slide the whole layer instead of rebuilding it.
    private var visibilityBuffer: CGFloat {
        height * CalendarConstants.dayVisibilityBufferRatio
    }

    private func isHeaderVisible(for month: VisibleMonth) -> Bool {
        let buffer = visibilityBuffer
        let top = month.yPosition + anchorOffset
        return top + CalendarConstants.monthHeaderHeight > -buffer && top < height + buffer
    }

    // One pass per month: culls off-screen days and resolves each layer's geometry, so the
    // three ForEach layers only ever walk the elements they actually draw.
    private func monthContent(for month: VisibleMonth) -> MonthContent {
        let dayWidth = self.dayWidth
        let weekHeight = calculator.weekHeight
        let buffer = visibilityBuffer

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

        return content
    }

    private func dotColors(for state: DayDisplayState?) -> [Color] {
        guard let state = state, !state.tagCategories.isEmpty || state.hasComment else { return [] }

        var colors = state.tagCategories.sorted().map { Color.tagColor(for: $0) }
        if state.hasComment {
            colors.append(CalendarPalette.commentDot)
        }
        return colors
    }
}

// MARK: - Render Models

private struct MonthContent {
    var cells: [RenderDay] = []
    var periodBars: [PeriodBar] = []
    var fertileLines: [FertileLine] = []
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
        case .fertile:   return CalendarPalette.fertileLine
        case .ovulation: return CalendarPalette.ovulationLine
        }
    }
}
