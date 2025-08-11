//
//  CalendarView.swift - Локализованный календарь с оптимизацией
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.07.2025.
//

import SwiftUI

// MARK: - Main Calendar View
struct CalendarView: View {
    @Binding var bottomCenterOffset: CGFloat
    @Binding var floatingButtonState: FloatingButtonState
    let calendarController: CalendarController
    
    @State private var calculator: MonthCalculator?
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var currentDate = Date()
    @State private var calendarHeight: CGFloat = 0
    @State private var calendarWidth: CGFloat = 0
    @State private var initialCenterOffset: CGFloat = 0
    @State private var localizedWeekdays: [String] = []
    @State private var globalTopOffset: CGFloat = 0
    @State private var calendar = Calendar.current
    
    @State private var lastViewportUpdateScroll: CGFloat = 0
    private let viewportUpdateThreshold: CGFloat = CalendarConstants.viewportUpdateThreshold
    private let dayVisibilityBuffer: CGFloat = CalendarConstants.dayVisibilityBuffer
    private let monthHeaderHeight: CGFloat = CalendarConstants.monthHeaderHeight
    private let headerHeight: CGFloat = CalendarConstants.weekdaysHeaderHeight
    
    init(
        bottomCenterOffset: Binding<CGFloat> = .constant(0),
        floatingButtonState: Binding<FloatingButtonState>,
        calendarController: CalendarController
    ) {
        self._bottomCenterOffset = bottomCenterOffset
        self._floatingButtonState = floatingButtonState
        self.calendarController = calendarController
    }
    
    var body: some View {
        GeometryReader { geometry in
            
            let currentGlobalTopOffset = geometry.frame(in: .global).minY
            
            VStack(spacing: 0) {
                CalendarHeaderView(
                    weekdays: localizedWeekdays,
                    width: calendarWidth,
                    height: CalendarConstants.weekdaysHeaderHeight
                )
                
                ZStack {
                    if let calc = calculator {
                        InfiniteScrollContainer(
                            scrollOffset: $scrollOffset,
                            onScrollChanged: { newOffset in
                                self.scrollOffset = newOffset
                                updateViewportTracking()
                                updateFloatingButtonState()
                            },
                            onDragStateChanged: { dragging in
                                self.isDragging = dragging
                            },
                            initialCenterOffset: initialCenterOffset,
                            calculator: calc,
                            currentDate: currentDate
                        )
                        
                        dynamicViewportRenderer(calculator: calc, width: calendarWidth, height: calendarHeight)
                    }
                }
            }
            .onAppear {
                calendarController.setScrollAction {
                    withAnimation(.easeInOut(duration: 0.6)) {
                        scrollOffset = initialCenterOffset
                    }
                }
            }
            .onChange(of: geometry.size) { newSize in
                let headerHeight = CalendarConstants.weekdaysHeaderHeight
                
                globalTopOffset = currentGlobalTopOffset
                setupCalculator(
                    height: newSize.height - headerHeight,
                    width: newSize.width
                )
            }
            .onChange(of: currentGlobalTopOffset) { newOffset in
                globalTopOffset = newOffset
                
                guard let calc = calculator else { return }
                
                initialCenterOffset = calculateInitialCenterOffset(calculator: calc)
                scrollOffset = initialCenterOffset
                updateFloatingButtonState()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                handleAppStateChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                handleAppStateChange()
            }
        }
    }
    
    // MARK: - Calculate Initial Center Offset
    private func calculateInitialCenterOffset(calculator: MonthCalculator) -> CGFloat {
        let currentMonthY = calculator.getYPosition(for: 0)
        let monthDays = calculator.getMonthDays(for: 0)
        let weekHeight = calculator.weekHeight
        
        var todayWeekIndex = 0
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
        
        let availableCalendarHeight = calendarHeight
        let centerPosition = availableCalendarHeight / 2
        let adjustedCenter = centerPosition - (globalTopOffset + headerHeight) / 2
        
        return adjustedCenter - todayWeekCenterY
    }
    
    private func handleAppStateChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            currentDate = Date()
            updateCalendarAndCalculatorIfNeeded()
        }
    }
    
    private func updateCalendarAndCalculatorIfNeeded() {
        let newCalendar = Calendar.current
        
        let localeChanged = newCalendar.locale?.identifier != calendar.locale?.identifier
        let firstWeekdayChanged = newCalendar.firstWeekday != calendar.firstWeekday
        
        if localeChanged || firstWeekdayChanged {
            calendar = newCalendar
        }
        
        updateCalculatorIfNeeded()
    }
    
    private func setupCalculator(height: CGFloat, width: CGFloat) {
        self.calendarHeight = height
        self.calendarWidth = width
        
        guard height > 0 && width > 0 else { return }
        
        let actualCurrentDate = Date()
        currentDate = actualCurrentDate
        
        let newCalculator = MonthCalculator(
            currentDate: actualCurrentDate,
            screenHeight: height,
            calendar: calendar
        )
        
        localizedWeekdays = newCalculator.getLocalizedWeekdays()
        
        calculator = newCalculator
        initialCenterOffset = calculateInitialCenterOffset(calculator: newCalculator)
        scrollOffset = initialCenterOffset
        
        updateFloatingButtonState()
    }
    
    private func updateCalculatorIfNeeded() {
        guard let currentCalculator = calculator else {
            return
        }
        
        let currentLocale = Locale.current.identifier
        let currentFirstWeekday = calendar.firstWeekday
        
        let localeChanged = currentLocale != currentCalculator.cachedLocaleIdentifier
        let firstWeekdayChanged = currentFirstWeekday != currentCalculator.cachedFirstWeekday
        
        let dateChanged = !calendar.isDate(currentDate, inSameDayAs: currentCalculator.currentDate)
        
        if localeChanged || firstWeekdayChanged || dateChanged {
            let newCalculator = MonthCalculator(currentDate: currentDate, screenHeight: calendarHeight, calendar: calendar)
            localizedWeekdays = newCalculator.getLocalizedWeekdays()
            
            calculator = newCalculator

            initialCenterOffset = calculateInitialCenterOffset(calculator: newCalculator)
            updateFloatingButtonState()
        }
    }
    
    private func updateFloatingButtonState() {
        let headerHeight: CGFloat = CalendarConstants.weekdaysHeaderHeight
        
        let fullScreenHeight = calendarHeight + CalendarConstants.weekdaysHeaderHeight + globalTopOffset
        
        let baseThreshold = fullScreenHeight / 2
        
        let deviation = scrollOffset - initialCenterOffset
        
        let downThreshold = baseThreshold
        let upThreshold = -baseThreshold + globalTopOffset + headerHeight
        
        let newState: FloatingButtonState = {
            if deviation > downThreshold {
                return .arrowDown
            } else if deviation < upThreshold {
                return .arrowUp
            } else {
                return .plus
            }
        }()
        
        if newState != floatingButtonState {
            floatingButtonState = newState
        }
    }
    
    private func dynamicViewportRenderer(calculator: MonthCalculator, width: CGFloat, height: CGFloat) -> some View {
        let shouldUpdateViewport = abs(scrollOffset - lastViewportUpdateScroll) > viewportUpdateThreshold || isDragging
        let scrollForCalculation = shouldUpdateViewport ? scrollOffset : lastViewportUpdateScroll
        
        let dynamicViewport = ViewportCalculator.calculateDynamicViewport(
            scrollOffset: scrollForCalculation,
            screenHeight: height,
            screenWidth: width,
            calculator: calculator,
            currentDate: currentDate,
            calendar: calendar
        )
        
        return ZStack(alignment: .topLeading) {
            ForEach(dynamicViewport.visibleMonths.indices, id: \.self) { monthIndex in
                let month = dynamicViewport.visibleMonths[monthIndex]
                
                Text(calculator.getMonthName(for: month.monthOffset))
                    .font(.title3)
                    .fontWeight(.heavy)
                    .foregroundColor(.secondary)
                    .frame(width: width, height: 60)
                    .position(x: width / 2, y: month.yPosition + 30)
                
                ForEach(month.visibleDays.indices, id: \.self) { dayIndex in
                    let day = month.visibleDays[dayIndex]
                    let horizontalPadding = CalendarConstants.horizontalPadding
                    
                    let dayScreenY = day.yPosition + scrollOffset
                    if dayScreenY > -dayVisibilityBuffer && dayScreenY < height + dayVisibilityBuffer {
                        let today = calendar.startOfDay(for: currentDate)
                        let dayDate = day.date != nil ? calendar.startOfDay(for: day.date!) : nil
                        let isFutureDay = dayDate != nil && dayDate! > today
                        
                        ZStack {
                            if day.isToday {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)
                            }
                            
                            Text(day.dayNumber)
                                .font(.system(size: 16, weight: day.isToday ? .bold : .medium))
                                .foregroundColor(
                                    day.isToday ? .white :
                                    isFutureDay ? Color(UIColor.tertiaryLabel) :
                                    .primary
                                )
                        }
                        .position(
                            x: day.xPosition + (width - horizontalPadding) / 14,
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
        let baseThreshold = viewportUpdateThreshold
        let adaptiveThreshold = isDragging ? baseThreshold * 0.5 : baseThreshold
        
        let shouldUpdate = abs(scrollOffset - lastViewportUpdateScroll) > adaptiveThreshold
        
        if shouldUpdate {
            lastViewportUpdateScroll = scrollOffset
        }
    }
}

#Preview {
    let previewController = CalendarController()
    
    CalendarView(
        floatingButtonState: .constant(.plus),
        calendarController: previewController
    )
}
