//
//  CalendarView.swift - Локализованный календарь с оптимизацией
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.07.2025.
//

import SwiftUI

// MARK: - Main Calendar View
struct CalendarView: View {
    @EnvironmentObject var store: AppStore
    @Binding var bottomCenterOffset: CGFloat
    @Binding var floatingButtonState: FloatingButtonState
    @Binding var scrollCommand: ScrollCommand
    
    @State private var calculator: MonthCalculator?
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var currentDate = Date()
    @State private var calendarHeight: CGFloat = 0
    @State private var calendarWidth: CGFloat = 0
    
    @State private var todayWeekCenterY: CGFloat = 0
    @State private var uiOffset: CGFloat = 0
    @State private var selectionOffset: CGFloat = 0
    
    @State private var localizedWeekdays: [String] = []
    @State private var globalTopOffset: CGFloat = 0
    @State private var calendar = Calendar.current
    
    @State private var lastViewportUpdateScroll: CGFloat = 0
    
    private var effectiveOffset: CGFloat {
        uiOffset - todayWeekCenterY - selectionOffset
    }
    
    private let viewportUpdateThreshold: CGFloat = CalendarConstants.viewportUpdateThreshold
    private let dayVisibilityBuffer: CGFloat = CalendarConstants.dayVisibilityBuffer
    private let monthHeaderHeight: CGFloat = CalendarConstants.monthHeaderHeight
    private let headerHeight: CGFloat = CalendarConstants.weekdaysHeaderHeight
    
    init(
        prefferedBottomOffset: Binding<CGFloat> = .constant(0),
        floatingButtonState: Binding<FloatingButtonState>,
        scrollCommand: Binding<ScrollCommand>
    ) {
        self._bottomCenterOffset = prefferedBottomOffset
        self._floatingButtonState = floatingButtonState
        self._scrollCommand = scrollCommand
    }
    
    var body: some View {
        GeometryReader { geometry in
            
            let currentGlobalTopOffset = geometry.safeAreaInsets.top
            
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
                            scrollCommand: $scrollCommand,
                            onScrollChanged: { newOffset in
                                DispatchQueue.main.async {
                                    self.scrollOffset = newOffset
                                    updateViewportTracking()
                                    updateFloatingButtonState()
                                }
                            },
                            onDragStateChanged: { dragging in
                                DispatchQueue.main.async {
                                    self.isDragging = dragging
                                }
                            },
                            onDayTapped: { date in
                                let dayStamp = Daystamp(from: date, calendar: calendar)
                                store.send(.setSelectedDayStamp(dayStamp))
                            },
                            initialCenterOffset: effectiveOffset,
                            calculator: calc,
                            currentDate: currentDate
                        )
                        
                        dynamicViewportRenderer(calculator: calc, width: calendarWidth, height: calendarHeight)
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
                let oldOffset = globalTopOffset
                globalTopOffset = newOffset
                
                uiOffset = calculateUIOffset()
                
                if oldOffset == 0 {
                    scrollOffset = effectiveOffset
                }
                
                updateFloatingButtonState()
            }
            .onChange(of: bottomCenterOffset) {
                AppLogger.info("Preferred bottom offset = \($0)")
            }
            .onChange(of: getSelectedDayStamp()) { newValue in
                guard let calc = calculator else { return }
                
                if let selectedDayStamp = newValue {
                    let selectedDate = selectedDayStamp.toDate(calendar: calendar)
                    selectionOffset = calculateSelectionOffset(for: selectedDate, calculator: calc)
                    scrollCommand = .animateToCenter
                } else {
                    selectionOffset = 0
                    DispatchQueue.main.async {
                        updateFloatingButtonState()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                handleAppStateChange()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                handleAppStateChange()
            }
        }
    }
    
    // MARK: - Get Selected DayStamp
    private func getSelectedDayStamp() -> Daystamp? {
        if case .authenticated(_, _, let calendarState) = store.state.authState {
            return calendarState.selectedDayStamp
        }
        return nil
    }
    
    // MARK: - Week Center Y Calculation (renamed from calculateWeekCenterY)
    private func weekCenterY(for date: Date, calculator: MonthCalculator) -> CGFloat {
        let normalized = calendar.startOfDay(for: date)
        let normalizedCurrent = calendar.startOfDay(for: currentDate)
        
        guard let targetMonthStart = calendar.dateInterval(of: .month, for: normalized)?.start,
              let currentMonthStart = calendar.dateInterval(of: .month, for: normalizedCurrent)?.start else {
            return 0
        }
        
        let monthOffset = calendar.dateComponents([.month], from: currentMonthStart, to: targetMonthStart).month ?? 0
        
        let monthY = calculator.getYPosition(for: monthOffset)
        let monthDays = calculator.getMonthDays(for: monthOffset)
        let weekHeight = calculator.weekHeight
        
        var weekIndex = 0
        for (index, dayDate) in monthDays.enumerated() {
            if let dayDate = dayDate, calendar.isDate(dayDate, inSameDayAs: normalized) {
                weekIndex = index / 7
                break
            }
        }
        
        let gridStartY = monthY + monthHeaderHeight
        let weekY = gridStartY + CGFloat(weekIndex) * (weekHeight + CalendarConstants.gridVerticalSpacing)
        return weekY + weekHeight / 2
    }
    
    // MARK: - NEW: Calculate UI Offset
    private func calculateUIOffset() -> CGFloat {
        let availableCalendarHeight = calendarHeight
        let centerPosition = availableCalendarHeight / 2
        let adjustedCenter = centerPosition - (globalTopOffset + headerHeight) / 2
        
        return adjustedCenter
    }
    
    // MARK: - NEW: Calculate Selection Offset
    private func calculateSelectionOffset(for selectedDate: Date, calculator: MonthCalculator) -> CGFloat {
        return weekCenterY(for: selectedDate, calculator: calculator) - todayWeekCenterY
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
        
        todayWeekCenterY = weekCenterY(for: currentDate, calculator: newCalculator)
        uiOffset = calculateUIOffset()
        
        if let selectedDayStamp = getSelectedDayStamp() {
            let selectedDate = selectedDayStamp.toDate(calendar: calendar)
            selectionOffset = calculateSelectionOffset(for: selectedDate, calculator: newCalculator)
        } else {
            selectionOffset = 0
        }
        
        scrollOffset = effectiveOffset
        
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
            
            todayWeekCenterY = weekCenterY(for: currentDate, calculator: newCalculator)
            
            if let selectedDayStamp = getSelectedDayStamp() {
                let selectedDate = selectedDayStamp.toDate(calendar: calendar)
                selectionOffset = calculateSelectionOffset(for: selectedDate, calculator: newCalculator)
            }
            
            updateFloatingButtonState()
        }
    }
    
    private func updateFloatingButtonState() {
        let headerHeight: CGFloat = CalendarConstants.weekdaysHeaderHeight
        
        let fullScreenHeight = calendarHeight + CalendarConstants.weekdaysHeaderHeight + globalTopOffset
        
        let baseThreshold = fullScreenHeight / 2
        
        let deviation = scrollOffset - effectiveOffset
        
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
        
        // Get selected day from CalendarState
        let selectedDayStamp: Daystamp? = {
            if case .authenticated(_, _, let calendarState) = store.state.authState {
                return calendarState.selectedDayStamp
            }
            return nil
        }()
        
        
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
                        
                        let isSelected: Bool = {
                            guard let date = day.date, let selected = selectedDayStamp else {
                                return false
                            }
                            let currentDayStamp = Daystamp(from: date, calendar: calendar)
                            return currentDayStamp.rawValue == selected.rawValue
                        }()
                        
                        ZStack {
                            if day.isToday {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)
                            }
                            
                            if isSelected {
                                Circle()
                                    .stroke(Color.blue, lineWidth: 2)
                                    .frame(
                                        width: day.isToday ? 38 : 32,
                                        height: day.isToday ? 38 : 32
                                    )
                            }
                            
                            Text(day.dayNumber)
                                .font(.system(size: 16, weight: day.isToday ? .bold : .medium))
                                .foregroundColor(
                                    day.isToday ? .white :
                                    isSelected ? .blue :
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
    CalendarView(
        floatingButtonState: .constant(.plus),
        scrollCommand: .constant(.none)
    )
}
