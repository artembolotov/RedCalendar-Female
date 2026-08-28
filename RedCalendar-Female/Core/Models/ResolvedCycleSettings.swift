//
//  ResolvedCycleSettings.swift
//  RedCalendar-Female
//

/// Cycle settings with server values clamped into the ranges the domain can actually work
/// with. `UserSettings.CycleSettings` carries raw optional integers straight from the API:
/// a zero or negative cycle length there would divide by zero in `predictedCycleStart` and
/// never terminate the prediction loop in `computeDayDisplayStates`.
///
/// Immutable, and constructed in exactly one place — the reducer, from what the profile
/// observation delivered. That is what makes it safe to clamp on the way in: nothing downstream
/// can produce a second, differently-clamped answer for the same stored settings.
struct ResolvedCycleSettings: Equatable, Sendable {
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
