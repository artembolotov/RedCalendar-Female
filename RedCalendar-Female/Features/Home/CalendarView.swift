//
//  CalendarView.swift - Локализованный календарь
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.07.2025.
//

import SwiftUI

// MARK: - Data Structures
struct ViewportData {
    let visibleMonths: [VisibleMonth]
}

struct VisibleMonth {
    let monthOffset: Int
    let yPosition: CGFloat
    let height: CGFloat
    let visibleDays: [VisibleDay]
}

struct VisibleDay {
    let date: Date?
    let isToday: Bool
    let xPosition: CGFloat
    let yPosition: CGFloat
    let dayNumber: String
}

// MARK: - Simple Infinite UIScrollView
struct InfiniteScrollContainer: UIViewRepresentable {
    @Binding var scrollOffset: CGFloat
    let onScrollChanged: (CGFloat) -> Void
    let onDragStateChanged: (Bool) -> Void
    let initialCenterOffset: CGFloat
    let calculator: MonthCalculator
    
    private let contentHeight: CGFloat = 8000000
    private let centerY: CGFloat = 4000000
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.contentSize = CGSize(width: 0, height: contentHeight)
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = true
        scrollView.isMultipleTouchEnabled = true
        scrollView.canCancelContentTouches = true
        scrollView.delaysContentTouches = false
        scrollView.backgroundColor = .clear
        scrollView.scrollsToTop = false
        
        // Start with current week centered
        scrollView.contentOffset.y = centerY - initialCenterOffset
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if !context.coordinator.isDragging {
            let targetY = centerY - scrollOffset
            if abs(uiView.contentOffset.y - targetY) > 100 {
                uiView.contentOffset.y = targetY
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: InfiniteScrollContainer
        var isDragging = false
        var lastRecenter = Date()
        
        init(_ parent: InfiniteScrollContainer) {
            self.parent = parent
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let physicalY = scrollView.contentOffset.y
            var calendarOffset = self.parent.centerY - physicalY
            
            // Apply real calendar limits
            let limits = self.parent.calculator.getScrollLimits()
            let originalOffset = calendarOffset
            calendarOffset = max(limits.min, min(limits.max, calendarOffset))
            
            // ALWAYS correct physical position when hitting boundaries
            if originalOffset != calendarOffset {
                let correctedPhysicalY = self.parent.centerY - calendarOffset
                scrollView.contentOffset.y = correctedPhysicalY
                
                // Update state synchronously at boundaries
                self.parent.scrollOffset = calendarOffset
                self.parent.onScrollChanged(calendarOffset)
                return
            }
            
            // Minimal recentering when very far from center
            if !isDragging && Date().timeIntervalSince(lastRecenter) > 5.0 {
                let correctedPhysicalY = self.parent.centerY - calendarOffset
                let distanceFromEdge = min(correctedPhysicalY, self.parent.contentHeight - correctedPhysicalY)
                if distanceFromEdge < 100000 {
                    scrollView.contentOffset.y = self.parent.centerY - calendarOffset
                    lastRecenter = Date()
                }
            }
            
            // Normal async update
            DispatchQueue.main.async {
                self.parent.scrollOffset = calendarOffset
                self.parent.onScrollChanged(calendarOffset)
            }
        }
        
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isDragging = true
            DispatchQueue.main.async { self.parent.onDragStateChanged(true) }
        }
        
        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
            if !willDecelerate {
                isDragging = false
                
                // Additional boundary check after drag without deceleration
                let physicalY = scrollView.contentOffset.y
                var calendarOffset = self.parent.centerY - physicalY
                let limits = self.parent.calculator.getScrollLimits()
                let correctedOffset = max(limits.min, min(limits.max, calendarOffset))
                
                if abs(correctedOffset - calendarOffset) > 0.1 {
                    let correctedPhysicalY = self.parent.centerY - correctedOffset
                    scrollView.contentOffset.y = correctedPhysicalY
                    calendarOffset = correctedOffset
                }
                
                // Update state synchronously
                self.parent.scrollOffset = calendarOffset
                self.parent.onScrollChanged(calendarOffset)
                
                DispatchQueue.main.async {
                    self.parent.onDragStateChanged(false)
                }
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isDragging = false
            
            // Additional boundary check after deceleration
            let physicalY = scrollView.contentOffset.y
            var calendarOffset = self.parent.centerY - physicalY
            let limits = self.parent.calculator.getScrollLimits()
            let correctedOffset = max(limits.min, min(limits.max, calendarOffset))
            
            if abs(correctedOffset - calendarOffset) > 0.1 {
                let correctedPhysicalY = self.parent.centerY - correctedOffset
                scrollView.contentOffset.y = correctedPhysicalY
                calendarOffset = correctedOffset
            }
            
            // Update state synchronously
            self.parent.scrollOffset = calendarOffset
            self.parent.onScrollChanged(calendarOffset)
            
            DispatchQueue.main.async {
                self.parent.onDragStateChanged(false)
            }
        }
        
        // Smooth deceleration at boundaries
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            let targetPhysicalY = targetContentOffset.pointee.y
            let targetCalendarOffset = parent.centerY - targetPhysicalY
            
            let limits = parent.calculator.getScrollLimits()
            
            // Check if we're approaching or exceeding boundaries
            let boundaryBuffer: CGFloat = 200
            let isApproachingTop = targetCalendarOffset > (limits.max - boundaryBuffer)
            let isApproachingBottom = targetCalendarOffset < (limits.min + boundaryBuffer)
            
            if isApproachingTop || isApproachingBottom {
                // Calculate smooth deceleration
                let clampedTarget = max(limits.min, min(limits.max, targetCalendarOffset))
                let correctedPhysicalY = parent.centerY - clampedTarget
                
                if isApproachingTop && targetCalendarOffset > limits.max {
                    // Smooth deceleration to top boundary
                    let overshoot = targetCalendarOffset - limits.max
                    let dampenedOvershoot = overshoot * 0.3
                    let smoothTarget = limits.max + dampenedOvershoot
                    targetContentOffset.pointee.y = parent.centerY - smoothTarget
                } else if isApproachingBottom && targetCalendarOffset < limits.min {
                    // Smooth deceleration to bottom boundary
                    let overshoot = limits.min - targetCalendarOffset
                    let dampenedOvershoot = overshoot * 0.3
                    let smoothTarget = limits.min - dampenedOvershoot
                    targetContentOffset.pointee.y = parent.centerY - smoothTarget
                } else {
                    // Direct clamp if within boundary buffer
                    targetContentOffset.pointee.y = correctedPhysicalY
                }
                
                // Reduce deceleration rate for smoother feel near boundaries
                scrollView.decelerationRate = UIScrollView.DecelerationRate.fast
            } else {
                // Normal deceleration rate away from boundaries
                scrollView.decelerationRate = UIScrollView.DecelerationRate.normal
            }
        }
    }
}

// MARK: - Month Calculator
final class MonthCalculator: ObservableObject {
    let currentDate: Date
    let currentYear: Int
    let screenHeight: CGFloat
    
    // Constants - extensive limits for maximum flexibility
    let minMonthOffset: Int = -2400  // 200 years back
    let maxMonthOffset: Int = 2400   // 200 years forward
    private let monthHeaderHeight: CGFloat = 60
    private let bottomSpacing: CGFloat = 20
    private let gridVerticalSpacing: CGFloat = 4
    
    // Caches
    private var weekCountCache: [Int: Int] = [:]
    private var monthHeightCache: [Int: CGFloat] = [:]
    private var monthDaysCache: [Int: [Date?]] = [:]
    private var cumulativePositionCache: [Int: CGFloat] = [0: 0]
    
    // Track current locale to invalidate cache when it changes
    private var cachedLocaleIdentifier: String
    private var cachedFirstWeekday: Int
    
    var weekHeight: CGFloat {
        return floor(max(50, (screenHeight - 31) / 15))
    }
    
    init(currentDate: Date, screenHeight: CGFloat) {
        self.currentDate = currentDate
        self.currentYear = Calendar.current.component(.year, from: currentDate)
        self.screenHeight = screenHeight
        self.cachedLocaleIdentifier = Locale.current.identifier
        self.cachedFirstWeekday = Calendar.current.firstWeekday
    }
    
    // Clear cache if locale or first weekday changed
    private func checkAndInvalidateCacheIfNeeded() {
        let currentLocale = Locale.current.identifier
        let currentFirstWeekday = Calendar.current.firstWeekday
        
        if currentLocale != cachedLocaleIdentifier || currentFirstWeekday != cachedFirstWeekday {
            weekCountCache.removeAll()
            monthHeightCache.removeAll()
            monthDaysCache.removeAll()
            cumulativePositionCache = [0: 0]
            
            cachedLocaleIdentifier = currentLocale
            cachedFirstWeekday = currentFirstWeekday
        }
    }
    
    private func getMonthDate(for monthOffset: Int) -> Date {
        let clampedOffset = max(minMonthOffset, min(maxMonthOffset, monthOffset))
        
        if let date = Calendar.current.date(byAdding: .month, value: clampedOffset, to: currentDate) {
            return date
        }
        
        return currentDate
    }
    
    func getWeeksCount(for monthOffset: Int) -> Int {
        checkAndInvalidateCacheIfNeeded()
        
        if let cached = weekCountCache[monthOffset] { return cached }
        
        let monthDate = getMonthDate(for: monthOffset)
        let calendar = Calendar.current
        
        guard let startOfMonth = calendar.dateInterval(of: .month, for: monthDate)?.start,
              let range = calendar.range(of: .day, in: .month, for: monthDate) else {
            weekCountCache[monthOffset] = 6
            return 6
        }
        
        let daysInMonth = range.count
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let calendarFirstWeekday = calendar.firstWeekday
        
        // Calculate empty cells at start based on user's regional first weekday setting
        let emptyCellsAtStart = (firstWeekday - calendarFirstWeekday + 7) % 7
        let totalCells = emptyCellsAtStart + daysInMonth
        let weeksCount = Int(ceil(Double(totalCells) / 7.0))
        
        weekCountCache[monthOffset] = weeksCount
        cleanupCacheIfNeeded()
        
        return weeksCount
    }
    
    func getMonthHeight(for monthOffset: Int) -> CGFloat {
        if let cached = monthHeightCache[monthOffset] { return cached }
        
        let weeksCount = getWeeksCount(for: monthOffset)
        let gridHeight = (CGFloat(weeksCount) * weekHeight) + (CGFloat(weeksCount - 1) * gridVerticalSpacing)
        let height = floor(monthHeaderHeight + gridHeight + bottomSpacing)
        
        monthHeightCache[monthOffset] = height
        return height
    }
    
    func getMonthDays(for monthOffset: Int) -> [Date?] {
        checkAndInvalidateCacheIfNeeded()
        
        if let cached = monthDaysCache[monthOffset] { return cached }
        
        let monthDate = getMonthDate(for: monthOffset)
        let calendar = Calendar.current
        
        guard let startOfMonth = calendar.dateInterval(of: .month, for: monthDate)?.start,
              let range = calendar.range(of: .day, in: .month, for: monthDate) else {
            let emptyMonth: [Date?] = Array(repeating: nil, count: 42)
            monthDaysCache[monthOffset] = emptyMonth
            return emptyMonth
        }
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let calendarFirstWeekday = calendar.firstWeekday
        
        // Calculate empty cells at start based on user's regional first weekday setting
        let emptyCellsAtStart = (firstWeekday - calendarFirstWeekday + 7) % 7
        
        var days: [Date?] = Array(repeating: nil, count: emptyCellsAtStart)
        
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        let totalCells = emptyCellsAtStart + range.count
        let weeksNeeded = Int(ceil(Double(totalCells) / 7.0))
        let cellsNeeded = weeksNeeded * 7
        
        while days.count < cellsNeeded {
            days.append(nil)
        }
        
        monthDaysCache[monthOffset] = days
        return days
    }
    
    func getYPosition(for monthOffset: Int) -> CGFloat {
        if let cached = cumulativePositionCache[monthOffset] {
            return cached
        }
        
        var nearestCachedOffset: Int
        var nearestCachedPosition: CGFloat
        
        if monthOffset > 0 {
            nearestCachedOffset = 0
            nearestCachedPosition = 0
            
            for offset in stride(from: monthOffset - 1, through: 0, by: -1) {
                if let cachedPos = cumulativePositionCache[offset] {
                    nearestCachedOffset = offset
                    nearestCachedPosition = cachedPos
                    break
                }
            }
            
            var currentPosition = nearestCachedPosition
            for offset in (nearestCachedOffset + 1)...monthOffset {
                let monthHeight = getMonthHeight(for: offset - 1)
                currentPosition += monthHeight
                cumulativePositionCache[offset] = currentPosition
            }
            
        } else if monthOffset < 0 {
            nearestCachedOffset = 0
            nearestCachedPosition = 0
            
            for offset in stride(from: monthOffset + 1, to: 1, by: 1) {
                if let cachedPos = cumulativePositionCache[offset] {
                    nearestCachedOffset = offset
                    nearestCachedPosition = cachedPos
                    break
                }
            }
            
            var currentPosition = nearestCachedPosition
            for offset in stride(from: nearestCachedOffset - 1, through: monthOffset, by: -1) {
                let monthHeight = getMonthHeight(for: offset)
                currentPosition -= monthHeight
                cumulativePositionCache[offset] = currentPosition
            }
        }
        
        return cumulativePositionCache[monthOffset] ?? 0
    }
    
    func getMonthName(for monthOffset: Int) -> String {
        let monthDate = getMonthDate(for: monthOffset)
        let formatter = DateFormatter()
        formatter.locale = Locale.current // Use system locale
        
        let monthYear = Calendar.current.component(.year, from: monthDate)
        
        // Show only month name for current year, month + year for other years
        if monthYear == currentYear {
            formatter.dateFormat = "LLLL"
        } else {
            formatter.dateFormat = "LLLL yyyy"
        }
        
        return formatter.string(from: monthDate).capitalized
    }
    
    // Get localized weekday names for header respecting regional first weekday
    func getLocalizedWeekdays() -> [String] {
        checkAndInvalidateCacheIfNeeded()
        
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        let weekdays = formatter.shortWeekdaySymbols!
        let firstWeekday = Calendar.current.firstWeekday
        
        // Reorder weekdays based on user's regional settings
        let startIndex = firstWeekday - 1
        let reorderedWeekdays = Array(weekdays[startIndex...]) + Array(weekdays[0..<startIndex])
        
        return reorderedWeekdays
    }
    
    // Get actual scroll limits based on first and last months
    func getScrollLimits() -> (min: CGFloat, max: CGFloat) {
        let firstMonthY = getYPosition(for: minMonthOffset)
        let lastMonthY = getYPosition(for: maxMonthOffset)
        let lastMonthHeight = getMonthHeight(for: maxMonthOffset)
        
        // Can't scroll beyond first month (going up)
        let maxScrollUp = -firstMonthY
        
        // Last month bottom aligns with screen bottom
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

// MARK: - Viewport Calculator
class ViewportCalculator {
    static func calculateDynamicViewport(
        scrollOffset: CGFloat,
        screenHeight: CGFloat,
        screenWidth: CGFloat,
        calculator: MonthCalculator
    ) -> ViewportData {
        
        let bufferHeight = screenHeight * 1.5
        let viewportTop = -scrollOffset - bufferHeight
        let viewportBottom = -scrollOffset + screenHeight + bufferHeight
        
        // Smart starting month search
        let averageMonthHeight: CGFloat = 290
        let estimatedMonthOffset = Int(scrollOffset / averageMonthHeight)
        
        // Binary search for optimal starting point
        var monthOffset = findOptimalStartMonth(
            estimatedOffset: estimatedMonthOffset,
            viewportTop: viewportTop,
            calculator: calculator
        )
        
        var visibleMonths: [VisibleMonth] = []
        var currentY = calculator.getYPosition(for: monthOffset)
        
        // Backward search to find first visible month
        while currentY > viewportTop && monthOffset > calculator.minMonthOffset {
            monthOffset -= 1
            currentY = calculator.getYPosition(for: monthOffset)
        }
        
        // Forward search to build visible months
        while currentY < viewportBottom && monthOffset <= calculator.maxMonthOffset {
            let monthHeight = calculator.getMonthHeight(for: monthOffset)
            let monthBottom = currentY + monthHeight
            
            if monthBottom > viewportTop && currentY < viewportBottom {
                let visibleMonth = createVisibleMonth(
                    monthOffset: monthOffset,
                    yPosition: currentY,
                    height: monthHeight,
                    screenWidth: screenWidth,
                    calculator: calculator
                )
                visibleMonths.append(visibleMonth)
            }
            
            currentY += monthHeight
            monthOffset += 1
            
            if visibleMonths.count >= 12 { // Reduced for better performance
                break
            }
        }
        
        return ViewportData(visibleMonths: visibleMonths)
    }
    
    // Binary search for optimal starting month
    private static func findOptimalStartMonth(
        estimatedOffset: Int,
        viewportTop: CGFloat,
        calculator: MonthCalculator
    ) -> Int {
        let clampedEstimate = max(calculator.minMonthOffset, min(calculator.maxMonthOffset, estimatedOffset))
        
        // Check if estimate is good enough
        let estimatedY = calculator.getYPosition(for: clampedEstimate)
        let estimatedHeight = calculator.getMonthHeight(for: clampedEstimate)
        
        if estimatedY <= viewportTop && (estimatedY + estimatedHeight) >= viewportTop {
            return clampedEstimate
        }
        
        // Binary search if estimate is off
        var low = calculator.minMonthOffset
        var high = calculator.maxMonthOffset
        
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
        calculator: MonthCalculator
    ) -> VisibleMonth {
        
        let monthDays = calculator.getMonthDays(for: monthOffset)
        let weeksCount = calculator.getWeeksCount(for: monthOffset)
        let weekHeight = calculator.weekHeight
        
        var visibleDays: [VisibleDay] = []
        
        let headerHeight: CGFloat = 60
        let gridStartY = yPosition + headerHeight
        let dayWidth = (screenWidth - 24) / 7
        
        // Batch process all days for better performance
        for weekIndex in 0..<weeksCount {
            let weekY = gridStartY + CGFloat(weekIndex) * (weekHeight + 4)
            
            for dayIndex in 0..<7 {
                let cellIndex = weekIndex * 7 + dayIndex
                if cellIndex < monthDays.count, let date = monthDays[cellIndex] {
                    let dayX = 12 + CGFloat(dayIndex) * dayWidth
                    let dayNumber = String(Calendar.current.component(.day, from: date))
                    let isToday = Calendar.current.isDate(date, inSameDayAs: Calendar.current.startOfDay(for: calculator.currentDate))
                    
                    let visibleDay = VisibleDay(
                        date: date,
                        isToday: isToday,
                        xPosition: dayX,
                        yPosition: weekY,
                        dayNumber: dayNumber
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

// MARK: - Main Calendar View
struct CalendarView: View {
    @State private var calculator: MonthCalculator?
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var screenHeight: CGFloat = 0
    @State private var screenWidth: CGFloat = 0
    @State private var lastViewportUpdateScroll: CGFloat = 0
    @State private var initialCenterOffset: CGFloat = 0
    @State private var localizedWeekdays: [String] = []
    
    // Constants
    private let viewportUpdateThreshold: CGFloat = 12
    private let headerHeight: CGFloat = 31
    private let monthHeaderHeight: CGFloat = 60
    private let dayVisibilityBuffer: CGFloat = 60
    private let currentDate = Date()
    
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let availableWidth = geometry.size.width
            
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color.red.opacity(0.02)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    headerView
                    
                    ZStack {
                        if let calc = calculator {
                            dynamicViewportRenderer(
                                calculator: calc,
                                screenWidth: availableWidth,
                                screenHeight: availableHeight
                            )
                            
                            InfiniteScrollContainer(
                                scrollOffset: $scrollOffset,
                                onScrollChanged: { newOffset in
                                    self.scrollOffset = newOffset
                                    updateViewportTracking()
                                },
                                onDragStateChanged: { dragging in
                                    self.isDragging = dragging
                                },
                                initialCenterOffset: initialCenterOffset,
                                calculator: calc
                            )
                        }
                    }
                }
            }
            .onAppear {
                setupCalculator(screenHeight: availableHeight, screenWidth: availableWidth)
            }
            .onChange(of: geometry.size) { newSize in
                if newSize.height > 0 && newSize.width > 0 {
                    setupCalculator(screenHeight: newSize.height, screenWidth: newSize.width)
                }
            }
            // Force refresh when returning from background (to catch locale changes)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Force refresh calculator to pick up any locale changes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    setupCalculator(screenHeight: screenHeight, screenWidth: screenWidth)
                }
            }
            // Update calendar when day changes or time settings change
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                // Refresh calculator to update today's date and recalculate positioning
                DispatchQueue.main.async {
                    setupCalculator(screenHeight: screenHeight, screenWidth: screenWidth)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupCalculator(screenHeight: CGFloat, screenWidth: CGFloat) {
        self.screenHeight = screenHeight
        self.screenWidth = screenWidth
        
        guard screenHeight > 0 && screenWidth > 0 else { return }
        
        let newCalculator = MonthCalculator(currentDate: currentDate, screenHeight: screenHeight)
        
        // Update localized weekdays
        localizedWeekdays = newCalculator.getLocalizedWeekdays()
        
        // Find today's week position for centering
        let currentMonthY = newCalculator.getYPosition(for: 0)
        let monthDays = newCalculator.getMonthDays(for: 0)
        let weekHeight = newCalculator.weekHeight
        
        var todayWeekIndex = 0
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentDate)
        
        for (index, date) in monthDays.enumerated() {
            if let date = date, calendar.isDate(date, inSameDayAs: today) {
                todayWeekIndex = index / 7
                break
            }
        }
        
        let gridStartY = currentMonthY + monthHeaderHeight
        let todayWeekY = gridStartY + CGFloat(todayWeekIndex) * (weekHeight + 4)
        let todayWeekCenterY = todayWeekY + weekHeight / 2
        
        // Center current week in available view (excluding header)
        let availableCalendarHeight = screenHeight - headerHeight
        let centerPosition = availableCalendarHeight / 2
        
        initialCenterOffset = centerPosition - todayWeekCenterY
        
        calculator = newCalculator
        scrollOffset = initialCenterOffset
    }
    
    private func dynamicViewportRenderer(calculator: MonthCalculator, screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        let shouldUpdateViewport = abs(scrollOffset - lastViewportUpdateScroll) > viewportUpdateThreshold || isDragging
        let scrollForCalculation = shouldUpdateViewport ? scrollOffset : lastViewportUpdateScroll
        
        let dynamicViewport = ViewportCalculator.calculateDynamicViewport(
            scrollOffset: scrollForCalculation,
            screenHeight: screenHeight,
            screenWidth: screenWidth,
            calculator: calculator
        )
        
        return ZStack(alignment: .topLeading) {
            ForEach(dynamicViewport.visibleMonths.indices, id: \.self) { monthIndex in
                let month = dynamicViewport.visibleMonths[monthIndex]
                
                // Month header
                Text(calculator.getMonthName(for: month.monthOffset))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(width: screenWidth, height: 60)
                    .position(x: screenWidth / 2, y: month.yPosition + 30)
                
                // Optimized day rendering
                ForEach(month.visibleDays.indices, id: \.self) { dayIndex in
                    let day = month.visibleDays[dayIndex]
                    
                    let dayScreenY = day.yPosition + scrollOffset
                    if dayScreenY > -dayVisibilityBuffer && dayScreenY < screenHeight + dayVisibilityBuffer {
                        ZStack {
                            if day.isToday {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)
                            }
                            
                            Text(day.dayNumber)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(day.isToday ? .white : .primary)
                        }
                        .position(
                            x: day.xPosition + (screenWidth - 24) / 14,
                            y: day.yPosition + calculator.weekHeight / 2
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: scrollOffset)
        .clipped()
        .allowsHitTesting(false)
    }
    
    private func updateViewportTracking() {
        // Enhanced adaptive threshold based on device capabilities and drag state
        let baseThreshold = viewportUpdateThreshold
        let adaptiveThreshold = isDragging ? baseThreshold * 0.5 : baseThreshold
        
        let shouldUpdate = abs(scrollOffset - lastViewportUpdateScroll) > adaptiveThreshold
        
        if shouldUpdate {
            lastViewportUpdateScroll = scrollOffset
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Use exact same positioning logic as calendar days
                ForEach(Array(localizedWeekdays.enumerated()), id: \.offset) { dayIndex, weekday in
                    let dayWidth = (screenWidth - 24) / 7
                    let dayX = 12 + CGFloat(dayIndex) * dayWidth
                    let centerX = dayX + dayWidth / 2
                    
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .position(x: centerX, y: 15)
                }
            }
            .frame(width: screenWidth, height: 30)
            .background(Color(.systemBackground))
            
            Divider()
                .frame(height: 1)
        }
    }
}

#Preview {
    CalendarView()
}
