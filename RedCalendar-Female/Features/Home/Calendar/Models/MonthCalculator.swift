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
        
    private var weekCountCache: [Int: Int] = [:]
    private var monthHeightCache: [Int: CGFloat] = [:]
    private var monthDaysCache: [Int: [Date?]] = [:]
    private var cumulativePositionCache: [Int: CGFloat] = [0: 0]
    
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
            monthDaysCache.removeAll()
            cumulativePositionCache = [0: 0]
            
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
    
    func getMonthDays(for monthOffset: Int) -> [Date?] {
        checkAndInvalidateCacheIfNeeded()
        
        if let cached = monthDaysCache[monthOffset] {
            return cached
        }
        
        let monthDate = getMonthDate(for: monthOffset)
        
        guard let monthRange = calendar.range(of: .day, in: .month, for: monthDate),
              let firstOfMonth = calendar.dateInterval(of: .month, for: monthDate)?.start else {
            monthDaysCache[monthOffset] = []
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
        
        monthDaysCache[monthOffset] = days
        return days
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
        
        cleanupCacheIfNeeded()
        return position
    }
    
    func getMonthDate(for monthOffset: Int) -> Date {
        return calendar.date(byAdding: .month, value: monthOffset, to: currentDate) ?? currentDate
    }
    
    func getMonthName(for monthOffset: Int) -> String {
        let monthDate = getMonthDate(for: monthOffset)
        let monthYear = calendar.component(.year, from: monthDate)
        
        dateFormatter.dateFormat = monthYear == currentYear ? "LLLL" : "LLLL yyyy"
        
        return dateFormatter.string(from: monthDate).capitalized
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
        let firstMonthY = getYPosition(for: minMonthOffset)
        let lastMonthY = getYPosition(for: maxMonthOffset)
        let lastMonthHeight = getMonthHeight(for: maxMonthOffset)
        
        let maxScrollUp = -firstMonthY
        let availableHeight = screenHeight - 31
        let maxScrollDown = availableHeight - (lastMonthY + lastMonthHeight)
        
        return (min: maxScrollDown, max: maxScrollUp)
    }
    
    private func cleanupCacheIfNeeded() {
        if weekCountCache.count > 200 {
            let sortedKeys = weekCountCache.keys.sorted { abs($0) > abs($1) }
            let keysToRemove = Array(sortedKeys.prefix(50))
            
            for key in keysToRemove {
                weekCountCache.removeValue(forKey: key)
                monthHeightCache.removeValue(forKey: key)
                monthDaysCache.removeValue(forKey: key)
            }
        }
    }
}
