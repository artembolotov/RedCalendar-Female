//
//  ViewportCalculator.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.08.2025.
//
import Foundation

class ViewportCalculator {
    static func calculateDynamicViewport(
        scrollOffset: CGFloat,
        screenHeight: CGFloat,
        screenWidth: CGFloat,
        calculator: MonthCalculator,
        today: Daystamp
    ) -> ViewportData {

        let bufferHeight = screenHeight * CalendarConstants.viewportBufferRatio
        let viewportTop = -scrollOffset - bufferHeight
        let viewportBottom = -scrollOffset + screenHeight + bufferHeight

        // Content grows downwards while scrollOffset grows upwards, so the estimate is taken
        // from the viewport's own content-space position — not from the raw scroll offset.
        let estimatedMonthOffset = Int(viewportTop / CalendarConstants.averageMonthHeight)

        var monthOffset = findOptimalStartMonth(
            estimatedOffset: estimatedMonthOffset,
            viewportTop: viewportTop,
            calculator: calculator
        )

        var visibleMonths: [VisibleMonth] = []
        var currentY = calculator.getYPosition(for: monthOffset)

        while currentY > viewportTop && monthOffset > CalendarConstants.minMonthOffset {
            monthOffset -= 1
            currentY = calculator.getYPosition(for: monthOffset)
        }

        while currentY < viewportBottom && monthOffset <= CalendarConstants.maxMonthOffset {
            let monthHeight = calculator.getMonthHeight(for: monthOffset)
            let monthBottom = currentY + monthHeight

            if monthBottom > viewportTop && currentY < viewportBottom {
                let visibleMonth = createVisibleMonth(
                    monthOffset: monthOffset,
                    yPosition: currentY,
                    height: monthHeight,
                    screenWidth: screenWidth,
                    calculator: calculator,
                    today: today
                )
                visibleMonths.append(visibleMonth)
            }

            currentY += monthHeight
            monthOffset += 1

            if visibleMonths.count >= 12 {
                break
            }
        }

        return ViewportData(visibleMonths: visibleMonths)
    }

    private static func findOptimalStartMonth(
        estimatedOffset: Int,
        viewportTop: CGFloat,
        calculator: MonthCalculator
    ) -> Int {
        let clampedEstimate = max(CalendarConstants.minMonthOffset, min(CalendarConstants.maxMonthOffset, estimatedOffset))

        let estimatedY = calculator.getYPosition(for: clampedEstimate)
        let estimatedHeight = calculator.getMonthHeight(for: clampedEstimate)

        if estimatedY <= viewportTop && (estimatedY + estimatedHeight) >= viewportTop {
            return clampedEstimate
        }

        var low = CalendarConstants.minMonthOffset
        var high = CalendarConstants.maxMonthOffset

        while high - low > 1 {
            let mid = (low + high) / 2
            let midY = calculator.getYPosition(for: mid)

            if midY < viewportTop {
                low = mid
            } else {
                high = mid
            }
        }

        return low
    }

    private static func createVisibleMonth(
        monthOffset: Int,
        yPosition: CGFloat,
        height: CGFloat,
        screenWidth: CGFloat,
        calculator: MonthCalculator,
        today: Daystamp
    ) -> VisibleMonth {

        let monthCells = calculator.getMonthCells(for: monthOffset)
        let weeksCount = calculator.getWeeksCount(for: monthOffset)
        let weekHeight = calculator.weekHeight

        var visibleDays: [VisibleDay] = []
        visibleDays.reserveCapacity(weeksCount * 7)

        let headerHeight: CGFloat = CalendarConstants.monthHeaderHeight
        let horizontalPadding = CalendarConstants.horizontalPadding
        let gridStartY = yPosition + headerHeight
        let dayWidth = (screenWidth - horizontalPadding) / 7

        for weekIndex in 0..<weeksCount {
            let weekY = gridStartY + CGFloat(weekIndex) * (weekHeight + CalendarConstants.gridVerticalSpacing)

            for dayIndex in 0..<7 {
                let cellIndex = weekIndex * 7 + dayIndex
                if cellIndex < monthCells.count, let cell = monthCells[cellIndex] {
                    let dayX = horizontalPadding / 2 + CGFloat(dayIndex) * dayWidth

                    let visibleDay = VisibleDay(
                        daystamp: cell.daystamp,
                        isToday: cell.daystamp == today,
                        xPosition: dayX,
                        yPosition: weekY,
                        dayNumber: cell.dayNumber
                    )
                    visibleDays.append(visibleDay)
                }
            }
        }

        return VisibleMonth(
            monthOffset: monthOffset,
            yPosition: yPosition,
            height: height,
            visibleDays: visibleDays
        )
    }
}
