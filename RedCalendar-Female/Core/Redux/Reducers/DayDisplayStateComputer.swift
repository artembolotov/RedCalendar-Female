//
//  DayDisplayStateComputer.swift
//  RedCalendar-Female
//

// MARK: - Compute Day Display States

func computeDayDisplayStates(
    _ calendarState: CalendarState,
    cycleSettings: UserSettings.CycleSettings?
) -> [Daystamp: DayDisplayState] {

    let defaultLength = cycleSettings?.defaultLength ?? 28
    let defaultPeriodLength = cycleSettings?.defaultPeriodLength ?? 5
    let lutealPhaseLength = cycleSettings?.lutealPhaseLength ?? 14

    let sortedCycles = calendarState.cycles.sorted { $0.startDay < $1.startDay }

    guard !sortedCycles.isEmpty else { return [:] }

    // Build full cycle list: real + predicted forward
    var allCycles = sortedCycles

    let lastStartDay = sortedCycles.last!.startDay
    var predictedStart = lastStartDay + defaultLength
    let upperBound = calendarState.loadedRange.upperBound.rawValue

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

    let todayRaw = calendarState.todayDayStamp.rawValue
    let lowerBound = calendarState.loadedRange.lowerBound.rawValue

    var result: [Daystamp: DayDisplayState] = [:]
    result.reserveCapacity(upperBound - lowerBound + 1)

    for dayRaw in lowerBound...upperBound {
        let daystamp = Daystamp(rawValue: dayRaw)

        // Find owning cycle: last cycle where startDay <= dayRaw
        var owningCycle: CycleRecord?
        for cycle in allCycles {
            if cycle.startDay <= dayRaw {
                owningCycle = cycle
            } else {
                break
            }
        }

        guard let cycle = owningCycle else {
            result[daystamp] = DayDisplayState(
                cyclePhase: .none,
                fertilePhase: nil,
                hasComment: calendarState.visibleComments[daystamp] != nil,
                tagCategories: resolveTagCategories(for: daystamp, calendarState: calendarState)
            )
            continue
        }

        // Effective period length
        let effectivePeriodLength: Int
        if let pl = cycle.periodLength, pl > 0 {
            effectivePeriodLength = pl
        } else {
            effectivePeriodLength = defaultPeriodLength
        }

        let periodEnd = cycle.startDay + effectivePeriodLength - 1

        // CyclePhase
        let cyclePhase: CyclePhase
        if dayRaw >= cycle.startDay && dayRaw <= periodEnd {
            let isPredicted = dayRaw >= todayRaw
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
            cyclePhase = .period(position: position, isPredicted: isPredicted)
        } else {
            cyclePhase = .none
        }

        // FertilePhase
        let fertilePhase: FertilePhase?
        if let ovDay = cycle.ovulation?.day {
            let fertileStart = ovDay - 3
            let fertileEnd = ovDay + 1
            if dayRaw == ovDay {
                fertilePhase = .ovulation(confirmed: cycle.ovulation?.confirmed ?? false)
            } else if dayRaw >= fertileStart && dayRaw <= fertileEnd {
                fertilePhase = .fertile
            } else {
                fertilePhase = nil
            }
        } else {
            fertilePhase = nil
        }

        let hasComment = calendarState.visibleComments[daystamp] != nil

        let categories = resolveTagCategories(for: daystamp, calendarState: calendarState)

        result[daystamp] = DayDisplayState(
            cyclePhase: cyclePhase,
            fertilePhase: fertilePhase,
            hasComment: hasComment,
            tagCategories: categories
        )
    }

    return result
}

// MARK: - Private Helpers

private func resolveTagCategories(for daystamp: Daystamp, calendarState: CalendarState) -> Set<Int> {
    let tagIds = calendarState.visibleDayTags[daystamp] ?? []
    return Set(tagIds.compactMap { id in
        calendarState.userTags.first(where: { $0.id == id })?.category
    })
}
