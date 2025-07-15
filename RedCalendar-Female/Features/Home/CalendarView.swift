//
//  CalendarView.swift - Низкоуровневая отрисовка окна просмотра 🎯⚡
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.07.2025.
//
//  🎯 VIEWPORT RENDERING APPROACH:
//  🖼️ Бесконечный viewport в обе стороны
//  🎨 НЕ пересчитываем элементы во время прокрутки
//  📐 Кэширование кумулятивных позиций (без ограничений)
//  🚫 Мгновенное прерывание анимаций
//  ✅ Полный контроль над рендерингом
//  ⚡ НАТИВНЫЙ momentum с физикой UIScrollView
//

import SwiftUI
import Combine

// MARK: - ViewportData - что видно в окне
struct ViewportData {
    let visibleMonths: [VisibleMonth]
    let totalContentHeight: CGFloat
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

// MARK: - Smooth and Responsive Calendar Physics
struct MomentumPhysics {
    // Friction coefficient - smooth and flowing like native iOS
    static let friction: CGFloat = 0.991  // Light friction for smooth momentum
    
    // Minimum velocity threshold - natural stop without abrupt ending
    static let minVelocity: CGFloat = 0.4  // Let momentum flow naturally
    
    // Maximum initial velocity - allow energetic navigation
    static let maxVelocity: CGFloat = 12000  // Support fast navigation
    
    // Velocity multiplier - responsive and lively
    static let velocityMultiplier: CGFloat = 1.1  // Amplify gestures for responsiveness
    
    // Target FPS for smooth animation
    static let targetFPS: Double = 120.0
    static let frameInterval: TimeInterval = 1.0 / targetFPS
}

// MARK: - Optimized MonthCalculator with Cumulative Position Caching
final class MonthCalculator: ObservableObject {
    let currentDate: Date
    let screenHeight: CGFloat
    
    private var weekCountCache: [Int: Int] = [:]
    private var monthHeightCache: [Int: CGFloat] = [:]
    private var monthDaysCache: [Int: [Date?]] = [:]
    
    // NEW: Cumulative position cache for smooth scrolling
    private var cumulativePositionCache: [Int: CGFloat] = [:]
    private var lastAccessedMonth: Int = 0  // Track movement direction for cache cleanup
    private var lastCacheCleanupTime: Date = Date()  // Prevent excessive cleanup
    
    private let maxCacheSize = 500  // Larger cache for infinite scrolling
    private let cacheCleanupDistance = 1000  // Very large distance before cleanup
    private let cacheCleanupCooldown: TimeInterval = 5.0  // Wait 5 seconds between cleanups
    
    init(currentDate: Date, screenHeight: CGFloat) {
        self.currentDate = currentDate
        self.screenHeight = screenHeight
        // Initialize position 0 for current month
        cumulativePositionCache[0] = 0
        lastCacheCleanupTime = Date()  // Initialize cleanup time
    }
    
    var weekHeight: CGFloat {
        return floor(max(50, (screenHeight - 31) / 15))
    }
    
    func getWeeksCount(for monthOffset: Int) -> Int {
        if let cached = weekCountCache[monthOffset] {
            return cached
        }
        
        let monthDate = Calendar.current.date(byAdding: .month, value: monthOffset, to: currentDate) ?? currentDate
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: monthDate)?.start ?? monthDate
        let range = calendar.range(of: .day, in: .month, for: monthDate) ?? 1..<32
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
        if let cached = monthHeightCache[monthOffset] {
            return cached
        }
        
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
        if let cached = monthDaysCache[monthOffset] {
            return cached
        }
        
        let monthDate = Calendar.current.date(byAdding: .month, value: monthOffset, to: currentDate) ?? currentDate
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: monthDate)?.start ?? monthDate
        let range = calendar.range(of: .day, in: .month, for: monthDate) ?? 1..<32
        
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
    
    func getMonthName(for monthOffset: Int) -> String {
        let monthDate = Calendar.current.date(byAdding: .month, value: monthOffset, to: currentDate) ?? currentDate
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: monthDate).capitalized
    }
    
    // OPTIMIZED: Cumulative position caching for smooth scrolling
    func getYPosition(for monthOffset: Int) -> CGFloat {
        // Check if already cached
        if let cached = cumulativePositionCache[monthOffset] {
            updateLastAccessed(monthOffset)
            return cached
        }
        
        // Find the nearest cached position to build from
        var nearestCachedOffset: Int
        var nearestCachedPosition: CGFloat
        
        if monthOffset > 0 {
            // For positive offsets, find highest cached offset below target
            nearestCachedOffset = 0
            nearestCachedPosition = 0
            
            for offset in stride(from: monthOffset - 1, through: 0, by: -1) {
                if let cachedPos = cumulativePositionCache[offset] {
                    nearestCachedOffset = offset
                    nearestCachedPosition = cachedPos
                    break
                }
            }
            
            // Build forward from nearest cached position
            var currentPosition = nearestCachedPosition
            for offset in (nearestCachedOffset + 1)...monthOffset {
                let monthHeight = getMonthHeight(for: offset - 1)
                currentPosition += monthHeight
                
                // Cache intermediate positions
                cumulativePositionCache[offset] = currentPosition
            }
            
        } else if monthOffset < 0 {
            // For negative offsets, find lowest cached offset above target
            nearestCachedOffset = 0
            nearestCachedPosition = 0
            
            for offset in stride(from: monthOffset + 1, to: 1, by: 1) {
                if let cachedPos = cumulativePositionCache[offset] {
                    nearestCachedOffset = offset
                    nearestCachedPosition = cachedPos
                    break
                }
            }
            
            // Build backward from nearest cached position
            var currentPosition = nearestCachedPosition
            for offset in stride(from: nearestCachedOffset - 1, through: monthOffset, by: -1) {
                let monthHeight = getMonthHeight(for: offset)
                currentPosition -= monthHeight
                
                // Cache intermediate positions
                cumulativePositionCache[offset] = currentPosition
            }
        }
        
        updateLastAccessed(monthOffset)
        return cumulativePositionCache[monthOffset] ?? 0
    }
    
    private func updateLastAccessed(_ monthOffset: Int) {
        let previousAccess = lastAccessedMonth
        lastAccessedMonth = monthOffset
        
        // Clean up distant cache if we've moved far away AND enough time has passed
        let distanceMoved = abs(monthOffset - previousAccess)
        let timeSinceLastCleanup = Date().timeIntervalSince(lastCacheCleanupTime)
        
        if distanceMoved > cacheCleanupDistance && timeSinceLastCleanup > cacheCleanupCooldown {
            cleanupDistantCache(around: monthOffset)
            lastCacheCleanupTime = Date()
        }
    }
    
    private func cleanupDistantCache(around centerMonth: Int) {
        // For truly infinite calendar, keep a larger range and clean less aggressively
        let keepRange = centerMonth - 500...centerMonth + 500  // Keep ±500 months (~41 years each direction)
        
        let keysToRemove = cumulativePositionCache.keys.filter { !keepRange.contains($0) }
        
        // Only clean if we have too many entries outside the range
        if keysToRemove.count > 200 {
            for key in keysToRemove {
                cumulativePositionCache.removeValue(forKey: key)
            }
            print("DEBUG: 🧹 Cache cleanup: removed \(keysToRemove.count) entries, kept ±500 around month \(centerMonth)")
        }
    }
    
    private func cleanupCacheIfNeeded() {
        if weekCountCache.count > maxCacheSize {
            let sortedKeys = weekCountCache.keys.sorted { abs($0) > abs($1) }
            let keysToRemove = Array(sortedKeys.prefix(20))
            
            for key in keysToRemove {
                weekCountCache.removeValue(forKey: key)
                monthHeightCache.removeValue(forKey: key)
                monthDaysCache.removeValue(forKey: key)
                // Note: Don't remove from cumulativePositionCache here - it has its own cleanup
            }
        }
    }
    
    func clearCache() {
        weekCountCache.removeAll()
        monthHeightCache.removeAll()
        monthDaysCache.removeAll()
        cumulativePositionCache.removeAll()
        // Restore initial position
        cumulativePositionCache[0] = 0
        lastAccessedMonth = 0
        lastCacheCleanupTime = Date()  // Reset cleanup time
    }
}

// MARK: - Simple Viewport Calculator (ORIGINAL LOGIC)
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
        
        // INFINITE backward search - no limits!
        while currentY > viewportTop {
            monthOffset -= 1
            currentY = calculator.getYPosition(for: monthOffset)
        }
        
        // INFINITE forward search to build visible months - no limits!
        while currentY < viewportBottom {
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
        
        return ViewportData(
            visibleMonths: visibleMonths,
            totalContentHeight: CGFloat.greatestFiniteMagnitude
        )
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
    
    private let currentDate = Date()
    
    // Separate scroll states for native momentum
    @State private var baseScrollOffset: CGFloat = 0
    @State private var animatedScrollOffset: CGFloat = 0
    @State private var dragStartOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var screenHeight: CGFloat = 0
    @State private var screenWidth: CGFloat = 0
    
    // Native momentum physics state
    @State private var momentumVelocity: CGFloat = 0
    @State private var momentumTimer: Timer?
    
    // Simple optimization: throttle viewport recalculation
    @State private var lastViewportUpdateScroll: CGFloat = 0
    private let viewportUpdateThreshold: CGFloat = 20
    
    // Computed property for current scroll offset
    private var currentScrollOffset: CGFloat {
        isDragging ? baseScrollOffset : animatedScrollOffset
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let availableWidth = geometry.size.width
            
            ZStack {
                backgroundView
                
                VStack(spacing: 0) {
                    // Fixed header
                    headerView
                    
                    // Dynamic viewport renderer
                    if let calc = calculator {
                        dynamicViewportRenderer(calculator: calc, screenWidth: availableWidth, screenHeight: availableHeight)
                    }
                }
            }
            .onAppear {
                setupCalculator(screenHeight: availableHeight, screenWidth: availableWidth)
            }
            .onDisappear {
                stopMomentumAnimation()
            }
            .onChange(of: geometry.size) { newSize in
                if abs(newSize.height - screenHeight) > 1 || abs(newSize.width - screenWidth) > 1 {
                    setupCalculator(screenHeight: newSize.height, screenWidth: newSize.width)
                }
            }
        }
    }
    
    // MARK: - Stable Dynamic Viewport Renderer
    
    private func dynamicViewportRenderer(calculator: MonthCalculator, screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        // Simple optimization: only recalculate viewport when scroll changes significantly
        let shouldUpdateViewport = abs(currentScrollOffset - lastViewportUpdateScroll) > viewportUpdateThreshold || isDragging
        
        // Use the scroll position for calculation (either current for smooth updates, or cached for performance)
        let scrollForCalculation = shouldUpdateViewport ? currentScrollOffset : lastViewportUpdateScroll
        
        let dynamicViewport = ViewportCalculator.calculateDynamicViewport(
            scrollOffset: scrollForCalculation,
            screenHeight: screenHeight,
            screenWidth: screenWidth,
            calculator: calculator
        )
        
        return ZStack(alignment: .topLeading) {
            // Render months from dynamic viewport
            ForEach(dynamicViewport.visibleMonths.indices, id: \.self) { monthIndex in
                let month = dynamicViewport.visibleMonths[monthIndex]
                
                // Month header - FIXED position
                Text(calculator.getMonthName(for: month.monthOffset))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(width: screenWidth, height: 60)
                    .position(x: screenWidth / 2, y: month.yPosition + 30)
                
                // Days - FIXED positions with visibility optimization
                ForEach(month.visibleDays.indices, id: \.self) { dayIndex in
                    let day = month.visibleDays[dayIndex]
                    
                    // Performance optimization: only render days that are reasonably close to screen
                    let dayScreenY = day.yPosition + currentScrollOffset
                    if dayScreenY > -100 && dayScreenY < screenHeight + 100 {
                        ZStack {
                            // Today highlight
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
        .offset(y: currentScrollOffset)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    // IMMEDIATELY stop any momentum animation
                    if !isDragging {
                        isDragging = true
                        stopMomentumAnimation()
                        baseScrollOffset = animatedScrollOffset
                        dragStartOffset = baseScrollOffset
                    }
                    
                    // Update base scroll position (no animation during drag)
                    baseScrollOffset = dragStartOffset + value.translation.height
                    updateViewportTracking()
                }
                .onEnded { value in
                    handleNativeDragEnd(velocity: value.velocity.height)
                    updateViewportTracking()
                }
        )
    }
    
    private func updateViewportTracking() {
        let shouldUpdate = abs(currentScrollOffset - lastViewportUpdateScroll) > viewportUpdateThreshold
        if shouldUpdate {
            lastViewportUpdateScroll = currentScrollOffset
        }
    }
    
    // MARK: - Native Momentum Methods
    
    private func handleNativeDragEnd(velocity: CGFloat) {
        isDragging = false
        animatedScrollOffset = baseScrollOffset
        
        let clampedVelocity = max(-MomentumPhysics.maxVelocity, min(MomentumPhysics.maxVelocity, velocity))
        let adjustedVelocity = clampedVelocity * MomentumPhysics.velocityMultiplier
        
        if abs(adjustedVelocity) > MomentumPhysics.minVelocity {
            startNativeMomentum(initialVelocity: adjustedVelocity)
        }
    }
    
    private func startNativeMomentum(initialVelocity: CGFloat) {
        stopMomentumAnimation()
        momentumVelocity = initialVelocity
        
        momentumTimer = Timer.scheduledTimer(withTimeInterval: MomentumPhysics.frameInterval, repeats: true) { _ in
            self.updateMomentumAnimation()
        }
    }
    
    private func updateMomentumAnimation() {
        momentumVelocity *= MomentumPhysics.friction
        animatedScrollOffset += momentumVelocity / MomentumPhysics.targetFPS
        
        if abs(momentumVelocity) < MomentumPhysics.minVelocity {
            stopMomentumAnimation()
            baseScrollOffset = animatedScrollOffset
        }
    }
    
    private func stopMomentumAnimation() {
        momentumTimer?.invalidate()
        momentumTimer = nil
        momentumVelocity = 0
    }
    
    // MARK: - Subviews
    
    private var backgroundView: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemBackground),
                Color.red.opacity(0.02)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
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
        
        if abs(baseScrollOffset) < 0.1 && abs(animatedScrollOffset) < 0.1 {
            baseScrollOffset = 0
            animatedScrollOffset = 0
        }
        
        print("DEBUG: 🎯 INFINITE календарь настроен для \(screenWidth)x\(screenHeight) - бесконечный скролл")
    }
}

// MARK: - Preview
#Preview {
    CalendarView()
}
