//
//  StatisticsAverages.swift
//  RedCalendar-Female
//

/// The two numbers shown in `StatisticsView`'s top tiles, over the `StatisticsPeriod` the user
/// picked there. Median, like `CycleForecast`, and for the same reason — resistance to a single
/// missed-period outlier (see its doc comment) — but windowed by *time* rather than by count.
/// `CycleForecast` looks at the last `forecastWindow` recorded cycles, however long ago that
/// stretch was, because it exists to say what to predict next. Statistics is answering a
/// different question — "what has my cycle actually looked like lately" — so it takes every
/// plausible cycle whose own start falls in the chosen window, whether that is two cycles or
/// eight. Nothing here feeds back into the store or the forecast.
struct StatisticsAverages {
    let cycleLength: Int?
    let periodLength: Int?

    /// `cycles` must be sorted by `startDay` ascending, the reducer's invariant (see
    /// `CycleRecord+Queries`) — cycle length is measured between neighbours, so an unsorted array
    /// would produce negative distances and silently drop every one of them.
    init(cycles: [CycleRecord], today: Daystamp, period: StatisticsPeriod) {
        let cutoff = period.windowDays.map { today - $0 }

        func isWithinWindow(_ day: Daystamp) -> Bool {
            guard let cutoff else { return true }
            return day >= cutoff
        }

        cycleLength = Self.median(
            of: zip(cycles, cycles.dropFirst())
                .filter { previous, _ in isWithinWindow(previous.startDay) }
                .map { previous, next in next.startDay - previous.startDay },
            within: Constants.Cycle.minCycleLength...Constants.Cycle.maxCycleLength
        )
        // Same `periodLength == 0` exclusion as `CycleForecast`: an open period is not yet a
        // fact, and `minPeriodLength` being 1 is what keeps it out of the median.
        periodLength = Self.median(
            of: cycles
                .filter { isWithinWindow($0.startDay) }
                .compactMap(\.periodLength),
            within: Constants.Cycle.minPeriodLength...Constants.Cycle.maxPeriodLength
        )
    }

    /// The lower of the two middles on an even count, same convention `CycleForecast` uses.
    /// `nil` while nothing plausible falls in the window — `StatisticsView` falls back to the
    /// stored `cycleSettings` for that case rather than leaving a tile blank.
    private static func median(of observations: [Int], within range: ClosedRange<Int>) -> Int? {
        let plausible = observations.filter { range.contains($0) }.sorted()
        guard !plausible.isEmpty else { return nil }
        return plausible[(plausible.count - 1) / 2]
    }
}
