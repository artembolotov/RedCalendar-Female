//
//  StatisticsAverages.swift
//  RedCalendar-Female
//

/// The plain averages shown in `StatisticsView`'s top tiles, over the last
/// `Constants.Statistics.averageWindowDays` — deliberately not the same number `CycleForecast`
/// writes into `ResolvedCycleSettings`. The calendar's own predictions need the median's
/// resistance to a single missed-period outlier (see `CycleForecast`'s doc comment); a stats
/// screen answering "how long has my cycle actually been, lately" is a different question, and a
/// windowed mean answers it more plainly. Nothing here feeds back into the store or the forecast.
struct StatisticsAverages {
    let cycleLength: Int?
    let periodLength: Int?

    /// `cycles` must be sorted by `startDay` ascending, the reducer's invariant (see
    /// `CycleRecord+Queries`) — cycle length is measured between neighbours, so an unsorted array
    /// would produce negative distances and silently drop every one of them.
    init(cycles: [CycleRecord], today: Daystamp) {
        let cutoff = today - Constants.Statistics.averageWindowDays

        cycleLength = Self.average(
            of: zip(cycles, cycles.dropFirst())
                .filter { previous, _ in previous.startDay >= cutoff }
                .map { previous, next in next.startDay - previous.startDay },
            within: Constants.Cycle.minCycleLength...Constants.Cycle.maxCycleLength
        )
        // Same `periodLength == 0` exclusion as `CycleForecast`: an open period is not yet a
        // fact, and `minPeriodLength` being 1 is what keeps it out of the average.
        periodLength = Self.average(
            of: cycles
                .filter { $0.startDay >= cutoff }
                .compactMap(\.periodLength),
            within: Constants.Cycle.minPeriodLength...Constants.Cycle.maxPeriodLength
        )
    }

    /// `nil` while nothing plausible falls in the window — `StatisticsView` falls back to the
    /// stored `cycleSettings` for that case rather than leaving a tile blank.
    private static func average(of observations: [Int], within range: ClosedRange<Int>) -> Int? {
        let plausible = observations.filter { range.contains($0) }
        guard !plausible.isEmpty else { return nil }
        return Int((Double(plausible.reduce(0, +)) / Double(plausible.count)).rounded())
    }
}
