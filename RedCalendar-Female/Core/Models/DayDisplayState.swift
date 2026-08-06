//
//  DayDisplayState.swift
//  RedCalendar-Female
//

// MARK: - DayDisplayState

struct DayDisplayState: Equatable {
    var cyclePhase: CyclePhase
    var fertileWindow: FertileWindow?
    var hasComment: Bool
    var tagCategories: Set<Int>

    static let empty = DayDisplayState(
        cyclePhase: .none,
        fertileWindow: nil,
        hasComment: false,
        tagCategories: []
    )
}

// MARK: - CyclePhase

enum CyclePhase: Equatable {
    case none
    case period(position: SegmentPosition, isPredicted: Bool)
}

// MARK: - FertileWindow

struct FertileWindow: Equatable {
    var phase: FertilePhase
    var position: SegmentPosition
}

// MARK: - FertilePhase

enum FertilePhase: Equatable {
    case fertile
    case ovulation(confirmed: Bool)
}

// MARK: - SegmentPosition

// Where a day sits inside a run of days drawn as one bar — the period bar and the fertile
// window band both cap their ends with it.
enum SegmentPosition: Equatable {
    case start
    case middle
    case end
    case single
}
