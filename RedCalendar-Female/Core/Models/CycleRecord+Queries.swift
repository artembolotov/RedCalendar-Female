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

    /// Cycle whose recorded period covers the day, open or closed — the one that owns the
    /// day's period data. See `recordedPeriodCycle(covering:)`.
    var recorded: CycleRecord? { ongoing ?? completed }
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

    /// Period that was started but not finished yet (`periodLength == 0`) and that still
    /// covers the given day — the day's owning cycle, no further from its start than the
    /// maximum period length.
    ///
    /// The window matters: an open period the user never closed must not capture days far
    /// beyond it, otherwise those days offer "end period" forever and the next cycle can
    /// never be started.
    func ongoingCycle(covering day: Int) -> CycleRecord? {
        guard let cycle = owningCycle(for: day),
              (cycle.periodLength ?? -1) == 0,
              day - cycle.startDay + 1 <= Constants.Cycle.maxPeriodLength else { return nil }
        return cycle
    }

    /// Cycle whose completed period covers the given day.
    func completedCycle(covering day: Int) -> CycleRecord? {
        last { cycle in
            guard let periodLength = cycle.periodLength, periodLength > 0 else { return false }
            return cycle.startDay <= day && day <= cycle.startDay + periodLength - 1
        }
    }

    /// A period may start only on a day that has already come, and only if no other cycle
    /// starts closer than the minimum cycle length.
    func canStartPeriod(at day: Int, today: Int) -> Bool {
        guard day <= today else { return false }
        return !contains { abs($0.startDay - day) < Constants.Cycle.minCycleLength }
    }

    /// Cycle whose recorded period covers the day, open or closed — the cycle a day's period
    /// data (end day, flow level) belongs to.
    ///
    /// Not the same as `owningCycle(for:)`, which also matches days long after the period
    /// ended and days inside a merely predicted cycle. Period data written against the
    /// owning cycle would land on whichever real cycle came last, not on the day's own.
    func recordedPeriodCycle(covering day: Int) -> CycleRecord? {
        ongoingCycle(covering: day) ?? completedCycle(covering: day)
    }

    /// A period may end only on a day that has already come and that belongs to a period
    /// which is still open or long enough to be shortened to that day.
    func canEndPeriod(at day: Int, today: Int) -> Bool {
        guard day <= today else { return false }
        return recordedPeriodCycle(covering: day) != nil
    }

    /// Flow level may be set only on a recorded period day that has already come — a
    /// predicted day has no flow to report yet and no cycle of its own to store it on.
    func canSetFlowLevel(at day: Int, today: Int) -> Bool {
        guard day <= today else { return false }
        return recordedPeriodCycle(covering: day) != nil
    }

    /// Start of the predicted (extrapolated) cycle the day falls into, or nil while the day
    /// is still within the first cycle after the last real start on or before it.
    func predictedCycleStart(for day: Int, defaultLength: Int) -> Int? {
        owningCycle(for: day)?.predictedCycleStart(for: day, defaultLength: defaultLength)
    }

    func dayContext(for day: Int) -> CycleDayContext {
        CycleDayContext(
            owning: owningCycle(for: day),
            ongoing: ongoingCycle(covering: day),
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

    /// Last day of this cycle the user reported flow for — how far the period is known to
    /// have actually run. Nil when no flow is logged inside the period window.
    ///
    /// Only days from the start up to `maxPeriodLength`, and not past `today`, count. Flow
    /// levels used to be written against the day's *owning* cycle, so a record can carry
    /// keys far outside its own period; without the window one of those would stretch the
    /// period across the whole calendar.
    func lastFlowDay(notAfter today: Int) -> Int? {
        let windowEnd = min(today, startDay + Constants.Cycle.maxPeriodLength - 1)
        guard startDay <= windowEnd else { return nil }
        return flowLevels.keys
            .compactMap { Int($0) }
            .filter { $0 >= startDay && $0 <= windowEnd }
            .max()
    }

    /// Start of the predicted cycle the day falls into, extrapolated from this cycle's
    /// start, or nil while the day is still within the first extrapolated cycle.
    func predictedCycleStart(for day: Int, defaultLength: Int) -> Int? {
        let cyclesPassed = (day - startDay) / defaultLength
        guard cyclesPassed >= 1 else { return nil }
        return startDay + cyclesPassed * defaultLength
    }
}
