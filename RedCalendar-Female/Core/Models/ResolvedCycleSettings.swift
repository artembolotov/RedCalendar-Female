//
//  ResolvedCycleSettings.swift
//  RedCalendar-Female
//

/// Cycle settings with server values clamped into the ranges the domain can actually work
/// with. `UserSettings.CycleSettings` carries raw optional integers straight from the API:
/// a zero or negative cycle length there would divide by zero in `predictedCycleStart` and
/// never terminate the prediction loop in `computeDayDisplayStates`.
nonisolated struct ResolvedCycleSettings: Equatable {
    let cycleLength: Int
    let periodLength: Int
    let lutealPhaseLength: Int

    init(_ settings: UserSettings.CycleSettings?) {
        cycleLength = clamp(
            settings?.defaultLength ?? Constants.Cycle.defaultCycleLength,
            Constants.Cycle.minCycleLength...Constants.Cycle.maxCycleLength
        )
        periodLength = clamp(
            settings?.defaultPeriodLength ?? Constants.Cycle.defaultPeriodLength,
            Constants.Cycle.minPeriodLength...Constants.Cycle.maxPeriodLength
        )
        // The luteal phase has to leave at least one day of follicular phase, otherwise
        // ovulation lands on or before the cycle start.
        lutealPhaseLength = clamp(
            settings?.lutealPhaseLength ?? Constants.Cycle.defaultLutealPhaseLength,
            1...(cycleLength - 1)
        )
    }
}

nonisolated private func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
    Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
}
