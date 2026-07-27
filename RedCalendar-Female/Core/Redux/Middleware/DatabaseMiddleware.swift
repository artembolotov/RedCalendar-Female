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

    private var observationsActive: Bool { cyclesToken != nil }

    // MARK: - Handle

    func handle(state: AppState, action: AppAction, dispatch: @escaping (AppAction) -> Void) async -> [AppAction] {
        switch action {
        case .setAuthState(let authState):
            if case .authenticated = authState {
                // userDetails updates re-dispatch .authenticated — don't recreate observations
                guard !observationsActive else { break }
                startPermanentObservations(dispatch: dispatch)
                startRangeObservations(for: state.calendarState.loadedRange, dispatch: dispatch)
            } else if case .notAuthenticated = authState {
                cancelAll()
            }

        case .calendarScrolledTo(let center):
            guard observationsActive else { break }
            let loaded = state.calendarState.loadedRange
            let threshold = Constants.Calendar.rangeExpansionThreshold
            let needsExpansion = center.rawValue - loaded.lowerBound.rawValue < threshold
                              || loaded.upperBound.rawValue - center.rawValue < threshold
            if needsExpansion {
                let buffer = Constants.Calendar.loadedRangeBuffer
                let newRange = (center - buffer)...(center + buffer)
                startRangeObservations(for: newRange, dispatch: dispatch)
                return [.setLoadedRange(newRange)]
            }

        case .markPeriodStart(let stamp):
            handleMarkPeriodStart(
                stamp: stamp,
                today: state.calendarState.todayDayStamp,
                cycles: state.calendarState.cycles
            )

        case .markPeriodEnd(let stamp):
            handleMarkPeriodEnd(
                stamp: stamp,
                today: state.calendarState.todayDayStamp,
                cycles: state.calendarState.cycles
            )

        case .unmarkPeriodEnd(let stamp):
            handleUnmarkPeriodEnd(stamp: stamp, cycles: state.calendarState.cycles)

        case .setFlowLevel(let stamp, let level):
            handleSetFlowLevel(
                stamp: stamp,
                level: level,
                today: state.calendarState.todayDayStamp,
                cycles: state.calendarState.cycles
            )

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
            let dict = Dictionary(uniqueKeysWithValues: records.compactMap { record in
                record.comment.map { (Daystamp(rawValue: record.dayNumber), $0) }
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
    }

    // MARK: - Day editing handlers

    private func handleMarkPeriodStart(stamp: Daystamp, today: Daystamp, cycles: [CycleRecord]) {
        if let existing = cycles.first(where: { $0.startDay == stamp.rawValue }) {
            // Toggle off: soft delete if synced, physical delete if not
            if existing.updatedAt != nil {
                var deleted = existing
                deleted.periodLength = nil
                deleted.updatedAt = nil
                write("markPeriodStart soft delete") { try dbService.upsert([deleted]) }
            } else {
                write("markPeriodStart delete") { try dbService.deleteCycle(startDay: stamp.rawValue) }
            }
        } else {
            guard cycles.canStartPeriod(at: stamp.rawValue, today: today.rawValue) else {
                AppLogger.warn("markPeriodStart rejected for \(stamp): in the future, or closer than \(Constants.Cycle.minCycleLength) days to an existing cycle")
                return
            }
            let newCycle = CycleRecord(
                startDay: stamp.rawValue,
                periodLength: 0,
                ovulation: nil,
                flowLevels: [:],
                updatedAt: nil
            )
            write("markPeriodStart insert") { try dbService.upsert([newCycle]) }
        }
    }

    private func handleMarkPeriodEnd(stamp: Daystamp, today: Daystamp, cycles: [CycleRecord]) {
        guard cycles.canEndPeriod(at: stamp.rawValue, today: today.rawValue) else {
            AppLogger.warn("markPeriodEnd rejected for \(stamp): in the future, or no period covers the day")
            return
        }

        guard let cycle = cycles.recordedPeriodCycle(covering: stamp.rawValue) else { return }

        let raw = stamp.rawValue - cycle.startDay + 1
        var updated = cycle
        updated.periodLength = max(Constants.Cycle.minPeriodLength, min(Constants.Cycle.maxPeriodLength, raw))
        updated.updatedAt = nil
        write("markPeriodEnd") { try dbService.upsert([updated]) }
    }

    private func handleUnmarkPeriodEnd(stamp: Daystamp, cycles: [CycleRecord]) {
        guard let cycle = cycles.completedCycle(covering: stamp.rawValue),
              let periodLength = cycle.periodLength,
              cycle.startDay + periodLength - 1 == stamp.rawValue else { return }
        var updated = cycle
        updated.periodLength = 0
        updated.updatedAt = nil
        write("unmarkPeriodEnd") { try dbService.upsert([updated]) }
    }

    private func handleSetFlowLevel(stamp: Daystamp, level: Int?, today: Daystamp, cycles: [CycleRecord]) {
        guard cycles.canSetFlowLevel(at: stamp.rawValue, today: today.rawValue) else {
            AppLogger.warn("setFlowLevel rejected for \(stamp): in the future, or no recorded period covers the day")
            return
        }

        guard var cycle = cycles.recordedPeriodCycle(covering: stamp.rawValue) else { return }
        cycle.setFlowLevel(level, on: stamp)
        cycle.updatedAt = nil
        write("setFlowLevel") { try dbService.upsert([cycle]) }
    }

    private func handleSaveComment(stamp: Daystamp, text: String) {
        let record = CommentRecord(
            dayNumber: stamp.rawValue,
            comment: text.isEmpty ? nil : text,
            updatedAt: nil
        )
        write("saveComment") { try dbService.upsert([record]) }
    }

    private func handleSetDayTags(stamp: Daystamp, tagIds: [String]) {
        let record = DayTagsRecord(
            dayNumber: stamp.rawValue,
            tagIds: tagIds,
            updatedAt: nil
        )
        write("setDayTags") { try dbService.upsert([record]) }
    }

    // User edits must not fail silently in production data flows — at minimum leave a trace.
    private func write(_ operation: String, _ work: () throws -> Void) {
        do {
            try work()
        } catch {
            AppLogger.error("Database write failed: \(operation)", error: error)
        }
    }
}
