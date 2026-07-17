//
//  CalendarView.swift - Локализованный календарь с оптимизацией
//  RedCalendar-Female
//
//  Created by Артём Болотов on 11.07.2025.
//

import SwiftUI
import Combine

// MARK: - Main Calendar View
struct CalendarView: View {
    @EnvironmentObject var store: AppStore
    @Binding var bottomCenterOffset: CGFloat
    @Binding var floatingButtonState: FloatingButtonState
    @Binding var scrollCommand: ScrollCommand
    
    // MARK: - State: Core Calendar
    @State private var calculator: MonthCalculator?
    @State private var calendar = Calendar.current
    @State private var localizedWeekdays: [String] = []
    
    // MARK: - State: Dimensions
    @State private var calendarHeight: CGFloat = 0
    @State private var calendarWidth: CGFloat = 0
    @State private var globalTopOffset: CGFloat = 0
    
    // MARK: - State: Scroll & Offsets
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var lastViewportUpdateScroll: CGFloat = 0
    
    // MARK: - State: Offset Components
    @State private var todayWeekCenterY: CGFloat = 0
    @State private var uiOffset: CGFloat = 0
    @State private var selectionOffset: CGFloat = 0
    
    // MARK: - State: Debouncer
    @State private var bottomOffsetDebouncer = PassthroughSubject<CGFloat, Never>()
    
    // MARK: - Computed Properties

    private var currentDate: Date {
        store.state.calendarState.todayDayStamp.toDate(calendar: calendar)
    }

    /// Adjusts calendar position when DayDetailsView is shown
    /// Returns offset to center selected date within visible area above the panel
    private var selectionUIOffset: CGFloat {
        bottomCenterOffset > 0 ? (bottomCenterOffset - globalTopOffset) / 2 : 0
    }
    
    /// Main offset that determines calendar scroll position
    /// - When DayDetails closed: centers on today's week
    /// - When DayDetails open: centers on selected date with panel adjustment
    private var effectiveOffset: CGFloat {
        let baseOffset = uiOffset - todayWeekCenterY
        return bottomCenterOffset > 0 ? baseOffset - selectionOffset - selectionUIOffset : baseOffset
    }
    
    // MARK: - Constants
    private let viewportUpdateThreshold: CGFloat = CalendarConstants.viewportUpdateThreshold
    private let dayVisibilityBuffer: CGFloat = CalendarConstants.dayVisibilityBuffer
    private let monthHeaderHeight: CGFloat = CalendarConstants.monthHeaderHeight
    private let headerHeight: CGFloat = CalendarConstants.weekdaysHeaderHeight
    private let bottomOffsetDebounceDelay: TimeInterval = 0.1
    
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
                
                // Recalculate only UI offset when globalTopOffset changes
                uiOffset = calculateUIOffset()
                
                if oldOffset == 0 {
                    scrollOffset = effectiveOffset
                }
                
                updateFloatingButtonState()
            }
            .onChange(of: bottomCenterOffset) { newValue in
                bottomOffsetDebouncer.send(newValue)
            }
            .onReceive(
                bottomOffsetDebouncer
                    .debounce(for: .seconds(bottomOffsetDebounceDelay), scheduler: DispatchQueue.main)
            ) { newValue in
                // Only animate when DayDetails is opening (not closing)
                if newValue > 0 && store.state.calendarState.selectedDayStamp != nil {
                    scrollCommand = .animateToCenter
                }
            }
            .onChange(of: store.state.calendarState.selectedDayStamp) { newValue in
                guard let calc = calculator else { return }
                handleDaySelection(newValue, calculator: calc)
            }
            .onChange(of: store.state.calendarState.todayDayStamp) { _ in
                updateCalculatorIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                updateCalendarAndCalculatorIfNeeded()
            }
        }
    }
    
    // MARK: - Day Selection Handler
    private func handleDaySelection(_ selectedDayStamp: Daystamp?, calculator: MonthCalculator) {
        if let selectedDayStamp = selectedDayStamp {
            let selectedDate = selectedDayStamp.toDate(calendar: calendar)
            selectionOffset = calculateSelectionOffset(for: selectedDate, calculator: calculator)
            
            // Animate only if DayDetails is already open
            if bottomCenterOffset > 0 {
                scrollCommand = .animateToCenter
            }
        } else {
            selectionOffset = 0
            updateFloatingButtonState()
        }
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
    
    // MARK: - Recalculate Offsets Helper
    private func recalculateOffsets(calculator: MonthCalculator) {
        todayWeekCenterY = weekCenterY(for: currentDate, calculator: calculator)
        uiOffset = calculateUIOffset()
        
        if let selectedDayStamp = store.state.calendarState.selectedDayStamp {
            let selectedDate = selectedDayStamp.toDate(calendar: calendar)
            selectionOffset = calculateSelectionOffset(for: selectedDate, calculator: calculator)
        } else {
            selectionOffset = 0
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

        let newCalculator = MonthCalculator(
            currentDate: currentDate,
            screenHeight: height,
            calendar: calendar
        )
        
        localizedWeekdays = newCalculator.getLocalizedWeekdays()
        
        calculator = newCalculator
        
        // Calculate all offset components
        recalculateOffsets(calculator: newCalculator)
        
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
            
            // Recalculate all offsets when calculator changes
            recalculateOffsets(calculator: newCalculator)
            
            updateFloatingButtonState()
        }
    }
    
    private func updateFloatingButtonState() {
        let headerHeight: CGFloat = CalendarConstants.weekdaysHeaderHeight
        
        let fullScreenHeight = calendarHeight + CalendarConstants.weekdaysHeaderHeight + globalTopOffset
        
        let baseThreshold = fullScreenHeight / 2
        
        // When no day is selected the panel is closed (or closing), so compare against
        // today's base position directly — effectiveOffset still includes the panel
        // adjustment for one render cycle after selectedDayStamp becomes nil.
        let reference = store.state.calendarState.selectedDayStamp == nil
            ? uiOffset - todayWeekCenterY
            : effectiveOffset
        let deviation = scrollOffset - reference
        
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
        
        let selectedDayStamp = store.state.calendarState.selectedDayStamp
        let dayDisplayStates = store.state.calendarState.dayDisplayStates
        let horizontalPadding = CalendarConstants.horizontalPadding
        let dayWidth = (width - horizontalPadding) / 7

        return ZStack(alignment: .topLeading) {
            ForEach(dynamicViewport.visibleMonths.indices, id: \.self) { monthIndex in
                let month = dynamicViewport.visibleMonths[monthIndex]

                Text(calculator.getMonthName(for: month.monthOffset))
                    .font(.title3)
                    .fontWeight(.heavy)
                    .foregroundColor(.secondary)
                    .frame(width: width, height: 60)
                    .position(x: width / 2, y: month.yPosition + 30)

                // MARK: - Layer 1: Period rectangles
                ForEach(month.visibleDays.indices, id: \.self) { dayIndex in
                    let day = month.visibleDays[dayIndex]
                    let dayScreenY = day.yPosition + scrollOffset
                    if dayScreenY > -dayVisibilityBuffer && dayScreenY < height + dayVisibilityBuffer {
                        if let daystamp = day.daystamp,
                           let displayState = dayDisplayStates[daystamp],
                           case .period(let position, let isPredicted) = displayState.cyclePhase {

                            let corners: UIRectCorner = {
                                switch position {
                                case .start:  return [.topLeft, .bottomLeft]
                                case .end:    return [.topRight, .bottomRight]
                                case .middle: return []
                                case .single: return .allCorners
                                }
                            }()

                            RoundedCorners(radius: 8, corners: corners)
                                .fill(Color.red.opacity(isPredicted ? 0.35 : 1.0))
                                .frame(width: dayWidth, height: 26)
                                .position(
                                    x: day.xPosition + dayWidth / 2,
                                    y: day.yPosition + calculator.weekHeight / 2
                                )
                        }
                    }
                }

                // MARK: - Layer 2: Fertile / Ovulation lines
                ForEach(month.visibleDays.indices, id: \.self) { dayIndex in
                    let day = month.visibleDays[dayIndex]
                    let dayScreenY = day.yPosition + scrollOffset
                    if dayScreenY > -dayVisibilityBuffer && dayScreenY < height + dayVisibilityBuffer {
                        if let daystamp = day.daystamp,
                           let displayState = dayDisplayStates[daystamp],
                           let fertilePhase = displayState.fertilePhase {

                            let lineColor: Color = {
                                switch fertilePhase {
                                case .fertile:       return Color(red: 0.55, green: 0.40, blue: 0.85)
                                case .ovulation(_):  return Color(red: 1.0, green: 0.65, blue: 0.0)
                                }
                            }()

                            let lineY = day.yPosition + calculator.weekHeight - 4

                            Path { path in
                                path.move(to: CGPoint(x: day.xPosition, y: lineY))
                                path.addLine(to: CGPoint(x: day.xPosition + dayWidth, y: lineY))
                            }
                            .stroke(lineColor, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        }
                    }
                }

                // MARK: - Layer 3: Day cells
                ForEach(month.visibleDays.indices, id: \.self) { dayIndex in
                    let day = month.visibleDays[dayIndex]

                    let dayScreenY = day.yPosition + scrollOffset
                    if dayScreenY > -dayVisibilityBuffer && dayScreenY < height + dayVisibilityBuffer {
                        let today = calendar.startOfDay(for: currentDate)
                        let dayDate = day.date != nil ? calendar.startOfDay(for: day.date!) : nil
                        let isFutureDay = dayDate != nil && dayDate! > today

                        let isSelected: Bool = {
                            guard let selected = selectedDayStamp, let daystamp = day.daystamp else {
                                return false
                            }
                            return daystamp == selected
                        }()

                        let displayState = day.daystamp.flatMap { dayDisplayStates[$0] }

                        let isInPeriod: Bool = {
                            guard let ds = displayState, case .period = ds.cyclePhase else { return false }
                            return true
                        }()

                        ZStack {
                            // Today indicator
                            if day.isToday {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)
                            }

                            // Selected indicator
                            if isSelected {
                                Circle()
                                    .fill(Color("SelectedDayColor"))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color(UIColor.systemBackground), lineWidth: 2)
                                    )
                            }

                            // Day number
                            Text(day.dayNumber)
                                .font(.system(size: 16, weight: day.isToday ? .bold : .medium))
                                .foregroundColor(
                                    isSelected ? Color(UIColor.systemBackground) :
                                    day.isToday ? .white :
                                    isInPeriod ? .white :
                                    isFutureDay ? Color(UIColor.tertiaryLabel) :
                                    .primary
                                )

                            // Tag dots + comment dot
                            if let ds = displayState,
                               (!ds.tagCategories.isEmpty || ds.hasComment) {
                                let dotSize: CGFloat = 6
                                let dotSpacing: CGFloat = 3

                                let tagColors: [Color] = ds.tagCategories.sorted().map { Color.tagColor(for: $0) }

                                let allDots: [Color] = ds.hasComment
                                    ? tagColors + [Color(UIColor.tertiaryLabel)]
                                    : tagColors

                                HStack(spacing: dotSpacing) {
                                    ForEach(allDots.indices, id: \.self) { i in
                                        Circle()
                                            .fill(allDots[i])
                                            .frame(width: dotSize, height: dotSize)
                                    }
                                }
                                .offset(y: 14)
                            }
                        }
                        .position(
                            x: day.xPosition + dayWidth / 2,
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
