//
//  CycleRecord+Queries.swift
//  RedCalendar-Female
//

// MARK: - CycleDayContext

/// All cycle lookups for a single day, resolved together so callers run the
/// queries once per render instead of re-running them per property.
struct CycleDayContext {
    let owning: CycleRecord?
    let ongoing: CycleRecord?
    let completed: CycleRecord?
}

// MARK: - Cycle Queries

// Shared cycle domain queries. Middleware, reducers and views must use these
// helpers instead of re-implementing the search logic, so that validation and
// display never disagree.
//
// Invariant: `CalendarState.cycles` is sorted by `startDay` ascending — the
// reducer sorts once in `.setCycles`. The backward scans below rely on that
// order to return the latest match in a single early-exiting pass.
extension Array where Element == CycleRecord {

    /// Last cycle that starts on or before the given day — the cycle the day belongs to.
    func owningCycle(for day: Int) -> CycleRecord? {
        last { $0.startDay <= day }
    }

    /// Most recent period that was started but not finished yet (`periodLength == 0`).
    func ongoingCycle(atOrBefore day: Int) -> CycleRecord? {
        last { $0.startDay <= day && ($0.periodLength ?? -1) == 0 }
    }

    /// Cycle whose completed period covers the given day.
    func completedCycle(covering day: Int) -> CycleRecord? {
        last { cycle in
            guard let periodLength = cycle.periodLength, periodLength > 0 else { return false }
            return cycle.startDay <= day && day <= cycle.startDay + periodLength - 1
        }
    }

    /// A period may start only if no other cycle starts closer than the minimum cycle length.
    func canStartPeriod(at day: Int) -> Bool {
        !contains { abs($0.startDay - day) < Constants.Cycle.minCycleLength }
    }

    /// Start of the predicted (extrapolated) cycle the day falls into, or nil while the day
    /// is still within the first cycle after the last real start on or before it.
    func predictedCycleStart(for day: Int, defaultLength: Int) -> Int? {
        owningCycle(for: day)?.predictedCycleStart(for: day, defaultLength: defaultLength)
    }

    func dayContext(for day: Int) -> CycleDayContext {
        CycleDayContext(
            owning: owningCycle(for: day),
            ongoing: ongoingCycle(atOrBefore: day),
            completed: completedCycle(covering: day)
        )
    }
}

// MARK: - CycleRecord Helpers

extension CycleRecord {
    func flowLevel(on day: Daystamp) -> Int? {
        flowLevels[String(day.rawValue)]
    }

    mutating func setFlowLevel(_ level: Int?, on day: Daystamp) {
        if let level = level {
            flowLevels[String(day.rawValue)] = level
        } else {
            flowLevels.removeValue(forKey: String(day.rawValue))
        }
    }

    /// Start of the predicted cycle the day falls into, extrapolated from this cycle's
    /// start, or nil while the day is still within the first extrapolated cycle.
    func predictedCycleStart(for day: Int, defaultLength: Int) -> Int? {
        let cyclesPassed = (day - startDay) / defaultLength
        guard cyclesPassed >= 1 else { return nil }
        return startDay + cyclesPassed * defaultLength
    }
}
