//
//  CycleRecord+Queries.swift
//  RedCalendar-Female
//

// MARK: - PeriodCoverage

/// How a cycle's recorded period relates to a day: not covering it at all, covering it
/// with a period that is still open, or with one the user already ended.
///
/// The "not covered" case is deliberately not called `none` — `?? .none` on an optional
/// `PeriodCoverage` would then be ambiguous with `Optional.none`.
enum PeriodCoverage: Equatable {
    case outside
    case ongoing
    case completed
}

// MARK: - CycleDayContext

/// All cycle lookups for a single day, resolved together so callers run the
/// queries once per render instead of re-running them per property.
struct CycleDayContext {
    let day: Daystamp
    let owning: CycleRecord?

    /// Next recorded cycle after `owning` — nil means `owning` is the latest one and the
    /// real length of the day's cycle is still unknown.
    let following: CycleRecord?
    let ongoing: CycleRecord?
    let completed: CycleRecord?

    /// Cycle whose recorded period covers the day, open or closed — the one that owns the
    /// day's period data. See `recordedPeriodCycle(covering:)`.
    var recorded: CycleRecord? { ongoing ?? completed }

    /// Start of the predicted (extrapolated) cycle the day falls into.
    ///
    /// Nil once the next cycle is recorded: the cycle's length is then a known fact — the
    /// distance to that start — and extrapolating the default length would contradict it.
    func predictedCycleStart(cycleLength: Int) -> Daystamp? {
        guard following == nil else { return nil }
        return owning?.predictedCycleStart(for: day, cycleLength: cycleLength)
    }

    /// See `canEndPeriod(at:today:)` — answered from the already-resolved context.
    func canEndPeriod(today: Daystamp) -> Bool {
        day <= today && recorded != nil
    }

    /// See `canSetFlowLevel(at:today:)` — answered from the already-resolved context.
    func canSetFlowLevel(today: Daystamp) -> Bool {
        day <= today && recorded != nil
    }
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
    func owningCycle(for day: Daystamp) -> CycleRecord? {
        last { $0.startDay <= day }
    }

    /// Period that was started but not finished yet (`periodLength == 0`) and that still
    /// covers the given day.
    func ongoingCycle(covering day: Daystamp) -> CycleRecord? {
        coveringCycle(day) { $0 == .ongoing }
    }

    /// Cycle whose completed period covers the given day.
    func completedCycle(covering day: Daystamp) -> CycleRecord? {
        coveringCycle(day) { $0 == .completed }
    }

    /// Cycle whose recorded period covers the day, open or closed — the cycle a day's period
    /// data (end day, flow level) belongs to.
    ///
    /// Not the same as `owningCycle(for:)`, which also matches days long after the period
    /// ended and days inside a merely predicted cycle. Period data written against the
    /// owning cycle would land on whichever real cycle came last, not on the day's own.
    func recordedPeriodCycle(covering day: Daystamp) -> CycleRecord? {
        coveringCycle(day) { $0 != .outside }
    }

    /// A period may start only on a day that has already come, and only if no other cycle
    /// starts closer than the minimum cycle length.
    func canStartPeriod(at day: Daystamp, today: Daystamp) -> Bool {
        guard day <= today else { return false }

        // Sorted ascending, so scanning backward walks cycles away from `day` into the
        // past: the first one that is already too far behind ends the search.
        for cycle in reversed() {
            let distance = day - cycle.startDay
            if distance >= Constants.Cycle.minCycleLength { break }
            if abs(distance) < Constants.Cycle.minCycleLength { return false }
        }
        return true
    }

    /// A period may end only on a day that has already come and that belongs to a period
    /// which is still open or long enough to be shortened to that day.
    func canEndPeriod(at day: Daystamp, today: Daystamp) -> Bool {
        day <= today && recordedPeriodCycle(covering: day) != nil
    }

    /// Flow level may be set only on a recorded period day that has already come — a
    /// predicted day has no flow to report yet and no cycle of its own to store it on.
    func canSetFlowLevel(at day: Daystamp, today: Daystamp) -> Bool {
        day <= today && recordedPeriodCycle(covering: day) != nil
    }

    /// Start of the predicted (extrapolated) cycle the day falls into, or nil while the day
    /// is still within the first cycle after the last real start on or before it — and nil
    /// as well once the next cycle is recorded. See `CycleDayContext.predictedCycleStart`.
    func predictedCycleStart(for day: Daystamp, cycleLength: Int) -> Daystamp? {
        dayContext(for: day).predictedCycleStart(cycleLength: cycleLength)
    }

    func dayContext(for day: Daystamp) -> CycleDayContext {
        let owningIndex = lastIndex { $0.startDay <= day }
        let owning = owningIndex.map { self[$0] }
        let following = owningIndex.flatMap { index -> CycleRecord? in
            index + 1 < count ? self[index + 1] : nil
        }
        let coverage: PeriodCoverage = owning?.periodCoverage(of: day) ?? .outside

        return CycleDayContext(
            day: day,
            owning: owning,
            following: following,
            ongoing: coverage == .ongoing ? owning : nil,
            completed: coverage == .completed ? owning : nil
        )
    }

    /// A day's period data lives on the cycle that owns the day — no earlier cycle can
    /// reach past a later cycle's start — so one backward scan answers every coverage query.
    private func coveringCycle(_ day: Daystamp, matching: (PeriodCoverage) -> Bool) -> CycleRecord? {
        guard let cycle = owningCycle(for: day), matching(cycle.periodCoverage(of: day)) else { return nil }
        return cycle
    }
}

// MARK: - CycleRecord Helpers

extension CycleRecord {

    /// How this cycle's recorded period relates to the given day.
    ///
    /// An open period is windowed to `maxPeriodLength`: a period the user never closed must
    /// not capture days far beyond it, otherwise those days offer "end period" forever and
    /// the next cycle can never be started.
    func periodCoverage(of day: Daystamp) -> PeriodCoverage {
        guard startDay <= day, let periodLength = periodLength else { return .outside }

        if periodLength == 0 {
            return day - startDay < Constants.Cycle.maxPeriodLength ? .ongoing : .outside
        }
        return day - startDay < periodLength ? .completed : .outside
    }

    /// Start of the predicted cycle the day falls into, extrapolated from this cycle's
    /// start, or nil while the day is still within the first extrapolated cycle.
    func predictedCycleStart(for day: Daystamp, cycleLength: Int) -> Daystamp? {
        let cyclesPassed = (day - startDay) / cycleLength
        guard cyclesPassed >= 1 else { return nil }
        return startDay.advanced(by: cyclesPassed * cycleLength)
    }
}

// MARK: - Flow Levels

/// What the user reported for the days of the loaded range — `CalendarState.flowLevels`, sparse
/// the way `visibleComments` is: an absent day is one nothing was reported for.
///
/// The lookup used to live on `CycleRecord`, because the levels lived in a dictionary inside the
/// cycle's row. See `FlowLevelRecord` for why they moved.
extension Dictionary where Key == Daystamp, Value == Int {

    /// Last day of the cycle the user reported flow for — how far the period is known to have
    /// actually run. Nil when nothing is reported inside the period window.
    ///
    /// The window is the cycle's own days: from its start up to `maxPeriodLength`, and not past
    /// `today`. It was needed when the levels sat in the cycle's dictionary, which could hold
    /// keys from days outside its period; it is needed just as much now that they are day-keyed,
    /// from the other side — this map spans the whole loaded range, and without the window a
    /// later cycle's flow would stretch this one's period across the calendar.
    ///
    /// Walks the window backwards rather than the map forwards: the window is at most
    /// `maxPeriodLength` days, and the map is several hundred.
    func lastFlowDay(of cycle: CycleRecord, notAfter today: Daystamp) -> Daystamp? {
        let windowEnd = Swift.min(today, cycle.startDay.advanced(by: Constants.Cycle.maxPeriodLength - 1))
        guard cycle.startDay <= windowEnd else { return nil }

        var day = windowEnd
        while day >= cycle.startDay {
            if self[day] != nil { return day }
            day = day.advanced(by: -1)
        }
        return nil
    }
}
