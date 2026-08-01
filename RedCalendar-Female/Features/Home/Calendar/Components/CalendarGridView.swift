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

    static func == (lhs: CalendarGridView, rhs: CalendarGridView) -> Bool {
        lhs.calculator === rhs.calculator
            && lhs.anchorOffset == rhs.anchorOffset
            && lhs.width == rhs.width
            && lhs.height == rhs.height
            && lhs.today == rhs.today
            && lhs.selectedDayStamp == rhs.selectedDayStamp
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
            RoundedCorners(radius: CalendarConstants.fertileLineHeight / 2, corners: line.corners)
                .fill(line.color)
                .frame(width: dayWidth, height: CalendarConstants.fertileLineHeight)
                .position(x: line.centerX, y: line.centerY)
        }

        // MARK: - Layer 2: Period rectangles
        ForEach(content.periodBars) { bar in
            RoundedCorners(radius: CalendarConstants.periodBarCornerRadius, corners: bar.corners)
                .fill(Palette.period.opacity(bar.isPredicted ? 0.35 : 1.0))
                .frame(width: dayWidth, height: CalendarConstants.periodBarHeight)
                .position(x: bar.centerX, y: bar.centerY)
        }

        // MARK: - Layer 3: Day cells
        ForEach(content.cells) { cell in
            dayCell(cell)
        }
    }

    @ViewBuilder
    private func dayCell(_ cell: RenderDay) -> some View {
        let isSelected = selectedDayStamp == cell.daystamp

        ZStack {
            if cell.isToday {
                Circle()
                    .fill(Palette.today)
                    .frame(width: CalendarConstants.dayIndicatorSize, height: CalendarConstants.dayIndicatorSize)
            }

            if isSelected {
                Circle()
                    .fill(Palette.selected)
                    .frame(width: CalendarConstants.dayIndicatorSize, height: CalendarConstants.dayIndicatorSize)
                    .overlay(
                        Circle()
                            .stroke(Palette.background, lineWidth: 2)
                    )
            }

            Text(cell.dayNumber)
                .font(.system(size: 16, weight: cell.isToday ? .bold : .medium))
                .foregroundColor(
                    isSelected ? Palette.background :
                    cell.isToday ? .white :
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
            if case .period(let position, let isPredicted) = state?.cyclePhase {
                isInPeriod = true
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
                        color: fertileWindow.phase.lineColor
                    )
                )
            }

            content.cells.append(
                RenderDay(
                    daystamp: day.daystamp,
                    dayNumber: day.dayNumber,
                    isToday: day.isToday,
                    isInPeriod: isInPeriod,
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
}

// Stable identity (daystamp) keeps SwiftUI diffing cheap while the viewport shifts.
private struct RenderDay: Identifiable {
    let daystamp: Daystamp
    let dayNumber: String
    let isToday: Bool
    let isInPeriod: Bool
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
    let color: Color
}

// MARK: - Palette

// Resolved once instead of per day cell — named assets and UIColor bridging are lookups,
// not literals. Dynamic colors still resolve against the current trait collection.
private enum Palette {
    static let period = Color.red
    static let today = Color.red
    static let selected = Color("SelectedDayColor")
    static let background = Color(UIColor.systemBackground)
    static let futureDay = Color(UIColor.tertiaryLabel)
    static let commentDot = Color(UIColor.tertiaryLabel)
    // An asset rather than a literal: the fertile line's weight comes from its alpha, and one
    // alpha reads very differently against white and against black, so it carries a light/dark
    // variant. The ovulation orange is full strength and needs no such split.
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
