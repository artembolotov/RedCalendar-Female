//
//  CycleRecord+Queries.swift
//  RedCalendar-Female
//

// Shared cycle domain queries. Middleware, reducers and views must use these
// helpers instead of re-implementing the search logic, so that validation and
// display never disagree.
extension Array where Element == CycleRecord {

    /// Last cycle that starts on or before the given day — the cycle the day belongs to.
    func owningCycle(for day: Int) -> CycleRecord? {
        filter { $0.startDay <= day }
            .max { $0.startDay < $1.startDay }
    }

    /// Most recent period that was started but not finished yet (`periodLength == 0`).
    func ongoingCycle(atOrBefore day: Int) -> CycleRecord? {
        filter { $0.startDay <= day && ($0.periodLength ?? -1) == 0 }
            .max { $0.startDay < $1.startDay }
    }

    /// Cycle whose completed period covers the given day.
    func completedCycle(covering day: Int) -> CycleRecord? {
        filter { cycle in
            guard let periodLength = cycle.periodLength, periodLength > 0 else { return false }
            return cycle.startDay <= day && day <= cycle.startDay + periodLength - 1
        }
        .max { $0.startDay < $1.startDay }
    }

    /// A period may start only if no other cycle starts closer than the minimum cycle length.
    func canStartPeriod(at day: Int) -> Bool {
        !contains { abs($0.startDay - day) < Constants.Cycle.minCycleLength }
    }

    /// Start of the predicted (extrapolated) cycle the day falls into, or nil while the day
    /// is still within the first cycle after the last real start on or before it.
    func predictedCycleStart(for day: Int, defaultLength: Int) -> Int? {
        guard let lastReal = owningCycle(for: day) else { return nil }
        let cyclesPassed = (day - lastReal.startDay) / defaultLength
        guard cyclesPassed >= 1 else { return nil }
        return lastReal.startDay + cyclesPassed * defaultLength
    }
}

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
}
