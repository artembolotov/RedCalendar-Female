//
//  StatisticsRow.swift
//  RedCalendar-Female
//

/// One row of `StatisticsView`'s history list — a single recorded cycle, resolved once per
/// render rather than re-derived per row from the raw `CycleRecord` array.
struct StatisticsRow: Identifiable {
    enum Subtitle {
        /// The period's confirmed length.
        case periodLength(Int)
        /// The period is still open, and this is the most recent recorded cycle — there is
        /// nothing to report yet beyond "this one is still running".
        case currentCycleOpen
        /// The period is still open on a cycle that is *not* the most recent one — only
        /// reachable with `autoConfirmPreviousCycle` off, since marking a new start otherwise
        /// closes the one before it. Distinct from `currentCycleOpen`: this cycle isn't the one
        /// running now, it was simply never closed.
        case periodNotConfirmed
    }

    enum Trailer {
        /// The cycle's real length — the distance to the next recorded cycle's start.
        case cycleLength(Int)
        /// The distance to the next recorded cycle's start falls outside what a single cycle can
        /// plausibly be — almost always a period the user forgot to log in between, not a fact
        /// about this cycle. `CycleForecast` excludes the same gaps from its own median for the
        /// same reason (see `Constants.Cycle`); shown as a dash rather than the raw number.
        case cycleLengthImplausible
        /// No next cycle recorded yet: how many days have passed since this cycle started.
        case daysElapsed(Int)
    }

    var id: Daystamp { startDay }
    let startDay: Daystamp
    let subtitle: Subtitle
    let trailer: Trailer
}

/// Builds the history rows, most recent cycle first — the order `StatisticsView` draws in.
///
/// `cycles` must be sorted ascending by `startDay`, the reducer's invariant (see
/// `CycleRecord+Queries`) — this walks it once, backward, rather than re-deriving each row's
/// neighbour from scratch.
func statisticsRows(cycles: [CycleRecord], today: Daystamp) -> [StatisticsRow] {
    cycles.indices.reversed().map { index in
        let cycle = cycles[index]
        let periodLength = cycle.periodLength ?? 0
        let isMostRecent = index == cycles.count - 1

        let trailer: StatisticsRow.Trailer
        if isMostRecent {
            trailer = .daysElapsed(today - cycle.startDay + 1)
        } else {
            let cycleLength = cycles[index + 1].startDay - cycle.startDay
            let plausibleRange = Constants.Cycle.minCycleLength...Constants.Cycle.maxCycleLength
            trailer = plausibleRange.contains(cycleLength) ? .cycleLength(cycleLength) : .cycleLengthImplausible
        }

        let subtitle: StatisticsRow.Subtitle
        if periodLength > 0 {
            subtitle = .periodLength(periodLength)
        } else {
            subtitle = isMostRecent ? .currentCycleOpen : .periodNotConfirmed
        }

        return StatisticsRow(startDay: cycle.startDay, subtitle: subtitle, trailer: trailer)
    }
}
