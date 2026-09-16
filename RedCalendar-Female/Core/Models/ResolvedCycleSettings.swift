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
    /// Whether marking a new period start also confirms the previous one — using this same
    /// `periodLength` — when it was left open. See `DatabaseMiddleware.handleMarkPeriodStart`.
    let autoConfirmPreviousCycle: Bool

    init(_ settings: UserSettings.CycleSettings?) {
        cycleLength = clamp(
            settings?.defaultLength ?? Constants.Cycle.defaultCycleLength,
            Constants.Cycle.minCycleLength...Constants.Cycle.maxCycleLength
        )
        periodLength = clamp(
            settings?.defaultPeriodLength ?? Constants.Cycle.defaultPeriodLength,
            Constants.Cycle.minPeriodLength...Constants.Cycle.maxPeriodLength
        )
        // Two bounds, intersected. The luteal phase has to leave at least one day of follicular
        // phase, or ovulation lands on or before the cycle start — that upper bound is
        // `cycleLength - 1` and has no constant of its own. It also has to stay inside
        // `minLutealPhaseLength...maxLutealPhaseLength`, the same plausibility range
        // `CycleForecast` itself trusts as a measurement, so a number from the server — or from
        // an old RedCalendar 2.0 import — is never drawn from as-is when it is outside it, the
        // same way `cycleLength`/`periodLength` are clamped to the exact range their own median
        // trusts. `min(_:_:)` on the upper bound keeps the range valid (lower ≤ upper) however
        // small `cycleLength - 1` gets; it cannot in practice drop below `minLutealPhaseLength`,
        // since `cycleLength` is itself already clamped to `minCycleLength...`, but nothing here
        // should depend on that holding.
        let lutealUpperBound = min(cycleLength - 1, Constants.Cycle.maxLutealPhaseLength)
        lutealPhaseLength = clamp(
            settings?.lutealPhaseLength ?? Constants.Cycle.defaultLutealPhaseLength,
            min(Constants.Cycle.minLutealPhaseLength, lutealUpperBound)...lutealUpperBound
        )
        autoConfirmPreviousCycle = settings?.autoConfirmPreviousCycle
            ?? Constants.Cycle.defaultAutoConfirmPreviousCycle
    }
}

/// One local edit to the cycle settings: the fields the settings screen changed, and no others.
///
/// A patch rather than the resolved value, and the difference is what reaches the server.
/// `ResolvedCycleSettings` fills every field with a fallback; writing those fallbacks would turn
/// "the user never said" into "the user chose 28" — in `users_female.settings`, for every device,
/// permanently. An edit writes the one key it changed.
///
/// The luteal phase is deliberately not a fourth field here. `cycleLength` and `periodLength`
/// have a screen that lets a person type them, so this patch's "don't touch" `nil` exists to
/// protect that typed value from a forecast recompute that merely has nothing new to say.
/// `lutealPhaseLength` has no such value to protect — nothing but `DatabaseMiddleware.refreshForecast`
/// ever writes it — so it has no "don't touch" state at all and does not belong on a type whose
/// whole point is distinguishing "not edited" from "edited to nothing". See
/// `DatabaseServiceProtocol.updateForecast(cycleLength:periodLength:lutealPhaseLength:)`.
struct CycleSettingsPatch: Sendable, Equatable {
    var cycleLength: Int?
    var periodLength: Int?
    var autoConfirmPreviousCycle: Bool?
}

private func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
    Swift.min(Swift.max(value, range.lowerBound), range.upperBound)
}
