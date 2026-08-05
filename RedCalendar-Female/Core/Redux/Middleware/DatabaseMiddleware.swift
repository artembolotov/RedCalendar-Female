//
//  DatabaseMiddleware.swift
//  RedCalendar-Female
//

import Foundation
import GRDB

// MARK: - DatabaseMiddleware

/// Main-actor isolated, and that is a correctness requirement rather than a convenience.
///
/// `Store.send` gives every action its own `Task` and `Middleware` is an unisolated `async`
/// closure, so without isolation two actions ran `handle` at the same time on different threads
/// of the cooperative pool. The observation tokens below are plain stored properties whose
/// `deinit` does real work (`AnyDatabaseCancellable.deinit` calls `cancel()`), and overwriting
/// one of those from two threads at once loses a reference count and corrupts the heap — the
/// crash then lands wherever the allocator happens to notice, with nothing of ours on the stack.
/// A fast calendar scroll produced exactly that, because `.calendarScrolledTo` arrives in bursts.
///
/// **The invariant:** everything that reads or writes the tokens and `observedRange`
/// (`startPermanentObservations`, `startRangeObservations`, `cancelAll`) is synchronous, and
/// `handle` has no `await` between checking the state of the observations and changing it. The
/// main actor is reentrant — an `await` introduced into that gap brings the same race back.
@MainActor
final class DatabaseMiddleware {
    static let shared = DatabaseMiddleware()

    @Injected private var dbService: DatabaseServiceProtocol

    private var cyclesToken: AnyDatabaseCancellable?
    private var userTagsToken: AnyDatabaseCancellable?
    private var commentsToken: AnyDatabaseCancellable?
    private var dayTagsToken: AnyDatabaseCancellable?

    /// The range `commentsToken` and `dayTagsToken` are currently subscribed to.
    ///
    /// It duplicates `state.calendarState.loadedRange` on purpose. The store only learns about a
    /// new range after `.setLoadedRange` travels back through `send` → `Task` → `Task.yield()` →
    /// reducer, while the calendar reports a fresh centre every `centerReportStep` days: several
    /// more `.calendarScrolledTo` arrive inside that round trip, and every one of them still sees
    /// the old `loadedRange`. Deciding from state restarted both observations once per action in
    /// the burst; deciding from here restarts them once per expansion.
    private var observedRange: ClosedRange<Daystamp>?

    private var observationsActive: Bool { cyclesToken != nil }

    private init() {}

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
            // `observedRange` is non-nil exactly while the range observations are running.
            guard let observed = observedRange else { break }
            let threshold = Constants.Calendar.rangeExpansionThreshold
            let needsExpansion = center.rawValue - observed.lowerBound.rawValue < threshold
                              || observed.upperBound.rawValue - center.rawValue < threshold
            if needsExpansion {
                let buffer = Constants.Calendar.loadedRangeBuffer
                let newRange = (center - buffer)...(center + buffer)
                startRangeObservations(for: newRange, dispatch: dispatch)
                return [.setLoadedRange(newRange)]
            }

        case .markPeriodStart(let stamp):
            await handleMarkPeriodStart(
                stamp: stamp,
                today: state.calendarState.todayDayStamp,
                cycles: state.calendarState.cycles
            )

        case .markPeriodEnd(let stamp):
            await handleMarkPeriodEnd(
                stamp: stamp,
                today: state.calendarState.todayDayStamp,
                cycles: state.calendarState.cycles
            )

        case .unmarkPeriodEnd(let stamp):
            await handleUnmarkPeriodEnd(stamp: stamp, cycles: state.calendarState.cycles)

        case .setFlowLevel(let stamp, let level):
            await handleSetFlowLevel(
                stamp: stamp,
                level: level,
                today: state.calendarState.todayDayStamp,
                cycles: state.calendarState.cycles
            )

        case .saveComment(let stamp, let text):
            await handleSaveComment(stamp: stamp, text: text)

        case .setDayTags(let stamp, let tagIds):
            await handleSetDayTags(stamp: stamp, tagIds: tagIds)

        default:
            break
        }
        return []
    }

    // MARK: - Private Methods

    private func startPermanentObservations(dispatch: @escaping (AppAction) -> Void) {
        let service = dbService
        cyclesToken = service.observeCycles { records in
            dispatch(.setCycles(records))
        }
        userTagsToken = service.observeUserTags { records in
            dispatch(.setUserTags(records))
        }
    }

    // The previous observations are cancelled explicitly rather than left to the assignment
    // dropping their last reference and `deinit` doing it: this way the moment of cancellation is
    // this line, not wherever ARC got around to releasing the object.
    private func startRangeObservations(for range: ClosedRange<Daystamp>, dispatch: @escaping (AppAction) -> Void) {
        commentsToken?.cancel()
        dayTagsToken?.cancel()
        observedRange = range

        let service = dbService
        commentsToken = service.observeComments(in: range) { records in
            let dict = Dictionary(
                records.compactMap { record in record.comment.map { (record.dayNumber, $0) } },
                uniquingKeysWith: { $1 }
            )
            dispatch(.setVisibleComments(dict))
        }

        dayTagsToken = service.observeDayTags(in: range) { records in
            let dict = Dictionary(
                records.map { ($0.dayNumber, $0.tagIds) },
                uniquingKeysWith: { $1 }
            )
            dispatch(.setVisibleDayTags(dict))
        }
    }

    private func cancelAll() {
        cyclesToken?.cancel()
        userTagsToken?.cancel()
        commentsToken?.cancel()
        dayTagsToken?.cancel()

        cyclesToken = nil
        userTagsToken = nil
        commentsToken = nil
        dayTagsToken = nil
        observedRange = nil
    }

    // MARK: - Day editing handlers

    private func handleMarkPeriodStart(stamp: Daystamp, today: Daystamp, cycles: [CycleRecord]) async {
        if let existing = cycles.first(where: { $0.startDay == stamp }) {
            // Toggle off: soft delete if synced, physical delete if not
            if existing.updatedAt != nil {
                var deleted = existing
                deleted.periodLength = nil
                deleted.updatedAt = nil
                await write("markPeriodStart soft delete") { service in try await service.upsert([deleted]) }
            } else {
                await write("markPeriodStart delete") { service in try await service.deleteCycle(startDay: stamp) }
            }
        } else {
            guard cycles.canStartPeriod(at: stamp, today: today) else {
                AppLogger.warn("markPeriodStart rejected for \(stamp): in the future, or closer than \(Constants.Cycle.minCycleLength) days to an existing cycle")
                return
            }
            let newCycle = CycleRecord(
                startDay: stamp,
                periodLength: 0,
                ovulation: nil,
                flowLevels: [:],
                updatedAt: nil
            )
            await write("markPeriodStart insert") { service in try await service.upsert([newCycle]) }
        }
    }

    private func handleMarkPeriodEnd(stamp: Daystamp, today: Daystamp, cycles: [CycleRecord]) async {
        guard stamp <= today, let cycle = cycles.recordedPeriodCycle(covering: stamp) else {
            AppLogger.warn("markPeriodEnd rejected for \(stamp): in the future, or no period covers the day")
            return
        }

        let raw = stamp - cycle.startDay + 1
        var updated = cycle
        updated.periodLength = max(Constants.Cycle.minPeriodLength, min(Constants.Cycle.maxPeriodLength, raw))
        updated.updatedAt = nil
        await write("markPeriodEnd") { service in try await service.upsert([updated]) }
    }

    private func handleUnmarkPeriodEnd(stamp: Daystamp, cycles: [CycleRecord]) async {
        guard let cycle = cycles.completedCycle(covering: stamp),
              let periodLength = cycle.periodLength,
              cycle.startDay.advanced(by: periodLength - 1) == stamp else { return }
        var updated = cycle
        updated.periodLength = 0
        updated.updatedAt = nil
        await write("unmarkPeriodEnd") { service in try await service.upsert([updated]) }
    }

    private func handleSetFlowLevel(stamp: Daystamp, level: Int?, today: Daystamp, cycles: [CycleRecord]) async {
        guard stamp <= today, var cycle = cycles.recordedPeriodCycle(covering: stamp) else {
            AppLogger.warn("setFlowLevel rejected for \(stamp): in the future, or no recorded period covers the day")
            return
        }
        cycle.setFlowLevel(level, on: stamp)
        cycle.updatedAt = nil
        await write("setFlowLevel") { service in try await service.upsert([cycle]) }
    }

    private func handleSaveComment(stamp: Daystamp, text: String) async {
        let record = CommentRecord(
            dayNumber: stamp,
            comment: text.isEmpty ? nil : text,
            updatedAt: nil
        )
        await write("saveComment") { service in try await service.upsert([record]) }
    }

    private func handleSetDayTags(stamp: Daystamp, tagIds: [String]) async {
        let record = DayTagsRecord(
            dayNumber: stamp,
            tagIds: tagIds,
            updatedAt: nil
        )
        await write("setDayTags") { service in try await service.upsert([record]) }
    }

    // User edits must not fail silently in production data flows — at minimum leave a trace.
    //
    // The transaction goes to the GRDB queue and is awaited, so the main thread never stands on
    // it. Order is preserved: requests reach that queue in the order the main actor reached the
    // corresponding `await`.
    private func write(
        _ operation: String,
        _ work: (DatabaseServiceProtocol) async throws -> Void
    ) async {
        // `@Injected` vends the service through a `mutating get`, so it is resolved once here and
        // handed to the closure — that keeps the mutating access off the same expression as the
        // `await` inside the operation.
        let service = dbService
        do {
            try await work(service)
        } catch {
            AppLogger.error("Database write failed: \(operation)", error: error)
        }
    }
}
