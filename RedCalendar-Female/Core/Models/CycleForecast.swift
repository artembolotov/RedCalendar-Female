//
//  CycleForecast.swift
//  RedCalendar-Female
//

/// The three numbers the calendar predicts with, measured from what the user actually recorded.
///
/// A `nil` field means "not enough recorded to say", which is not the same as a fallback: the
/// stored setting stands, and that is what gives the value chosen on the onboarding screen — or
/// typed into `ProfileView` — its first few cycles before any measurement can replace it.
///
/// Measured from the cycles every time, never accumulated into the previous answer. That is
/// what makes two devices holding the same cycles agree, and what lets a start deleted by
/// mistake take its effect on the forecast away with it.
struct CycleForecast {
    let cycleLength: Int?
    let periodLength: Int?
    let lutealPhaseLength: Int?

    /// `cycles` must be sorted by `startDay` ascending — the reducer's invariant, the same one
    /// `CycleRecord+Queries` relies on. Cycle length is measured between neighbours, so an
    /// unsorted array would produce negative distances and silently drop every one of them.
    init(cycles: [CycleRecord]) {
        cycleLength = Self.median(
            of: zip(cycles, cycles.dropFirst()).map { previous, next in next.startDay - previous.startDay },
            within: Constants.Cycle.minCycleLength...Constants.Cycle.maxCycleLength
        )
        // An open period is stored as `periodLength == 0` and must not be measured — nothing
        // ended it, so its length is not yet a fact. The range below is what excludes it, since
        // `minPeriodLength` is 1; there is no second filter to keep in step with this one.
        periodLength = Self.median(
            of: cycles.compactMap(\.periodLength),
            within: Constants.Cycle.minPeriodLength...Constants.Cycle.maxPeriodLength
        )
        lutealPhaseLength = Self.lastConfirmedLutealPhase(cycles: cycles)
    }

    /// The lower median of the last `forecastWindow` plausible observations, or nil while there
    /// are fewer than `forecastMinObservations` of them.
    ///
    /// A median rather than an average, and that is the whole of the outlier handling. The
    /// common error in this data is a month nobody recorded: it arrives as a single interval of
    /// roughly twice the length, which an average of six would carry for half a year and a
    /// median of six does not notice at all.
    ///
    /// `within` drops what cannot be one cycle before the median ever sees it. Locally that is
    /// already true — `canStartPeriod` refuses a start closer than `minCycleLength` to another
    /// cycle — but a history imported from RedCalendar 2.0 was written by an app that did not
    /// enforce it.
    ///
    /// The lower of the two middles on an even count, rather than the average of them: it is a
    /// length this person actually recorded, and it errs short, where a forecast that arrives
    /// early is easier to live with than one that arrives late.
    private static func median(of observations: [Int], within range: ClosedRange<Int>) -> Int? {
        let window = observations.filter { range.contains($0) }.suffix(Constants.Cycle.forecastWindow)
        guard window.count >= Constants.Cycle.forecastMinObservations else { return nil }
        return window.sorted()[(window.count - 1) / 2]
    }

    /// Not a median over a window, unlike the two above — deliberately. The luteal phase is close
    /// to constant for a given woman, so a single *confirmed* ovulation is already the answer, and
    /// averaging it against older, less certain cycles would only dilute the most reliable
    /// measurement this app ever gets. Takes the most recent **completed** cycle (a real next
    /// start on record, so the distance is a fact rather than a guess) whose ovulation the user
    /// actually confirmed — `.anovulatory` and an unconfirmed automatic guess are both silent
    /// here, the same way an open period is silent for `periodLength`.
    ///
    /// A distance outside `minLutealPhaseLength...maxLutealPhaseLength` is not trusted either,
    /// for the same reason `median(of:within:)` drops an implausible interval before it is ever
    /// measured: a single bad confirmation — the wrong day picked, or a next start recorded weeks
    /// late — would otherwise become a "constant" every future prediction leans on, with nothing
    /// to average it back down. Unlike the median, dropping it does not forfeit the observation:
    /// the scan keeps walking backward for an older, plausible confirmation instead of giving up.
    private static func lastConfirmedLutealPhase(cycles: [CycleRecord]) -> Int? {
        let plausibleRange = Constants.Cycle.minLutealPhaseLength...Constants.Cycle.maxLutealPhaseLength
        for (index, cycle) in cycles.enumerated().reversed() {
            guard index + 1 < cycles.count, case .confirmed(let day) = cycle.ovulation else { continue }
            let distance = cycles[index + 1].startDay - day
            guard plausibleRange.contains(distance) else { continue }
            return distance
        }
        return nil
    }
}
