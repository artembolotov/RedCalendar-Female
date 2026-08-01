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
    @Binding var cardHeight: DayCardHeight
    @Binding var floatingButtonState: FloatingButtonState
    @Binding var scrollCommand: ScrollCommand
    
    // MARK: - State: Core Calendar
    @State private var calculator: MonthCalculator?
    @State private var calendar = Calendar.current
    @State private var localizedWeekdays: [String] = []
    @State private var weekendIndices: Set<Int> = []
    
    // MARK: - State: Dimensions
    // The full screen, not the space under the bar: the grid is drawn edge to edge and
    // scrolls beneath `CalendarTopChrome`.
    @State private var calendarHeight: CGFloat = 0
    @State private var calendarWidth: CGFloat = 0
    @State private var globalTopOffset: CGFloat = 0
    // Kept so the top inset, which lands on a pass of its own, can rebuild the calculator
    // without waiting for the size to change again.
    @State private var screenSize: CGSize = .zero
    
    // MARK: - State: Scroll & Offsets
    @State private var scrollOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var lastDispatchedCenter: Daystamp?

    // MARK: - State: Viewport
    // Rebuilt in steps rather than per frame — see updateViewportTracking().
    @State private var viewport: ViewportData = .empty
    @State private var viewportAnchor: CGFloat = 0
    
    // MARK: - State: Offset Components
    @State private var todayWeekCenterY: CGFloat = 0
    @State private var uiOffset: CGFloat = 0
    @State private var selectionOffset: CGFloat = 0

    // MARK: - State: Card Height
    // A selection re-centres the day in the space above the card, so the flight cannot start
    // until the card's height for that day is known — see `awaitingHeightFor`. The last height
    // seen is kept only for the fallback below, and for the very first opening of a session.
    @State private var assumedCardHeight: CGFloat = CalendarConstants.assumedCardHeight
    @State private var commandBottomOffset: CGFloat = 0
    @State private var awaitingHeightFor: Daystamp?
    @State private var heightWaitTask: Task<Void, Never>?

    // MARK: - Computed Properties

    private var currentDate: Date {
        store.state.calendarState.todayDayStamp.toDate(calendar: calendar)
    }

    /// Everything the grid runs underneath at the top of the screen — the navigation bar and
    /// the weekday strip. The calendar's own coordinate space starts at the top of the screen
    /// now, so this is the offset at which the area a user can actually read begins.
    private var chromeHeight: CGFloat {
        globalTopOffset + CalendarConstants.weekdaysHeaderHeight
    }

    /// The height left under the bar. Both the centring and the floating button's thresholds
    /// are measured against this, never against the full screen — half the screen is a point
    /// behind the navigation bar.
    private var visibleCalendarHeight: CGFloat {
        max(0, calendarHeight - chromeHeight)
    }

    /// The height of the card for the day currently selected — the panel the calendar has to
    /// centre above. Falls back to the last height seen only while the card for that day has
    /// not reported yet, which is a window nothing normally scrolls in.
    private var pendingBottomOffset: CGFloat {
        guard let selected = store.state.calendarState.selectedDayStamp else { return 0 }

        if cardHeight.day == selected, cardHeight.height > 0 { return cardHeight.height }
        return assumedCardHeight
    }

    /// Adjusts calendar position when DayDetailsView is shown
    /// Returns offset to center selected date within visible area above the panel
    ///
    /// The card eats the bottom of the visible area, so its centre rises by exactly half the
    /// card — the top of that area (`chromeHeight`) has not moved, and it is already baked
    /// into `uiOffset`.
    private var selectionUIOffset: CGFloat {
        pendingBottomOffset / 2
    }

    /// Main offset that determines calendar scroll position
    /// - When DayDetails closed: centers on today's week
    /// - When DayDetails open: centers on selected date with panel adjustment
    private var effectiveOffset: CGFloat {
        let baseOffset = uiOffset - todayWeekCenterY
        return pendingBottomOffset > 0 ? baseOffset - selectionOffset - selectionUIOffset : baseOffset
    }
    
    // MARK: - Constants
    private let viewportUpdateThreshold: CGFloat = CalendarConstants.viewportUpdateThreshold
    private let monthHeaderHeight: CGFloat = CalendarConstants.monthHeaderHeight
    // How long a selection waits for its card's height before leaving on the last one seen.
    // A measurement takes a frame or two; this is the guard against a card that never reports,
    // not the path a selection normally takes.
    private let cardHeightWaitLimit: TimeInterval = 0.05

    init(
        cardHeight: Binding<DayCardHeight> = .constant(.none),
        floatingButtonState: Binding<FloatingButtonState>,
        scrollCommand: Binding<ScrollCommand>
    ) {
        self._cardHeight = cardHeight
        self._floatingButtonState = floatingButtonState
        self._scrollCommand = scrollCommand
    }
    
    var body: some View {
        GeometryReader { geometry in
            
            let currentGlobalTopOffset = geometry.safeAreaInsets.top
            
            // The grid fills the screen and passes under the bar; the bar is laid over it
            // rather than stacked above it, which is the whole point — a month title sliding
            // into a blur reads as depth, and a month title stopping at a divider does not.
            ZStack(alignment: .top) {
                ZStack {
                    if let calc = calculator {
                        InfiniteScrollContainer(
                            scrollOffset: $scrollOffset,
                            scrollCommand: scrollCommand,
                            onScrollChanged: { newOffset in
                                // Read the calculator from state, not from the captured `calc`:
                                // the container keeps the first callback it was given.
                                if let current = calculator {
                                    updateViewportTracking(for: newOffset, calculator: current)
                                }
                                updateFloatingButtonState(scrollOffset: newOffset)
                            },
                            onDragStateChanged: { dragging in
                                self.isDragging = dragging
                            },
                            onDayTapped: { dayStamp in
                                let current = store.state.calendarState.selectedDayStamp
                                store.send(.setSelectedDayStamp(current == dayStamp ? nil : dayStamp))
                            },
                            onEmptyAreaTapped: { dismissDayDetails() },
                            initialCenterOffset: effectiveOffset,
                            calculator: calc,
                            today: store.state.calendarState.todayDayStamp
                        )

                        CalendarGridView(
                            viewport: viewport,
                            anchorOffset: viewportAnchor,
                            calculator: calc,
                            dayDisplayStates: store.state.calendarState.dayDisplayStates,
                            selectedDayStamp: store.state.calendarState.selectedDayStamp,
                            today: store.state.calendarState.todayDayStamp,
                            width: calendarWidth,
                            height: calendarHeight,
                            theme: store.state.accentTheme
                        )
                        .equatable()
                        .offset(y: scrollOffset)
                        .clipped()
                        .allowsHitTesting(false)
                    }
                }

                CalendarTopChrome(
                    weekdays: localizedWeekdays,
                    weekendIndices: weekendIndices,
                    width: calendarWidth,
                    topInset: globalTopOffset,
                    onTap: dismissDayDetails
                )
            }
            // The band is pinned to the top of the screen, not to the top of whatever the grid
            // happens to size to — which is nothing at all on the frame before the calculator
            // exists.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onChange(of: geometry.size) { newSize in
                screenSize = newSize
                globalTopOffset = currentGlobalTopOffset
                setupCalculator(height: newSize.height, width: newSize.width)
            }
            // The inset arrives on its own pass, and the week height is derived from the
            // space left under the bar — so this rebuilds the calculator rather than merely
            // recomputing the offsets, or the first layout would size every week against a
            // navigation bar it did not know about yet.
            .onChange(of: currentGlobalTopOffset) { newOffset in
                globalTopOffset = newOffset

                guard screenSize.height > 0, screenSize.width > 0 else {
                    uiOffset = calculateUIOffset()
                    return
                }

                setupCalculator(height: screenSize.height, width: screenSize.width)
            }
            // Ahead of the height handler below: when a selection and a height land in the
            // same pass, the selection is what decides whether the height is the one being
            // waited for.
            .onChange(of: store.state.calendarState.selectedDayStamp) { newValue in
                guard let calc = calculator else { return }
                handleDaySelection(newValue, calculator: calc)
            }
            .onChange(of: cardHeight) { newValue in
                handleCardHeight(newValue)
            }
            .onChange(of: store.state.calendarState.todayDayStamp) { _ in
                updateCalculatorIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                updateCalendarAndCalculatorIfNeeded()
            }
            // A day rollover or a time zone change only updates `todayDayStamp` in the store;
            // the calendar this view draws with is a snapshot and has to be re-read too.
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                updateCalendarAndCalculatorIfNeeded()
            }
            .onDisappear {
                cancelHeightWait()
            }
        }
    }
    
    // MARK: - Dismiss Handler

    // Guarded rather than dispatched blindly: the store drops the duplicate state either way,
    // but every tap on empty space would still be logged and reported as an action.
    private func dismissDayDetails() {
        guard store.state.calendarState.selectedDayStamp != nil else { return }
        store.send(.setSelectedDayStamp(nil))
    }

    // MARK: - Day Selection Handler
    private func handleDaySelection(_ selectedDayStamp: Daystamp?, calculator: MonthCalculator) {
        cancelHeightWait()

        guard let selectedDayStamp = selectedDayStamp else {
            selectionOffset = 0
            updateFloatingButtonState(scrollOffset: scrollOffset)
            return
        }

        selectionOffset = calculateSelectionOffset(for: selectedDayStamp, calculator: calculator)

        // The target is the day's row plus half the card's height, so a card of the wrong
        // height aims the flight somewhere the calendar then has to come back from. The card
        // reports its height a frame or two after the selection; waiting for it costs less
        // than the correction does, and a card that keeps its level across the day change
        // reports on the same frame, so a swipe waits for nothing at all.
        if cardHeight.day == selectedDayStamp, cardHeight.height > 0 {
            launchRecentring(against: pendingBottomOffset)
        } else {
            awaitingHeightFor = selectedDayStamp
            startHeightWait(for: selectedDayStamp)
        }
    }

    // MARK: - Card Height Handler

    private func handleCardHeight(_ newValue: DayCardHeight) {
        guard newValue.height > 0,
              let day = newValue.day,
              day == store.state.calendarState.selectedDayStamp else { return }

        assumedCardHeight = newValue.height

        if awaitingHeightFor == day {
            cancelHeightWait()
            launchRecentring(against: newValue.height)
            return
        }

        // The card can still change height after the flight has left — a swiped card taking
        // its own height once it has stood still, or a day growing a comment or a tag. That
        // moves the visible area, so the centring follows it.
        guard abs(newValue.height - commandBottomOffset) > CalendarConstants.cardHeightTolerance else { return }
        launchRecentring(against: newValue.height)
    }

    /// Sends the calendar to the day currently selected. The target itself is read off
    /// `effectiveOffset` by the render pass that reaches `updateUIView`; the height the flight
    /// was aimed with is recorded here, so a card that changes size afterwards can be judged
    /// worth a correction.
    private func launchRecentring(against panelHeight: CGFloat) {
        commandBottomOffset = panelHeight
        scrollCommand.request()
    }

    /// Leaves anyway if the card never reports. A selection always re-centres — a day left
    /// sitting under the card would be a worse failure than a target that is slightly off.
    private func startHeightWait(for day: Daystamp) {
        heightWaitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(cardHeightWaitLimit * 1_000_000_000))
            guard !Task.isCancelled, awaitingHeightFor == day else { return }

            awaitingHeightFor = nil
            heightWaitTask = nil
            launchRecentring(against: pendingBottomOffset)
        }
    }

    private func cancelHeightWait() {
        awaitingHeightFor = nil
        guard let task = heightWaitTask else { return }
        task.cancel()
        heightWaitTask = nil
    }

    // MARK: - Week Center Y Calculation (renamed from calculateWeekCenterY)
    private func weekCenterY(for daystamp: Daystamp, calculator: MonthCalculator) -> CGFloat {
        let targetDate = daystamp.toDate(calendar: calendar)

        guard let targetMonthStart = calendar.dateInterval(of: .month, for: targetDate)?.start,
              let currentMonthStart = calendar.dateInterval(of: .month, for: currentDate)?.start else {
            return 0
        }

        let monthOffset = calendar.dateComponents([.month], from: currentMonthStart, to: targetMonthStart).month ?? 0

        let monthY = calculator.getYPosition(for: monthOffset)
        let weekHeight = calculator.weekHeight

        var weekIndex = 0
        for (index, cell) in calculator.getMonthCells(for: monthOffset).enumerated() {
            if cell?.daystamp == daystamp {
                weekIndex = index / 7
                break
            }
        }

        let gridStartY = monthY + monthHeaderHeight
        let weekY = gridStartY + CGFloat(weekIndex) * (weekHeight + CalendarConstants.gridVerticalSpacing)
        return weekY + weekHeight / 2
    }
    
    // MARK: - NEW: Calculate UI Offset

    /// Where today's week centre has to land on screen.
    ///
    /// The grid's coordinate space starts at the top of the screen now, so this is a screen
    /// position directly: the middle of what is left under the bar, not the middle of the
    /// screen — half of which is behind the navigation bar.
    private func calculateUIOffset() -> CGFloat {
        chromeHeight + visibleCalendarHeight / 2
    }
    
    // MARK: - NEW: Calculate Selection Offset
    private func calculateSelectionOffset(for selectedDayStamp: Daystamp, calculator: MonthCalculator) -> CGFloat {
        return weekCenterY(for: selectedDayStamp, calculator: calculator) - todayWeekCenterY
    }

    // MARK: - Recalculate Offsets Helper
    private func recalculateOffsets(calculator: MonthCalculator) {
        todayWeekCenterY = weekCenterY(for: store.state.calendarState.todayDayStamp, calculator: calculator)
        uiOffset = calculateUIOffset()

        if let selectedDayStamp = store.state.calendarState.selectedDayStamp {
            selectionOffset = calculateSelectionOffset(for: selectedDayStamp, calculator: calculator)
        } else {
            selectionOffset = 0
        }
    }
    
    private func updateCalendarAndCalculatorIfNeeded() {
        // Compared whole rather than field by field: the time zone matters as much as the
        // locale and the first weekday, and a stale zone leaves the grid measuring days in
        // one zone while the store computes today in another.
        let newCalendar = Calendar.current

        if newCalendar != calendar {
            calendar = newCalendar
        }

        updateCalculatorIfNeeded()
    }
    
    private func setupCalculator(height: CGFloat, width: CGFloat) {
        self.calendarHeight = height
        self.calendarWidth = width
        
        guard height > 0 && width > 0 else { return }

        // Sized against the readable area, not the drawing area. The grid is drawn across the
        // whole screen now, and handing that height to the calculator would quietly make every
        // week taller — a week is measured against what a user can see, not against the strip
        // of screen behind the navigation bar.
        let newCalculator = MonthCalculator(
            currentDate: currentDate,
            screenHeight: visibleCalendarHeight,
            calendar: calendar
        )

        localizedWeekdays = newCalculator.getLocalizedWeekdays()
        weekendIndices = newCalculator.getWeekendIndices()

        calculator = newCalculator
        
        // Calculate all offset components
        recalculateOffsets(calculator: newCalculator)

        scrollOffset = effectiveOffset

        rebuildViewport(for: scrollOffset, calculator: newCalculator)
        updateFloatingButtonState(scrollOffset: scrollOffset)
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
            let newCalculator = MonthCalculator(currentDate: currentDate, screenHeight: visibleCalendarHeight, calendar: calendar)
            localizedWeekdays = newCalculator.getLocalizedWeekdays()
            weekendIndices = newCalculator.getWeekendIndices()

            calculator = newCalculator

            scrollOffset -= originShift(from: currentCalculator, to: newCalculator)

            // Recalculate all offsets when calculator changes
            recalculateOffsets(calculator: newCalculator)

            rebuildViewport(for: scrollOffset, calculator: newCalculator)
            updateFloatingButtonState(scrollOffset: scrollOffset)
        }
    }

    /// How far the content moved when the calculator was replaced.
    ///
    /// Every Y position is measured from the top of the month holding the calculator's
    /// `currentDate`, so a today that crossed into a new month re-origins the whole
    /// coordinate space. Without cancelling that out of `scrollOffset`, the day the user
    /// was looking at slides a month's height away at midnight on the 1st.
    private func originShift(from old: MonthCalculator, to new: MonthCalculator) -> CGFloat {
        guard let oldMonthStart = calendar.dateInterval(of: .month, for: old.currentDate)?.start,
              let newMonthStart = calendar.dateInterval(of: .month, for: new.currentDate)?.start,
              let monthOffset = calendar.dateComponents([.month], from: newMonthStart, to: oldMonthStart).month
        else {
            return 0
        }

        return new.getYPosition(for: monthOffset)
    }
    
    private func updateFloatingButtonState(scrollOffset: CGFloat) {
        // The button is only mounted while nothing is selected, and the state lives in
        // HomeView — writing it under an open card would rebuild the card and the calendar
        // on every frame of a scroll nobody can see the button during. The closing path
        // recomputes it from handleDaySelection(nil,…), by which point this guard passes.
        guard store.state.calendarState.selectedDayStamp == nil else { return }

        // The panel is closed (or closing), so compare against today's base position
        // directly — effectiveOffset still includes the panel adjustment for one render
        // cycle after selectedDayStamp becomes nil.
        let reference = uiOffset - todayWeekCenterY
        let deviation = scrollOffset - reference

        // `uiOffset` is the centre of the readable area, so today leaves that area at exactly
        // half its height in either direction — symmetric, where the old thresholds were
        // measured off a grid that started below the strip rather than at the top of the screen.
        let threshold = visibleCalendarHeight / 2

        let newState: FloatingButtonState = {
            if deviation > threshold {
                return .arrowDown
            } else if deviation < -threshold {
                return .arrowUp
            } else {
                return .plus
            }
        }()
        
        if newState != floatingButtonState {
            floatingButtonState = newState
        }
    }
    
    // Rebuilding the viewport walks every month and day around the screen, so it happens
    // in steps: the layer is drawn once for an anchor offset and then simply slid by
    // `.offset` until the scroll moves far enough to justify a new one.
    private func rebuildViewport(for offset: CGFloat, calculator: MonthCalculator) {
        guard calendarHeight > 0, calendarWidth > 0 else { return }

        viewportAnchor = offset
        viewport = ViewportCalculator.calculateDynamicViewport(
            scrollOffset: offset,
            screenHeight: calendarHeight,
            screenWidth: calendarWidth,
            calculator: calculator,
            today: store.state.calendarState.todayDayStamp
        )
    }

    private func updateViewportTracking(for offset: CGFloat, calculator: MonthCalculator) {
        let baseThreshold = viewportUpdateThreshold
        let adaptiveThreshold = isDragging ? baseThreshold * 0.5 : baseThreshold

        guard abs(offset - viewportAnchor) > adaptiveThreshold else { return }

        rebuildViewport(for: offset, calculator: calculator)
        dispatchScrollCenterIfNeeded(scrollOffset: offset, calculator: calculator)
    }

    // Lets DatabaseMiddleware re-center the loaded range (DB observations + display)
    // when the user scrolls near its edge. Dispatched only when the viewport center
    // moved far enough since the last dispatch, so scrolling doesn't spam the store.
    private func dispatchScrollCenterIfNeeded(scrollOffset: CGFloat, calculator: MonthCalculator) {
        let center = centerDaystamp(scrollOffset: scrollOffset, calculator: calculator)
        if let last = lastDispatchedCenter,
           abs(center.rawValue - last.rawValue) < Constants.Calendar.centerReportStep {
            return
        }

        lastDispatchedCenter = center
        store.send(.calendarScrolledTo(center: center))
    }

    private func centerDaystamp(scrollOffset: CGFloat, calculator: MonthCalculator) -> Daystamp {
        // Content-space Y at the vertical screen center (days render at yPosition + scrollOffset)
        let centerY = calendarHeight / 2 - scrollOffset

        var offset = Int(centerY / CalendarConstants.averageMonthHeight)
        offset = min(max(offset, CalendarConstants.minMonthOffset), CalendarConstants.maxMonthOffset)

        while offset > CalendarConstants.minMonthOffset && calculator.getYPosition(for: offset) > centerY {
            offset -= 1
        }
        while offset < CalendarConstants.maxMonthOffset && calculator.getYPosition(for: offset + 1) <= centerY {
            offset += 1
        }

        // Month precision is enough for range management — take the month's middle.
        let monthDate = calculator.getMonthDate(for: offset)
        return Daystamp(from: monthDate, calendar: calendar)
    }
}

#Preview {
    CalendarView(
        floatingButtonState: .constant(.plus),
        scrollCommand: .constant(.none)
    )
}
