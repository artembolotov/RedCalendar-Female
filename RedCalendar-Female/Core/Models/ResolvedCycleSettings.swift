//
//  ResolvedCycleSettings.swift
//  RedCalendar-Female
//

/// Cycle settings with server values clamped into the ranges the domain can actually work
/// with. `UserSettings.CycleSettings` carries raw optional integers straight from the API:
/// a zero or negative cycle length there would divide by zero in `predictedCycleStart` and
/// never terminate the prediction loop in `computeDayDisplayStates`.
///
/// It lives in `AppState` rather than being resolved at each reader, because the settings screen
/// edits it optimistically — see `appReducer` — and the clamping has to hold for those edits too.
/// Hence `private(set)` and the two mutating setters: the bound being protected is the prediction
/// loop's, not the stepper's.
struct ResolvedCycleSettings: Equatable, Sendable {
    private(set) var cycleLength: Int
    private(set) var periodLength: Int
    private(set) var lutealPhaseLength: Int

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

    /// The luteal phase is re-clamped rather than left alone: it is not on this screen, but its
    /// upper bound is a function of the value that is. A stored 25 under a cycle shortened to 20
    /// would put ovulation on or before the start — the same invariant the initialiser keeps, at
    /// the only other place the cycle length can change.
    mutating func set(cycleLength: Int) {
        self.cycleLength = clamp(
            cycleLength,
            Constants.Cycle.minCycleLength...Constants.Cycle.maxCycleLength
        )
        lutealPhaseLength = clamp(lutealPhaseLength, 1...(self.cycleLength - 1))
    }

    mutating func set(periodLength: Int) {
        self.periodLength = clamp(
            periodLength,
            Constants.Cycle.minPeriodLength...Constants.Cycle.maxPeriodLength
        )
    }
}

/// One local edit to the cycle settings: the fields the settings screen changed, and no others.
///
/// A patch rather than the resolved value, and the difference is what reaches the server.
/// `ResolvedCycleSettings` fills every field with a fallback; writing those fallbacks would turn
/// "the user never said" into "the user chose 28" — in `users_female.settings`, for every device,
/// permanently. An edit writes the one key it changed.
struct CycleSettingsPatch: Sendable, Equatable {
    var cycleLength: Int?
    var periodLength: Int?
}

private func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
    Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
}
