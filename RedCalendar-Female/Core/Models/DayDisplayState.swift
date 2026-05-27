//
//  DayDisplayState.swift
//  RedCalendar-Female
//

// MARK: - DayDisplayState

struct DayDisplayState {
    var cyclePhase: CyclePhase
    var fertilePhase: FertilePhase?
    var hasComment: Bool
    var tagCategories: Set<Int>
}

// MARK: - CyclePhase

enum CyclePhase: Equatable {
    case none
    case period(position: PeriodPosition, isPredicted: Bool)
}

// MARK: - FertilePhase

enum FertilePhase: Equatable {
    case fertile
    case ovulation(confirmed: Bool)
}

// MARK: - PeriodPosition

enum PeriodPosition: Equatable {
    case start
    case middle
    case end
    case single
}
