//
//  MonthCalculator.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.08.2025.
//
import SwiftUI

final class MonthCalculator: ObservableObject {
    let currentDate: Date
    let currentYear: Int
    let screenHeight: CGFloat
    
    private let calendar: Calendar
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter
    }()
    
    private let minMonthOffset: Int = CalendarConstants.minMonthOffset
    private let maxMonthOffset: Int = CalendarConstants.maxMonthOffset
    private let monthHeaderHeight: CGFloat = CalendarConstants.monthHeaderHeight
    private let bottomSpacing: CGFloat = CalendarConstants.bottomSpacing
    private let gridVerticalSpacing: CGFloat = CalendarConstants.gridVerticalSpacing
        
    // None of these are evicted from, and none of them need to be: every key is a month offset,
    // and every offset that reaches this class has already been clamped to
    // `CalendarConstants.minMonthOffset ... maxMonthOffset` — by `ViewportCalculator` on both
    // ends of its walk, by `CalendarView.centerDaystamp`, and by the scroll rail itself. So the
    // ceiling is 1441 entries each, by construction rather than by policy.
    //
    // In bytes that is ~46KB apiece for the three below that hold a number, ~58KB of month
    // names, and ~2MB of month cells — and the last of those only fills if someone drags
    // through all 120 years, since `getMonthCells` and `getMonthName` are demand-driven where
    // the other three are filled outright by the first measurement of the rail. A calculator
    // does not outlive a change of locale, first weekday, day or layout metrics either; it is
    // replaced whole, caches and all.
    //
    // There was an eviction pass here once. It was gated on `weekCountCache.count`, which the
    // rail measurement saturates permanently, and it dropped entries by `abs(offset)` —
    // distance from today, not from what is on screen — so it would have deleted the months
    // being drawn precisely when someone had scrolled far enough to make the caches worth
    // trimming. It also aimed at the two cheapest caches while `cumulativePositionCache`, which
    // is computed from them and never dropped, kept everything it had. It never actually ran.
    private var weekCountCache: [Int: Int] = [:]
    private var monthHeightCache: [Int: CGFloat] = [:]
    private var monthCellsCache: [Int: [MonthCell?]] = [:]
    private var monthNameCache: [Int: String] = [:]
    private var cumulativePositionCache: [Int: CGFloat] = [0: 0]

    // The rail the scroll view is clamped to, kept once it has been worked out.
    //
    // It is by far the most expensive thing this class computes: the rail is the content-space
    // position of the outermost months, so reaching it measures every month in between — a
    // `date(byAdding:)` and a `range(of:in:for:)` each. `scrollViewDidScroll` asks for it on
    // every frame, which made the first frame of the first drag pay for all of them at once.
    private var cachedScrollLimits: (min: CGFloat, max: CGFloat)?


    private(set) var cachedLocaleIdentifier: String
    private(set) var cachedFirstWeekday: Int
    
    var weekHeight: CGFloat {
        return floor(max(50, (screenHeight - CalendarConstants.weekdaysHeaderHeight) / 15))
    }
    
    init(currentDate: Date, screenHeight: CGFloat, calendar: Calendar) {
        self.currentDate = currentDate
        self.screenHeight = screenHeight
        self.calendar = calendar
        self.currentYear = calendar.component(.year, from: currentDate)
        self.cachedLocaleIdentifier = Locale.current.identifier
        self.cachedFirstWeekday = calendar.firstWeekday
    }
    
    private func checkAndInvalidateCacheIfNeeded() {
        let currentLocale = Locale.current.identifier
        let currentFirstWeekday = calendar.firstWeekday
        
        if currentLocale != cachedLocaleIdentifier || currentFirstWeekday != cachedFirstWeekday {
            weekCountCache.removeAll()
            monthHeightCache.removeAll()
            monthCellsCache.removeAll()
            monthNameCache.removeAll()
            cumulativePositionCache = [0: 0]
            // Month heights follow the first weekday, so the rail moves with it too.
            cachedScrollLimits = nil

            dateFormatter.locale = Locale.current
            
            cachedLocaleIdentifier = currentLocale
            cachedFirstWeekday = currentFirstWeekday
        }
    }
    
    func getWeeksCount(for monthOffset: Int) -> Int {
        checkAndInvalidateCacheIfNeeded()
        
        if let cached = weekCountCache[monthOffset] {
            return cached
        }
        
        let monthDate = getMonthDate(for: monthOffset)
        let range = calendar.range(of: .weekOfMonth, in: .month, for: monthDate) ?? 1..<2
        let weeksCount = range.count
        
        weekCountCache[monthOffset] = weeksCount
        return weeksCount
    }
    
    func getMonthHeight(for monthOffset: Int) -> CGFloat {
        checkAndInvalidateCacheIfNeeded()
        
        if let cached = monthHeightCache[monthOffset] {
            return cached
        }
        
        let weeksCount = getWeeksCount(for: monthOffset)
        let gridHeight = CGFloat(weeksCount) * weekHeight + CGFloat(weeksCount - 1) * gridVerticalSpacing
        let totalHeight = monthHeaderHeight + gridHeight + bottomSpacing
        
        monthHeightCache[monthOffset] = totalHeight
        return totalHeight
    }
    
    private func buildMonthDays(for monthOffset: Int) -> [Date?] {
        let monthDate = getMonthDate(for: monthOffset)

        guard let monthRange = calendar.range(of: .day, in: .month, for: monthDate),
              let firstOfMonth = calendar.dateInterval(of: .month, for: monthDate)?.start else {
            return []
        }
        
        let weeksCount = getWeeksCount(for: monthOffset)
        var days: [Date?] = Array(repeating: nil, count: weeksCount * 7)
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let firstWeekdayIndex = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        for day in monthRange {
            let dayIndex = firstWeekdayIndex + day - 1
            if dayIndex < days.count {
                days[dayIndex] = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
            }
        }
        
        return days
    }

    // Per-day calendar work (day number, daystamp) is the same for every viewport rebuild,
    // so it is paid once per month instead of on every scroll step.
    func getMonthCells(for monthOffset: Int) -> [MonthCell?] {
        checkAndInvalidateCacheIfNeeded()

        if let cached = monthCellsCache[monthOffset] {
            return cached
        }

        let cells: [MonthCell?] = buildMonthDays(for: monthOffset).map { date in
            guard let date = date else { return nil }
            return MonthCell(
                daystamp: Daystamp(from: date, calendar: calendar),
                dayNumber: String(calendar.component(.day, from: date))
            )
        }

        monthCellsCache[monthOffset] = cells
        return cells
    }
    
    func getYPosition(for monthOffset: Int) -> CGFloat {
        if monthOffset == 0 {
            return 0
        }
        
        if let cached = cumulativePositionCache[monthOffset] {
            return cached
        }
        
        var position: CGFloat = 0
        
        if monthOffset > 0 {
            for offset in 1...monthOffset {
                if let cachedPos = cumulativePositionCache[offset] {
                    position = cachedPos
                } else {
                    position += getMonthHeight(for: offset - 1)
                    cumulativePositionCache[offset] = position
                }
            }
        } else {
            for offset in stride(from: -1, through: monthOffset, by: -1) {
                if let cachedPos = cumulativePositionCache[offset] {
                    position = cachedPos
                } else {
                    position -= getMonthHeight(for: offset)
                    cumulativePositionCache[offset] = position
                }
            }
        }

        return position
    }
    
    func getMonthDate(for monthOffset: Int) -> Date {
        return calendar.date(byAdding: .month, value: monthOffset, to: currentDate) ?? currentDate
    }
    
    func getMonthName(for monthOffset: Int) -> String {
        checkAndInvalidateCacheIfNeeded()

        if let cached = monthNameCache[monthOffset] {
            return cached
        }

        let monthDate = getMonthDate(for: monthOffset)
        let monthYear = calendar.component(.year, from: monthDate)

        dateFormatter.dateFormat = monthYear == currentYear ? "LLLL" : "LLLL yyyy"

        let name = dateFormatter.string(from: monthDate).capitalized
        monthNameCache[monthOffset] = name
        return name
    }
    
    func getLocalizedWeekdays() -> [String] {
        checkAndInvalidateCacheIfNeeded()
        
        let weekdays = dateFormatter.shortWeekdaySymbols!
        let firstWeekday = calendar.firstWeekday
        
        let startIndex = firstWeekday - 1
        let reorderedWeekdays = Array(weekdays[startIndex...]) + Array(weekdays[0..<startIndex])
        
        return reorderedWeekdays
    }
    
    func getScrollLimits() -> (min: CGFloat, max: CGFloat) {
        checkAndInvalidateCacheIfNeeded()

        if let cached = cachedScrollLimits {
            return cached
        }

        let firstMonthY = getYPosition(for: minMonthOffset)
        let lastMonthY = getYPosition(for: maxMonthOffset)
        let lastMonthHeight = getMonthHeight(for: maxMonthOffset)

        let maxScrollUp = -firstMonthY
        let availableHeight = screenHeight - 31
        let maxScrollDown = availableHeight - (lastMonthY + lastMonthHeight)

        let limits = (min: maxScrollDown, max: maxScrollUp)
        cachedScrollLimits = limits
        return limits
    }
}
