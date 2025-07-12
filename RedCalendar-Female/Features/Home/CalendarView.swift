//
//  CalendarView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.07.2025.
//

import SwiftUI

// MARK: - MonthCalculator (SINGLE SOURCE OF TRUTH)
struct MonthCalculator {
    let currentDate: Date
    let screenHeight: CGFloat
    
    var weekHeight: CGFloat {
        return floor(max(50, (screenHeight - 31) / 15))
    }
    
    func getWeeksCount(for monthOffset: Int) -> Int {
        let monthDate = Calendar.current.date(byAdding: .month, value: monthOffset, to: currentDate) ?? currentDate
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: monthDate)?.start ?? monthDate
        let range = calendar.range(of: .day, in: .month, for: monthDate) ?? 1..<32
        let daysInMonth = range.count
        
        // Get weekday of first day (1=Sunday, 2=Monday, ..., 7=Saturday)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        
        // Calculate empty cells before first day (our calendar starts with Monday)
        let emptyCellsAtStart = (firstWeekday + 5) % 7
        
        // Total cells needed
        let totalCells = emptyCellsAtStart + daysInMonth
        
        // Number of weeks (rows)
        return Int(ceil(Double(totalCells) / 7.0))
    }
    
    func getMonthHeight(for monthOffset: Int) -> CGFloat {
        let weeksCount = getWeeksCount(for: monthOffset)
        let headerHeight: CGFloat = 60
        let bottomSpacing: CGFloat = 20
        let gridVerticalSpacing: CGFloat = 4 // spacing between week rows
        
        // Calculate grid height: weeks * weekHeight + spacing between weeks
        let gridHeight = (CGFloat(weeksCount) * weekHeight) + (CGFloat(weeksCount - 1) * gridVerticalSpacing)
        
        return floor(headerHeight + gridHeight + bottomSpacing)
    }
}

struct CalendarView: View {
    @State private var offset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    @State private var velocity: CGFloat = 0
    @State private var displayTimer: Timer?
    @State private var animationTimer: Timer?
    
    private let bufferMonths = 20 // Number of months to render ahead/behind
    
    @State private var currentCenterMonth: Int = 0 // Months offset from current month
    @State private var renderedMonths: [Int] = []
    @State private var screenHeight: CGFloat = 0
    @State private var calculator: MonthCalculator?
    
    private let currentDate = Date()
    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = geometry.size.height
            let calc = MonthCalculator(currentDate: currentDate, screenHeight: availableHeight)
            
            ZStack {
                // Background gradient similar to WelcomeView
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
                    // Fixed header with weekdays
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
                    
                    // Calendar months container - expand to fill available space
                    ZStack(alignment: .top) {
                        ForEach(renderedMonths, id: \.self) { monthOffset in
                            MonthView(
                                monthOffset: monthOffset,
                                currentDate: currentDate,
                                calculator: calc
                            )
                            .offset(y: calculateMonthPosition(monthOffset, calculator: calc) + offset + dragOffset)
                            .zIndex(Double(-abs(monthOffset))) // Ensure proper layering
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                }
            }
            .onAppear {
                screenHeight = availableHeight
                calculator = calc
                setupInitialState()
                startAnimationTimer()
            }
            .onChange(of: availableHeight) { newHeight in
                screenHeight = newHeight
                calculator = MonthCalculator(currentDate: currentDate, screenHeight: newHeight)
            }
        }
        .onDisappear {
            stopAnimationTimer()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Stop momentum during drag
                    velocity = 0
                    dragOffset = value.translation.height
                }
                .onEnded { value in
                    handleDragEnd(translation: value.translation.height, velocity: value.velocity.height)
                }
        )
    }
    
    // MARK: - Month Position Calculations
    
    private func calculateMonthPosition(_ monthOffset: Int, calculator: MonthCalculator) -> CGFloat {
        var position: CGFloat = 0
        
        if monthOffset > 0 {
            // Calculate cumulative height of all previous months
            for i in 0..<monthOffset {
                position += calculator.getMonthHeight(for: i)
            }
        } else if monthOffset < 0 {
            // Calculate cumulative height of all previous months (going backwards)
            for i in stride(from: -1, through: monthOffset, by: -1) {
                position -= calculator.getMonthHeight(for: i)
            }
        }
        
        return position
    }
    
    // MARK: - Setup Methods
    
    private func setupInitialState() {
        // Generate initial rendered months
        updateRenderedMonths()
    }
    
    private func updateRenderedMonths() {
        let startMonth = currentCenterMonth - bufferMonths
        let endMonth = currentCenterMonth + bufferMonths
        renderedMonths = Array(startMonth...endMonth)
    }
    
    // MARK: - Animation Timer for smooth rendering
    
    private func startAnimationTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            animationUpdate()
        }
    }
    
    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func animationUpdate() {
        // Apply velocity-based momentum scrolling only when not dragging
        if abs(velocity) > 10 && dragOffset == 0 {
            velocity *= 0.95 // Friction
            offset += velocity / 120.0 // Slower momentum scrolling
            
            // Update visible months based on scroll position
            updateCurrentCenterMonth()
            updateRenderedMonths()
        } else {
            velocity = 0
        }
    }
    
    // MARK: - Gesture Handling
    
    private func handleDragEnd(translation: CGFloat, velocity: CGFloat) {
        let totalOffset = offset + translation
        
        // Set reduced velocity for momentum scrolling
        self.velocity = velocity * 0.3 // Reduce momentum strength
        
        // Apply translation to offset - free scrolling without snapping
        withAnimation(.easeOut(duration: 0.3)) {
            offset = totalOffset
            dragOffset = 0
        }
        
        updateCurrentCenterMonth()
        updateRenderedMonths()
    }
    
    private func updateCurrentCenterMonth() {
        guard let calc = calculator else { return }
        
        // Find the month that's closest to center of screen
        var closestMonth = currentCenterMonth
        var minDistance = CGFloat.infinity
        
        for monthOffset in renderedMonths {
            let monthPosition = calculateMonthPosition(monthOffset, calculator: calc)
            let distance = abs(monthPosition + offset)
            
            if distance < minDistance {
                minDistance = distance
                closestMonth = monthOffset
            }
        }
        
        if closestMonth != currentCenterMonth {
            currentCenterMonth = closestMonth
            updateRenderedMonths()
        }
    }
}

// MARK: - MonthView Component

private struct MonthView: View {
    let monthOffset: Int
    let currentDate: Date
    let calculator: MonthCalculator
    
    private var monthDate: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: currentDate) ?? currentDate
    }
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: monthDate).capitalized
    }
    
    private var monthDays: [Date?] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: monthDate)?.start ?? monthDate
        let range = calendar.range(of: .day, in: .month, for: monthDate) ?? 1..<32
        
        // Get weekday of first day (1=Sunday, 2=Monday, ..., 7=Saturday)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        
        // Calculate empty cells before first day (our calendar starts with Monday)
        let emptyCellsAtStart = (firstWeekday + 5) % 7
        
        var days: [Date?] = Array(repeating: nil, count: emptyCellsAtStart)
        
        // Add all days of the month
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        // Pad to complete the last week (total cells should be multiple of 7)
        let totalCells = emptyCellsAtStart + range.count
        let weeksNeeded = Int(ceil(Double(totalCells) / 7.0))
        let cellsNeeded = weeksNeeded * 7
        
        while days.count < cellsNeeded {
            days.append(nil)
        }
        
        return days
    }
    
    var body: some View {
        let weeksCount = calculator.getWeeksCount(for: monthOffset)
        let weekHeight = calculator.weekHeight
        
        VStack(spacing: 0) {
            // Month header
            Text(monthName)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .frame(height: 60)
                .frame(maxWidth: .infinity)
            
            // Calendar grid
            VStack(spacing: 4) {
                ForEach(0..<weeksCount, id: \.self) { weekIndex in
                    HStack(spacing: 4) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            let cellIndex = weekIndex * 7 + dayIndex
                            if cellIndex < monthDays.count {
                                DayCell(
                                    date: monthDays[cellIndex],
                                    isToday: monthDays[cellIndex] != nil && Calendar.current.isDate(monthDays[cellIndex]!, inSameDayAs: currentDate),
                                    cellHeight: weekHeight
                                )
                                .id("\(monthOffset)-\(cellIndex)")
                            } else {
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(height: weekHeight)
                            }
                        }
                    }
                    .frame(height: weekHeight)
                }
            }
            .padding(.horizontal, 12)
            
            // Bottom spacing between months
            Spacer()
                .frame(height: 20)
        }
        .frame(maxWidth: .infinity)
        .id(monthOffset)
    }
}

// MARK: - DayCell Component

private struct DayCell: View {
    let date: Date?
    let isToday: Bool
    let cellHeight: CGFloat
    
    @State private var hasEvent = false // Random events for demo
    @State private var hasImportantEvent = false
    
    private var dayNumber: String {
        guard let date = date else { return "" }
        return String(Calendar.current.component(.day, from: date))
    }
    
    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                // Today highlight - red circle like in the image
                if isToday {
                    Circle()
                        .fill(Color.red)
                        .frame(width: min(cellHeight * 0.6, 32), height: min(cellHeight * 0.6, 32))
                }
                
                Text(dayNumber)
                    .font(.system(size: min(cellHeight * 0.3, 16), weight: .medium))
                    .foregroundColor(isToday ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight * 0.7)
            
            // Event indicators (like in the reference image) - only for actual dates
            VStack(spacing: 1) {
                if date != nil && hasEvent {
                    // Dotted line indicator (blue dashed line in image)
                    Rectangle()
                        .fill(Color.blue)
                        .frame(height: 1)
                        .overlay(
                            Rectangle()
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                .foregroundColor(.clear)
                        )
                }
                
                if date != nil && hasImportantEvent {
                    // Solid line indicator (red line in image)
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 2)
                }
            }
            .frame(width: min(cellHeight * 0.6, 24))
            .frame(height: cellHeight * 0.3)
        }
        .frame(height: cellHeight)
        .onAppear {
            // Random events for demo purposes - only for actual dates
            if date != nil {
                hasEvent = Int.random(in: 0...100) < 20
                hasImportantEvent = Int.random(in: 0...100) < 10
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CalendarView()
}
