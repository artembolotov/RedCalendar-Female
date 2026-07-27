//
//  DayDisplayStateComputer.swift
//  RedCalendar-Female
//

// MARK: - Compute Day Display States

// The result is sparse: days without any cycle phase, comment or tags have no
// entry at all — a missing key means DayDisplayState.empty.
func computeDayDisplayStates(
    _ calendarState: CalendarState,
    cycleSettings: UserSettings.CycleSettings?
) -> [Daystamp: DayDisplayState] {

    let defaultLength = cycleSettings?.defaultLength ?? Constants.Cycle.defaultCycleLength
    let defaultPeriodLength = cycleSettings?.defaultPeriodLength ?? Constants.Cycle.defaultPeriodLength
    let lutealPhaseLength = cycleSettings?.lutealPhaseLength ?? Constants.Cycle.defaultLutealPhaseLength

    let lowerBound = calendarState.loadedRange.lowerBound.rawValue
    let upperBound = calendarState.loadedRange.upperBound.rawValue
    let todayRaw = calendarState.todayDayStamp.rawValue

    var result: [Daystamp: DayDisplayState] = [:]

    for daystamp in calendarState.visibleComments.keys where calendarState.loadedRange.contains(daystamp) {
        result[daystamp, default: .empty].hasComment = true
    }

    let categoryByTagId = Dictionary(uniqueKeysWithValues: calendarState.userTags.compactMap { tag in
        tag.category.map { (tag.id, $0) }
    })
    for (daystamp, tagIds) in calendarState.visibleDayTags where calendarState.loadedRange.contains(daystamp) {
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
    var predictedStart = lastStartDay + defaultLength
    while predictedStart <= upperBound {
        let ovulationDay = predictedStart + (defaultLength - lutealPhaseLength)
        let predicted = CycleRecord(
            startDay: predictedStart,
            periodLength: defaultPeriodLength,
            ovulation: OvulationData(day: ovulationDay, confirmed: false),
            flowLevels: [:]
        )
        allCycles.append(predicted)
        predictedStart += defaultLength
    }

    for (index, cycle) in allCycles.enumerated() {
        // Days this cycle owns: from its start up to (not including) the next cycle's
        // start, clipped to the loaded range.
        let nextStart = index + 1 < allCycles.count ? allCycles[index + 1].startDay : Int.max
        let segmentStart = max(cycle.startDay, lowerBound)
        let segmentEnd = min(nextStart - 1, upperBound)
        guard segmentStart <= segmentEnd else { continue }

        let isPredictedCycle = cycle.startDay > lastStartDay

        // Effective period length, plus the last day of it that is confirmed rather than
        // predicted — days past it render faded.
        let effectivePeriodLength: Int
        let lastConfirmedDay: Int
        if let periodLength = cycle.periodLength, periodLength > 0 {
            effectivePeriodLength = periodLength
            lastConfirmedDay = todayRaw - 1
        } else if let lastFlowDay = cycle.lastFlowDay(notAfter: todayRaw) {
            // Open period with logged flow: it is known to have run through the last day the
            // user reported flow for, so show exactly that instead of the default guess.
            effectivePeriodLength = lastFlowDay - cycle.startDay + 1
            lastConfirmedDay = lastFlowDay
        } else {
            effectivePeriodLength = defaultPeriodLength
            lastConfirmedDay = cycle.startDay
        }

        let periodEnd = cycle.startDay + effectivePeriodLength - 1
        let periodUpper = min(periodEnd, segmentEnd)
        if segmentStart <= periodUpper {
            for dayRaw in segmentStart...periodUpper {
                // Synthesized predicted cycles always render as predictions, even if their
                // days are now in the past.
                let isPredicted = isPredictedCycle || dayRaw > lastConfirmedDay

                let position: PeriodPosition
                if effectivePeriodLength == 1 {
                    position = .single
                } else if dayRaw == cycle.startDay {
                    position = .start
                } else if dayRaw == periodEnd {
                    position = .end
                } else {
                    position = .middle
                }

                result[Daystamp(rawValue: dayRaw), default: .empty].cyclePhase =
                    .period(position: position, isPredicted: isPredicted)
            }
        }

        // FertilePhase — derive predicted ovulation when the cycle has no explicit data
        // so that user-created (real) cycles also show a fertile window / ovulation.
        // If a confirmed next cycle exists, anchor ovulation off its start (luteal phase
        // before it) so the previous cycle's prediction reflects actual cycle length.
        let ovulationDay: Int
        let ovulationConfirmed: Bool
        if let ovulation = cycle.ovulation {
            ovulationDay = ovulation.day
            ovulationConfirmed = ovulation.confirmed
        } else {
            let nextRealStart = index + 1 < realCycles.count ? realCycles[index + 1].startDay : nil
            ovulationDay = nextRealStart.map { $0 - lutealPhaseLength }
                ?? cycle.startDay + (defaultLength - lutealPhaseLength)
            ovulationConfirmed = false
        }

        let fertileLower = max(ovulationDay - 3, segmentStart)
        let fertileUpper = min(ovulationDay + 1, segmentEnd)
        if fertileLower <= fertileUpper {
            for dayRaw in fertileLower...fertileUpper {
                result[Daystamp(rawValue: dayRaw), default: .empty].fertilePhase =
                    dayRaw == ovulationDay ? .ovulation(confirmed: ovulationConfirmed) : .fertile
            }
        }
    }

    return result
}
