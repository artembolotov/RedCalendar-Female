//
//  CycleForecast.swift
//  RedCalendar-Female
//

/// The two numbers the calendar predicts with, measured from what the user actually recorded.
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

    /// `cycles` must be sorted by `startDay` ascending — the reducer's invariant, the same one
    /// `CycleRecord+Queries` relies on. Cycle length is measured between neighbours, so an
    /// unsorted array would produce negative distances and silently drop every one of them.
    init(cycles: [CycleRecord]) {
        cycleLength = Self.median(
            of: zip(cycles, cycles.dropFirst()).map { $0.1.startDay - $0.0.startDay },
            within: Constants.Cycle.minCycleLength...Constants.Cycle.maxCycleLength
        )
        // An open period is stored as `periodLength == 0` and must not be measured — nothing
        // ended it, so its length is not yet a fact. The range below is what excludes it, since
        // `minPeriodLength` is 1; there is no second filter to keep in step with this one.
        periodLength = Self.median(
            of: cycles.compactMap(\.periodLength),
            within: Constants.Cycle.minPeriodLength...Constants.Cycle.maxPeriodLength
        )
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
}
