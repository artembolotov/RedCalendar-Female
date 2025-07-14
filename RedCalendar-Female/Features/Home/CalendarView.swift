//
//  CalendarView.swift - Низкоуровневая отрисовка окна просмотра 🎯⚡
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.07.2025.
//
//  🎯 VIEWPORT RENDERING APPROACH:
//  🖼️ Зафиксированный viewport с большим буфером
//  🎨 НЕ пересчитываем элементы во время прокрутки
//  📐 Прямые математические вычисления позиций
//  🚫 Мгновенное прерывание анимаций
//  ✅ Полный контроль над рендерингом
//  ⚡ Стабильная прокрутка
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

// MARK: - Simplified MonthCalculator
final class MonthCalculator: ObservableObject {
    let currentDate: Date
    let screenHeight: CGFloat
    
    private var weekCountCache: [Int: Int] = [:]
    private var monthHeightCache: [Int: CGFloat] = [:]
    private var monthDaysCache: [Int: [Date?]] = [:]
    
    init(currentDate: Date, screenHeight: CGFloat) {
        self.currentDate = currentDate
        self.screenHeight = screenHeight
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
    
    // Clear position calculation
    func getYPosition(for monthOffset: Int) -> CGFloat {
        var totalHeight: CGFloat = 0
        
        if monthOffset > 0 {
            // Positive offsets: months AFTER current (below Y=0)
            for offset in 0..<monthOffset {
                totalHeight += getMonthHeight(for: offset)
            }
        } else if monthOffset < 0 {
            // Negative offsets: months BEFORE current (above Y=0)
            for offset in stride(from: -1, through: monthOffset, by: -1) {
                totalHeight -= getMonthHeight(for: offset)
            }
        }
        // monthOffset == 0: return 0 (current month at Y=0)
        
        return totalHeight
    }
    
    func clearCache() {
        weekCountCache.removeAll()
        monthHeightCache.removeAll()
        monthDaysCache.removeAll()
    }
}

// MARK: - Fixed Viewport Calculator
class ViewportCalculator {
    static func calculateFixedViewport(
        screenHeight: CGFloat,
        screenWidth: CGFloat,
        calculator: MonthCalculator
    ) -> ViewportData {
        
        // Create a large fixed viewport covering many months
        let bufferMonths = 50 // ±50 months from current
        var visibleMonths: [VisibleMonth] = []
        
        for monthOffset in -bufferMonths...bufferMonths {
            let monthHeight = calculator.getMonthHeight(for: monthOffset)
            let monthY = calculator.getYPosition(for: monthOffset)
            
            let visibleMonth = createVisibleMonth(
                monthOffset: monthOffset,
                yPosition: monthY,
                height: monthHeight,
                screenWidth: screenWidth,
                calculator: calculator
            )
            visibleMonths.append(visibleMonth)
        }
        
        return ViewportData(
            visibleMonths: visibleMonths,
            totalContentHeight: abs(calculator.getYPosition(for: bufferMonths)) + abs(calculator.getYPosition(for: -bufferMonths))
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
        let dayWidth = (screenWidth - 24) / 7 // 12px padding on each side
        
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
    @State private var viewportData: ViewportData?
    
    private let currentDate = Date()
    
    // Separate scroll states for immediate interruption
    @State private var baseScrollOffset: CGFloat = 0      // Real position (no animation)
    @State private var animatedScrollOffset: CGFloat = 0  // Manual momentum position
    @State private var dragStartOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var momentumTimer: Timer?
    @State private var screenHeight: CGFloat = 0
    @State private var screenWidth: CGFloat = 0
    
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
                    
                    // Fixed viewport renderer
                    if let viewport = viewportData {
                        fixedViewportRenderer(viewport: viewport, screenWidth: availableWidth, screenHeight: availableHeight)
                    }
                }
            }
            .onAppear {
                setupCalculator(screenHeight: availableHeight, screenWidth: availableWidth)
            }
            .onDisappear {
                // Clean up momentum timer
                momentumTimer?.invalidate()
                momentumTimer = nil
            }
            .onChange(of: geometry.size) { newSize in
                if abs(newSize.height - screenHeight) > 1 || abs(newSize.width - screenWidth) > 1 {
                    setupCalculator(screenHeight: newSize.height, screenWidth: newSize.width)
                }
            }
        }
    }
    
    // MARK: - Fixed Viewport Renderer
    
    private func fixedViewportRenderer(viewport: ViewportData, screenWidth: CGFloat, screenHeight: CGFloat) -> some View {
        return ZStack(alignment: .topLeading) {
            // Render months near visible area for performance
            ForEach(viewport.visibleMonths.indices, id: \.self) { monthIndex in
                let month = viewport.visibleMonths[monthIndex]
                let adjustedY = month.yPosition + currentScrollOffset
                
                // Fixed visibility check: consider month height and add proper buffer
                let monthBottom = adjustedY + month.height
                let screenTop: CGFloat = -100  // Buffer above screen
                let screenBottom = screenHeight + 100  // Buffer below screen
                
                // Only render months that actually intersect with extended visible area
                if monthBottom > screenTop && adjustedY < screenBottom {
                    // Month header - FIXED position (never recalculated)
                    Text(calculator?.getMonthName(for: month.monthOffset) ?? "")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(width: screenWidth, height: 60)
                        .position(x: screenWidth / 2, y: month.yPosition + 30)
                    
                    // Days - FIXED positions (never recalculated)
                    ForEach(month.visibleDays.indices, id: \.self) { dayIndex in
                        let day = month.visibleDays[dayIndex]
                        
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
                            y: day.yPosition + (calculator?.weekHeight ?? 50) / 2
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: currentScrollOffset) // Use computed property
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    // IMMEDIATELY stop any momentum animation
                    if !isDragging {
                        isDragging = true
                        
                        // CRITICAL: Stop momentum timer immediately
                        momentumTimer?.invalidate()
                        momentumTimer = nil
                        
                        // Set base position to current animated position (seamless transition)
                        baseScrollOffset = animatedScrollOffset
                        dragStartOffset = baseScrollOffset
                        
                        print("DEBUG: ⭐ NEW DRAG STARTED - STOPPED MOMENTUM at offset: \(Int(dragStartOffset))")
                    }
                    
                    // Update base scroll position (no animation during drag)
                    baseScrollOffset = dragStartOffset + value.translation.height
                }
                .onEnded { value in
                    print("DEBUG: 🛑 DRAG ENDED at base offset: \(Int(baseScrollOffset))")
                    handleDragEnd(velocity: value.velocity.height)
                }
        )
    }
    
    private func handleDragEnd(velocity: CGFloat) {
        // Reset drag state
        isDragging = false
        
        // Set animated offset to current base position first
        animatedScrollOffset = baseScrollOffset
        
        // Only start momentum if there's significant velocity
        if abs(velocity) > 50 {
            let momentumMultiplier: CGFloat = 0.3
            let maxMomentum: CGFloat = screenHeight * 1.5
            let momentumDistance = min(max(velocity * momentumMultiplier, -maxMomentum), maxMomentum)
            
            let targetOffset = baseScrollOffset + momentumDistance
            
            print("DEBUG: 💨 Starting MANUAL momentum from \(Int(baseScrollOffset)) to \(Int(targetOffset))")
            
            startManualMomentum(from: baseScrollOffset, to: targetOffset, duration: 0.4)
        } else {
            print("DEBUG: 🚫 Skipping momentum (low velocity)")
        }
    }
    
    private func startManualMomentum(from startOffset: CGFloat, to targetOffset: CGFloat, duration: TimeInterval) {
        // Stop any existing momentum
        momentumTimer?.invalidate()
        
        let startTime = Date()
        let totalDistance = targetOffset - startOffset
        
        momentumTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / duration, 1.0)
            
            // Ease-out animation curve
            let easedProgress = 1.0 - pow(1.0 - progress, 3.0)
            
            animatedScrollOffset = startOffset + (totalDistance * easedProgress)
            
            if progress >= 1.0 {
                timer.invalidate()
                momentumTimer = nil
                baseScrollOffset = animatedScrollOffset
                print("DEBUG: ✅ Manual momentum finished at: \(Int(animatedScrollOffset))")
            }
        }
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
        
        // Calculate fixed viewport ONCE
        if let calc = calculator {
            viewportData = ViewportCalculator.calculateFixedViewport(
                screenHeight: screenHeight,
                screenWidth: screenWidth,
                calculator: calc
            )
            
            // Only reset offsets on very first setup
            if abs(baseScrollOffset) < 0.1 && abs(animatedScrollOffset) < 0.1 {
                baseScrollOffset = 0
                animatedScrollOffset = 0
                print("DEBUG: ✅ Initial setup - setting offsets to 0")
            } else {
                print("DEBUG: ⚠️ Screen size change - keeping existing offsets")
            }
        }
        
        print("DEBUG: Manual momentum календарь настроен для \(screenWidth)x\(screenHeight)")
        print("DEBUG: Months in viewport: \(viewportData?.visibleMonths.count ?? 0)")
    }
}

// MARK: - Preview
#Preview {
    CalendarView()
}
