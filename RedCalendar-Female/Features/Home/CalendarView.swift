//
//  CalendarView.swift - Бесконечный календарь с простыми ограничениями 🎯⚡
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

// MARK: - Simple Infinite UIScrollView with Basic Limits
struct InfiniteScrollContainer: UIViewRepresentable {
    @Binding var scrollOffset: CGFloat
    let onScrollChanged: (CGFloat) -> Void
    let onDragStateChanged: (Bool) -> Void
    
    // Simple infinite scroll parameters
    private let contentHeight: CGFloat = 8000000
    private let centerY: CGFloat = 4000000
    
    // Simple boundary limits - approximate but fast
    private let maxScrollUp: CGFloat = 1800000    // ~6000 months * 300px average
    private let maxScrollDown: CGFloat = -1800000  // ~6000 months * 300px average
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.contentSize = CGSize(width: 0, height: contentHeight)
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = true
        scrollView.isMultipleTouchEnabled = true  // Native multi-touch
        scrollView.canCancelContentTouches = true
        scrollView.delaysContentTouches = false
        scrollView.backgroundColor = .clear
        scrollView.contentOffset.y = centerY
        scrollView.scrollsToTop = false  // Disable tap-to-scroll-to-top
        
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
            var calendarOffset = parent.centerY - physicalY
            
            // Simple boundary check - clamp to limits
            if calendarOffset > parent.maxScrollUp {
                calendarOffset = parent.maxScrollUp
                scrollView.contentOffset.y = parent.centerY - parent.maxScrollUp
            } else if calendarOffset < parent.maxScrollDown {
                calendarOffset = parent.maxScrollDown
                scrollView.contentOffset.y = parent.centerY - parent.maxScrollDown
            }
            
            // Simple recentering - only when needed and not dragging
            if !isDragging && Date().timeIntervalSince(lastRecenter) > 2.0 {
                let distanceFromEdge = min(physicalY, parent.contentHeight - physicalY)
                if distanceFromEdge < 1000000 {
                    scrollView.contentOffset.y = parent.centerY - calendarOffset
                    lastRecenter = Date()
                }
            }
            
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
                DispatchQueue.main.async { self.parent.onDragStateChanged(false) }
            }
        }
        
        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            isDragging = false
            DispatchQueue.main.async { self.parent.onDragStateChanged(false) }
        }
        
        // Simple deceleration control at boundaries
        func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            let targetPhysicalY = targetContentOffset.pointee.y
            let targetCalendarOffset = parent.centerY - targetPhysicalY
            
            // Simple boundary check
            if targetCalendarOffset > parent.maxScrollUp {
                targetContentOffset.pointee.y = parent.centerY - parent.maxScrollUp
            } else if targetCalendarOffset < parent.maxScrollDown {
                targetContentOffset.pointee.y = parent.centerY - parent.maxScrollDown
            }
        }
    }
}

// MARK: - Month Calculator with Proper Caching (RESTORED ORIGINAL)
final class MonthCalculator: ObservableObject {
    let currentDate: Date
    let screenHeight: CGFloat
    
    // Reasonable limits for calendar (about ±500 years)
    private let minMonthOffset: Int = -6000  // ~500 years back
    private let maxMonthOffset: Int = 6000   // ~500 years forward
    
    // Special boundary offsets for edge messages
    private let pastBoundaryOffset: Int = -6001
    private let futureBoundaryOffset: Int = 6001
    
    // Essential caches - keep the working logic
    private var weekCountCache: [Int: Int] = [:]
    private var monthHeightCache: [Int: CGFloat] = [:]
    private var monthDaysCache: [Int: [Date?]] = [:]
    private var cumulativePositionCache: [Int: CGFloat] = [0: 0]
    
    var weekHeight: CGFloat {
        return floor(max(50, (screenHeight - 31) / 15))
    }
    
    init(currentDate: Date, screenHeight: CGFloat) {
        self.currentDate = currentDate
        self.screenHeight = screenHeight
    }
    
    // Safe date calculation with fallbacks
    private func getMonthDate(for monthOffset: Int) -> Date {
        // Clamp to reasonable range
        let clampedOffset = max(minMonthOffset, min(maxMonthOffset, monthOffset))
        
        // Try to create the date
        if let date = Calendar.current.date(byAdding: .month, value: clampedOffset, to: currentDate) {
            return date
        }
        
        // Fallback for extreme dates
        return currentDate
    }
    
    func getWeeksCount(for monthOffset: Int) -> Int {
        if let cached = weekCountCache[monthOffset] { return cached }
        
        // Handle boundary messages
        if monthOffset == pastBoundaryOffset || monthOffset == futureBoundaryOffset {
            weekCountCache[monthOffset] = 8  // Extra tall for message
            return 8
        }
        
        let monthDate = getMonthDate(for: monthOffset)
        let calendar = Calendar.current
        
        guard let startOfMonth = calendar.dateInterval(of: .month, for: monthDate)?.start,
              let range = calendar.range(of: .day, in: .month, for: monthDate) else {
            // Fallback for problematic dates
            weekCountCache[monthOffset] = 6  // Standard month grid
            return 6
        }
        
        let daysInMonth = range.count
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let emptyCellsAtStart = (firstWeekday + 5) % 7
        let totalCells = emptyCellsAtStart + daysInMonth
        let weeksCount = Int(ceil(Double(totalCells) / 7.0))
        
        weekCountCache[monthOffset] = weeksCount
        cleanupCacheIfNeeded()
        
        return weeksCount
    }
    
    func getMonthHeight(for monthOffset: Int) -> CGFloat {
        if let cached = monthHeightCache[monthOffset] { return cached }
        
        let weeksCount = getWeeksCount(for: monthOffset)
        let headerHeight: CGFloat = 60
        let bottomSpacing: CGFloat = 20
        let gridVerticalSpacing: CGFloat = 4
        
        let gridHeight = (CGFloat(weeksCount) * weekHeight) + (CGFloat(weeksCount - 1) * gridVerticalSpacing)
        let height = floor(headerHeight + gridHeight + bottomSpacing)
        
        monthHeightCache[monthOffset] = height
        return height
    }
    
    func getMonthDays(for monthOffset: Int) -> [Date?] {
        if let cached = monthDaysCache[monthOffset] { return cached }
        
        // Handle boundary messages - return empty grid for special rendering
        if monthOffset == pastBoundaryOffset || monthOffset == futureBoundaryOffset {
            let emptyBoundary: [Date?] = Array(repeating: nil, count: 42)  // 6 weeks * 7 days
            monthDaysCache[monthOffset] = emptyBoundary
            return emptyBoundary
        }
        
        let monthDate = getMonthDate(for: monthOffset)
        let calendar = Calendar.current
        
        guard let startOfMonth = calendar.dateInterval(of: .month, for: monthDate)?.start,
              let range = calendar.range(of: .day, in: .month, for: monthDate) else {
            // Fallback - return empty month
            let emptyMonth: [Date?] = Array(repeating: nil, count: 42)  // 6 weeks * 7 days
            monthDaysCache[monthOffset] = emptyMonth
            return emptyMonth
        }
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let emptyCellsAtStart = (firstWeekday + 5) % 7
        
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
        if let cached = cumulativePositionCache[monthOffset] { return cached }
        
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
        // Special boundary messages
        if monthOffset == pastBoundaryOffset {
            return "🕰️ Граница времени"
        } else if monthOffset == futureBoundaryOffset {
            return "🚀 Край вселенной"
        }
        
        let monthDate = getMonthDate(for: monthOffset)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        
        // Handle extreme dates gracefully
        let name = formatter.string(from: monthDate).capitalized
        
        // Show indication for clamped dates
        if monthOffset <= minMonthOffset {
            return "Начало времен"
        } else if monthOffset >= maxMonthOffset {
            return "Конец времен"
        }
        
        return name
    }
    
    func getBoundaryMessage(for monthOffset: Int) -> String? {
        if monthOffset == pastBoundaryOffset {
            return "Дальше уже ничего нет! 🕰️\n\nСпасибо за любознательность,\nно календарь заканчивается здесь.\n\nВозвращайтесь к нашему времени! ✨"
        } else if monthOffset == futureBoundaryOffset {
            return "Это край времени! 🚀\n\nВы достигли границ календаря.\nСпасибо за исследовательский дух!\n\nВремя вернуться назад в реальность 😊"
        }
        return nil
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

// MARK: - Viewport Calculator - ORIGINAL WORKING LOGIC
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
        
        // Simple estimation based on average height
        let averageMonthHeight: CGFloat = 290
        let estimatedStartMonth = Int(scrollOffset / averageMonthHeight) - 5
        
        var visibleMonths: [VisibleMonth] = []
        var currentY: CGFloat = 0
        var monthOffset = estimatedStartMonth
        
        // Find the actual starting position
        currentY = calculator.getYPosition(for: monthOffset)
        
        // INFINITE backward search - with boundary message
        while currentY > viewportTop && monthOffset > -6001 {  // Include boundary
            monthOffset -= 1
            currentY = calculator.getYPosition(for: monthOffset)
        }
        
        // INFINITE forward search to build visible months - with boundary message
        while currentY < viewportBottom && monthOffset < 6001 {  // Include boundary
            let monthHeight = calculator.getMonthHeight(for: monthOffset)
            let monthBottom = currentY + monthHeight
            
            // Include month if it intersects with viewport
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
            
            // Safety: limit number of visible months to prevent memory issues
            if visibleMonths.count >= 30 {
                break
            }
        }
        
        return ViewportData(visibleMonths: visibleMonths)
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
        
        // Calculate day positions
        let headerHeight: CGFloat = 60
        let gridStartY = yPosition + headerHeight
        let dayWidth = (screenWidth - 24) / 7
        
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
    
    // Viewport optimization
    @State private var lastViewportUpdateScroll: CGFloat = 0
    private let viewportUpdateThreshold: CGFloat = 20
    
    private let currentDate = Date()
    
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let availableWidth = geometry.size.width
            
            ZStack {
                // Background
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
                    // Fixed header
                    headerView
                    
                    // Calendar content with native scroll overlay
                    ZStack {
                        // Calendar content layer
                        if let calc = calculator {
                            dynamicViewportRenderer(calculator: calc, screenWidth: availableWidth, screenHeight: availableHeight)
                        }
                        
                        // Native scroll layer (invisible but handles touch)
                        InfiniteScrollContainer(
                            scrollOffset: $scrollOffset,
                            onScrollChanged: { newOffset in
                                self.scrollOffset = newOffset
                                updateViewportTracking()
                            },
                            onDragStateChanged: { dragging in
                                self.isDragging = dragging
                            }
                        )
                    }
                }
            }
            .onAppear {
                setupCalculator(screenHeight: availableHeight, screenWidth: availableWidth)
            }
            .onChange(of: geometry.size) { newSize in
                if abs(newSize.height - screenHeight) > 1 || abs(newSize.width - screenWidth) > 1 {
                    setupCalculator(screenHeight: newSize.height, screenWidth: newSize.width)
                }
            }
        }
    }
    
    // MARK: - Calendar Content View - RESTORED WORKING LOGIC
    
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
                
                // Check if this is a boundary month
                if let boundaryMessage = calculator.getBoundaryMessage(for: month.monthOffset) {
                    // Render boundary message
                    boundaryMessageView(
                        message: boundaryMessage,
                        title: calculator.getMonthName(for: month.monthOffset),
                        yPosition: month.yPosition,
                        height: month.height,
                        screenWidth: screenWidth
                    )
                } else {
                    // Month header
                    Text(calculator.getMonthName(for: month.monthOffset))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(width: screenWidth, height: 60)
                        .position(x: screenWidth / 2, y: month.yPosition + 30)
                    
                    // Days - each as separate positioned element
                    ForEach(month.visibleDays.indices, id: \.self) { dayIndex in
                        let day = month.visibleDays[dayIndex]
                        
                        let dayScreenY = day.yPosition + scrollOffset
                        if dayScreenY > -100 && dayScreenY < screenHeight + 100 {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: scrollOffset)
        .clipped()
        .allowsHitTesting(false)
    }
    
    // MARK: - Boundary Message View
    
    private func boundaryMessageView(
        message: String,
        title: String,
        yPosition: CGFloat,
        height: CGFloat,
        screenWidth: CGFloat
    ) -> some View {
        VStack(spacing: 20) {
            // Title
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            // Decorative line
            Rectangle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color.red.opacity(0.3), Color.red, Color.red.opacity(0.3)]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 2)
                .frame(width: screenWidth * 0.6)
            
            // Message
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)
            
            // Decorative element
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 8, height: 8)
                Circle()
                    .fill(Color.red.opacity(0.6))
                    .frame(width: 12, height: 12)
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: screenWidth, height: height)
        .position(x: screenWidth / 2, y: yPosition + height / 2)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
    
    private func updateViewportTracking() {
        let shouldUpdate = abs(scrollOffset - lastViewportUpdateScroll) > viewportUpdateThreshold
        if shouldUpdate {
            lastViewportUpdateScroll = scrollOffset
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                }
            }
            .padding(.horizontal, 8)
            .background(Color(.systemBackground))
            
            Divider()
        }
    }
    
    private func setupCalculator(screenHeight: CGFloat, screenWidth: CGFloat) {
        self.screenHeight = screenHeight
        self.screenWidth = screenWidth
        
        calculator = MonthCalculator(currentDate: currentDate, screenHeight: screenHeight)
        
        if abs(scrollOffset) < 0.1 {
            scrollOffset = 0
        }
    }
}

// MARK: - Preview
#Preview {
    CalendarView()
}
