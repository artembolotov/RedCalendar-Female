//
//  DayDisplayStateComputer.swift
//  RedCalendar-Female
//

// MARK: - Compute Day Display States

// The result is sparse: days without any cycle phase, comment or tags have no
// entry at all — a missing key means DayDisplayState.empty.
func computeDayDisplayStates(
    _ calendarState: CalendarState,
    cycleSettings: ResolvedCycleSettings
) -> [Daystamp: DayDisplayState] {

    let loadedRange = calendarState.loadedRange
    let lowerBound = loadedRange.lowerBound
    let upperBound = loadedRange.upperBound
    let today = calendarState.todayDayStamp

    var result: [Daystamp: DayDisplayState] = [:]

    for daystamp in calendarState.visibleComments.keys where loadedRange.contains(daystamp) {
        result[daystamp, default: .empty].hasComment = true
    }

    let categoryByTagId = Dictionary(
        calendarState.userTags.map { ($0.id, $0.category) },
        uniquingKeysWith: { $1 }
    )
    for (daystamp, tagIds) in calendarState.visibleDayTags where loadedRange.contains(daystamp) {
        let categories = Set(tagIds.compactMap { categoryByTagId[$0] })
        if !categories.isEmpty {
            result[daystamp, default: .empty].tagCategories = categories
        }
    }

    // Sorted by startDay — reducer invariant (see CycleRecord+Queries)
    let realCycles = calendarState.cycles
    guard let lastStartDay = realCycles.last?.startDay else { return result }

    // Build full cycle list: real + predicted forward
    var allCycles = realCycles
    var predictedStart = lastStartDay.advanced(by: cycleSettings.cycleLength)
    while predictedStart <= upperBound {
        let ovulationDay = predictedStart.advanced(by: cycleSettings.cycleLength - cycleSettings.lutealPhaseLength)
        let predicted = CycleRecord(
            startDay: predictedStart,
            periodLength: cycleSettings.periodLength,
            ovulation: OvulationData(day: ovulationDay, confirmed: false)
        )
        allCycles.append(predicted)
        predictedStart = predictedStart.advanced(by: cycleSettings.cycleLength)
    }

    for (index, cycle) in allCycles.enumerated() {
        // Days this cycle owns: from its start up to (not including) the next cycle's
        // start, clipped to the loaded range.
        let nextStart: Daystamp? = index + 1 < allCycles.count ? allCycles[index + 1].startDay : nil
        let segmentStart = max(cycle.startDay, lowerBound)
        let segmentEnd = nextStart.map { min($0.advanced(by: -1), upperBound) } ?? upperBound
        guard segmentStart <= segmentEnd else { continue }

        let isPredictedCycle = cycle.startDay > lastStartDay

        // Effective period length, plus the last day of it that is confirmed rather than
        // predicted — days past it render faded.
        let effectivePeriodLength: Int
        let lastConfirmedDay: Daystamp
        if let periodLength = cycle.periodLength, periodLength > 0 {
            effectivePeriodLength = periodLength
            lastConfirmedDay = today
        } else {
            // Open period. Logged flow shows the period was still running that day, so the
            // forecast stretches to cover it — but it never shortens the forecast, and only
            // the start stays confirmed: nothing but markPeriodEnd can end a period, so
            // everything after the start keeps rendering as a prediction.
            let flowLength = calendarState.flowLevels.lastFlowDay(of: cycle, notAfter: today)
                .map { $0 - cycle.startDay + 1 } ?? 0
            effectivePeriodLength = max(cycleSettings.periodLength, flowLength)
            lastConfirmedDay = cycle.startDay
        }

        // Where the bar genuinely ends: the period's own last day, cut short only when the
        // next cycle starts inside it — positions are derived from that, so a truncated
        // period still caps with `.end` instead of trailing off as `.middle`.
        //
        // The loaded range is a viewport, not a boundary: a period running past it is
        // clipped for drawing but keeps its square edge, which reads as continuing offscreen.
        let periodEnd = cycle.startDay.advanced(by: effectivePeriodLength - 1)
        let barEnd = nextStart.map { min(periodEnd, $0.advanced(by: -1)) } ?? periodEnd

        let drawEnd = min(barEnd, upperBound)
        if segmentStart <= drawEnd {
            for day in segmentStart...drawEnd {
                // Synthesized predicted cycles always render as predictions, even if their
                // days are now in the past.
                let isPredicted = isPredictedCycle || day > lastConfirmedDay

                let position: SegmentPosition
                if cycle.startDay == barEnd {
                    position = .single
                } else if day == cycle.startDay {
                    position = .start
                } else if day == barEnd {
                    position = .end
                } else {
                    position = .middle
                }

                result[day, default: .empty].cyclePhase = .period(position: position, isPredicted: isPredicted)
            }
        }

        // FertilePhase — derive predicted ovulation when the cycle has no explicit data
        // so that user-created (real) cycles also show a fertile window / ovulation.
        // If a confirmed next cycle exists, anchor ovulation off its start (luteal phase
        // before it) so the previous cycle's prediction reflects actual cycle length.
        let ovulationDay: Daystamp
        let ovulationConfirmed: Bool
        if let ovulation = cycle.ovulation {
            ovulationDay = ovulation.day
            ovulationConfirmed = ovulation.confirmed
        } else {
            let nextRealStart = index + 1 < realCycles.count ? realCycles[index + 1].startDay : nil
            ovulationDay = nextRealStart?.advanced(by: -cycleSettings.lutealPhaseLength)
                ?? cycle.startDay.advanced(by: cycleSettings.cycleLength - cycleSettings.lutealPhaseLength)
            ovulationConfirmed = false
        }

        // Where the window genuinely begins and ends: clipped to the cycle's own days, so a
        // stray ovulation date can't reach into the next cycle's window. The band's rounded
        // caps come from these — the loaded range is a viewport, and a window running past it
        // is clipped for drawing but keeps its square edge, same rule as the period bar above.
        let windowLower = max(ovulationDay.advanced(by: -Constants.Cycle.fertileWindowDaysBefore), cycle.startDay)
        let windowUpper = nextStart
            .map { min(ovulationDay.advanced(by: Constants.Cycle.fertileWindowDaysAfter), $0.advanced(by: -1)) }
            ?? ovulationDay.advanced(by: Constants.Cycle.fertileWindowDaysAfter)
        guard windowLower <= windowUpper else { continue }

        let drawLower = max(windowLower, lowerBound)
        let drawUpper = min(windowUpper, upperBound)
        if drawLower <= drawUpper {
            for day in drawLower...drawUpper {
                let position: SegmentPosition
                if windowLower == windowUpper {
                    position = .single
                } else if day == windowLower {
                    position = .start
                } else if day == windowUpper {
                    position = .end
                } else {
                    position = .middle
                }

                result[day, default: .empty].fertileWindow = FertileWindow(
                    phase: day == ovulationDay ? .ovulation(confirmed: ovulationConfirmed) : .fertile,
                    position: position
                )
            }
        }
    }

    return result
}
