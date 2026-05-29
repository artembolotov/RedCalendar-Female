//
//  DatabaseMiddleware.swift
//  RedCalendar-Female
//

import Foundation
import GRDB

// MARK: - DatabaseMiddleware

final class DatabaseMiddleware {
    @Injected private var dbService: DatabaseServiceProtocol

    private var cyclesToken: AnyDatabaseCancellable?
    private var userTagsToken: AnyDatabaseCancellable?
    private var commentsToken: AnyDatabaseCancellable?
    private var dayTagsToken: AnyDatabaseCancellable?

    private var currentLoadedRange: ClosedRange<Daystamp>?

    // MARK: - Handle

    func handle(state: AppState, action: AppAction, dispatch: @escaping (AppAction) -> Void) async -> [AppAction] {
        switch action {
        case .setAuthState(let authState):
            if case .authenticated = authState {
                startPermanentObservations(dispatch: dispatch)
                let initialRange = state.calendarState.loadedRange
                startRangeObservations(for: initialRange, dispatch: dispatch)
                currentLoadedRange = initialRange
            } else if case .notAuthenticated = authState {
                cancelAll()
            }

        case .calendarScrolledTo(let center):
            let buffer = 180
            let newRange = (center - buffer)...(center + buffer)
            guard let loaded = currentLoadedRange else { break }
            let needsExpansion = center.rawValue - loaded.lowerBound.rawValue < 30
                              || loaded.upperBound.rawValue - center.rawValue < 30
            if needsExpansion {
                currentLoadedRange = newRange
                startRangeObservations(for: newRange, dispatch: dispatch)
                return [.setLoadedRange(newRange)]
            }

        case .markPeriodStart(let stamp):
            handleMarkPeriodStart(stamp: stamp, cycles: state.calendarState.cycles)

        case .markPeriodEnd(let stamp):
            handleMarkPeriodEnd(stamp: stamp, cycles: state.calendarState.cycles)

        case .unmarkPeriodEnd(let stamp):
            handleUnmarkPeriodEnd(stamp: stamp, cycles: state.calendarState.cycles)

        case .setFlowLevel(let stamp, let level):
            handleSetFlowLevel(stamp: stamp, level: level, cycles: state.calendarState.cycles)

        case .saveComment(let stamp, let text):
            handleSaveComment(stamp: stamp, text: text)

        case .setDayTags(let stamp, let tagIds):
            handleSetDayTags(stamp: stamp, tagIds: tagIds)

        default:
            break
        }
        return []
    }

    // MARK: - Private Methods

    private func startPermanentObservations(dispatch: @escaping (AppAction) -> Void) {
        cyclesToken = dbService.observeCycles { records in
            dispatch(.setCycles(records))
        }
        userTagsToken = dbService.observeUserTags { records in
            dispatch(.setUserTags(records))
        }
    }

    private func startRangeObservations(for range: ClosedRange<Daystamp>, dispatch: @escaping (AppAction) -> Void) {
        let intRange = range.lowerBound.rawValue...range.upperBound.rawValue

        commentsToken = dbService.observeComments(in: intRange) { records in
            let dict = Dictionary(uniqueKeysWithValues: records.map {
                (Daystamp(rawValue: $0.dayNumber), $0)
            })
            dispatch(.setVisibleComments(dict))
        }

        dayTagsToken = dbService.observeDayTags(in: intRange) { records in
            let dict = Dictionary(uniqueKeysWithValues: records.map {
                (Daystamp(rawValue: $0.dayNumber), $0.tagIds)
            })
            dispatch(.setVisibleDayTags(dict))
        }
    }

    private func cancelAll() {
        cyclesToken = nil
        userTagsToken = nil
        commentsToken = nil
        dayTagsToken = nil
        currentLoadedRange = nil
    }

    // MARK: - Day editing handlers

    private func handleMarkPeriodStart(stamp: Daystamp, cycles: [CycleRecord]) {
        if let existing = cycles.first(where: { $0.startDay == stamp.rawValue }) {
            // Toggle off: soft delete if synced, physical delete if not
            if existing.updatedAt != nil {
                var deleted = existing
                deleted.periodLength = nil
                deleted.updatedAt = nil
                try? dbService.upsert([deleted])
            } else {
                try? dbService.deleteCycle(startDay: stamp.rawValue)
            }
        } else {
            // Reject if too close to another real cycle's start (min cycle length).
            let minGap = Constants.Cycle.minCycleLength
            let conflicts = cycles.contains { abs($0.startDay - stamp.rawValue) < minGap }
            if conflicts {
                AppLogger.warn("markPeriodStart rejected: closer than \(minGap) days to existing cycle")
                return
            }
            let newCycle = CycleRecord(
                startDay: stamp.rawValue,
                periodLength: 0,
                ovulation: nil,
                flowLevels: [:],
                updatedAt: nil
            )
            try? dbService.upsert([newCycle])
        }
    }

    private func handleMarkPeriodEnd(stamp: Daystamp, cycles: [CycleRecord]) {
        let maxLen = Constants.Cycle.maxPeriodLength
        let minLen = Constants.Cycle.minPeriodLength

        // Prefer the ongoing (open) period; fall back to closing a completed one.
        if let cycle = cycles.filter({ $0.startDay <= stamp.rawValue && ($0.periodLength ?? -1) == 0 })
                             .max(by: { $0.startDay < $1.startDay }) {
            let raw = stamp.rawValue - cycle.startDay + 1
            var updated = cycle
            updated.periodLength = max(minLen, min(maxLen, raw))
            updated.updatedAt = nil
            try? dbService.upsert([updated])
            return
        }

        if let cycle = cycles.filter({ c in
            guard let pl = c.periodLength, pl > 0 else { return false }
            return c.startDay <= stamp.rawValue && stamp.rawValue <= c.startDay + pl - 1
        }).max(by: { $0.startDay < $1.startDay }) {
            let raw = stamp.rawValue - cycle.startDay + 1
            var updated = cycle
            updated.periodLength = max(minLen, min(maxLen, raw))
            updated.updatedAt = nil
            try? dbService.upsert([updated])
        }
    }

    private func handleUnmarkPeriodEnd(stamp: Daystamp, cycles: [CycleRecord]) {
        guard let cycle = cycles.first(where: { c in
            guard let pl = c.periodLength, pl > 0 else { return false }
            return c.startDay + pl - 1 == stamp.rawValue
        }) else { return }
        var updated = cycle
        updated.periodLength = 0
        updated.updatedAt = nil
        try? dbService.upsert([updated])
    }

    private func handleSetFlowLevel(stamp: Daystamp, level: Int?, cycles: [CycleRecord]) {
        guard var cycle = cycles.filter({ $0.startDay <= stamp.rawValue })
                                .max(by: { $0.startDay < $1.startDay }) else { return }
        if let level = level {
            cycle.flowLevels[String(stamp.rawValue)] = level
        } else {
            cycle.flowLevels.removeValue(forKey: String(stamp.rawValue))
        }
        cycle.updatedAt = nil
        try? dbService.upsert([cycle])
    }

    private func handleSaveComment(stamp: Daystamp, text: String) {
        let record = CommentRecord(
            dayNumber: stamp.rawValue,
            comment: text.isEmpty ? nil : text,
            updatedAt: nil
        )
        try? dbService.upsert([record])
    }

    private func handleSetDayTags(stamp: Daystamp, tagIds: [String]) {
        let record = DayTagsRecord(
            dayNumber: stamp.rawValue,
            tagIds: tagIds,
            updatedAt: nil
        )
        try? dbService.upsert([record])
    }
}
