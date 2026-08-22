//
//  DatabaseMiddleware.swift
//  RedCalendar-Female
//

import Foundation
import GRDB

// MARK: - DatabaseMiddleware

/// Main-actor isolated, and still a correctness requirement rather than a convenience — though
/// no longer the only thing standing between this class and a heap corruption.
///
/// The tokens below are stored properties whose `deinit` does real work
/// (`AnyDatabaseCancellable.deinit` calls `cancel()`), so overwriting one from two threads at
/// once loses a reference count and corrupts the heap; the crash then lands wherever the
/// allocator happens to notice, with nothing of ours on the stack. A fast calendar scroll
/// produced exactly that, because `.calendarScrolledTo` arrives in bursts and every action used
/// to get its own `Task` on the cooperative pool.
///
/// The store no longer works that way — actions are drained one at a time — so this isolation is
/// now belt to that braces. It stays because the ownership argument is independent of the
/// store's scheduling: whoever holds a token has to be isolated somewhere, and the main actor is
/// where GRDB delivers the values anyway.
///
/// **The invariant is unchanged:** everything that reads or writes the tokens and `observedRange`
/// (`startPermanentObservations`, `startRangeObservations`, `cancelAll`) is synchronous, and
/// `handle` has no `await` between checking the state of the observations and changing it. The
/// main actor is reentrant — an `await` introduced into that gap brings the race back.
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
    /// It duplicates `state.calendarState.loadedRange` on purpose, and the reason has outlived
    /// two rewrites of how the store schedules things. The dispatch below does reach the reducer
    /// immediately, so `state` is current the moment it returns — but that does nothing for the
    /// `.scrolledTo` actions already sitting in the queue behind it. Each was queued with the
    /// state *its own* reducer produced, so every one of them still carries the range as it was
    /// before the expansion, and the calendar reports a fresh centre every `centerReportStep`
    /// days, so a fling produces several. Deciding from state restarted both observations once
    /// per action in the burst; deciding from here restarts them once per expansion.
    private var observedRange: ClosedRange<Daystamp>?

    private var observationsActive: Bool { cyclesToken != nil }

    private init() {}

    // MARK: - Handle

    func handle(state: AppState, action: AppAction, dispatch: @escaping Dispatch) async {
        switch action {

        case .auth(.set(let authState)):
            if case .authenticated = authState {
                // userDetails updates re-dispatch .authenticated — don't recreate observations
                guard !observationsActive else { break }
                startPermanentObservations(dispatch: dispatch)
                startRangeObservations(for: state.calendarState.loadedRange, dispatch: dispatch)
            } else if case .notAuthenticated = authState {
                cancelAll()
            }

        case .calendar(.scrolledTo(let center)):
            // `observedRange` is non-nil exactly while the range observations are running.
            guard let observed = observedRange else { break }
            let threshold = Constants.Calendar.rangeExpansionThreshold
            let needsExpansion = center.rawValue - observed.lowerBound.rawValue < threshold
                              || observed.upperBound.rawValue - center.rawValue < threshold
            if needsExpansion {
                let buffer = Constants.Calendar.loadedRangeBuffer
                let newRange = (center - buffer)...(center + buffer)
                startRangeObservations(for: newRange, dispatch: dispatch)
                dispatch(.data(.setLoadedRange(newRange)))
            }

        // This middleware owns the data domain — every read here is an observation it started and
        // every write is a transaction it runs — so the switch is exhaustive. The cases it does
        // nothing for are spelled out rather than swept into a `default`, which is the whole
        // point: a new `DataAction` does not compile until somebody has decided whether it
        // reaches the database.
        case .data(let dataAction):
            switch dataAction {

            case .markPeriodStart(let stamp):
                await handleMarkPeriodStart(
                    stamp: stamp,
                    today: state.calendarState.todayDayStamp,
                    cycles: state.calendarState.cycles,
                    dispatch: dispatch
                )

            case .markPeriodEnd(let stamp):
                await handleMarkPeriodEnd(
                    stamp: stamp,
                    today: state.calendarState.todayDayStamp,
                    cycles: state.calendarState.cycles,
                    dispatch: dispatch
                )

            case .unmarkPeriodEnd(let stamp):
                await handleUnmarkPeriodEnd(
                    stamp: stamp,
                    cycles: state.calendarState.cycles,
                    dispatch: dispatch
                )

            case .setFlowLevel(let stamp, let level):
                await handleSetFlowLevel(
                    stamp: stamp,
                    level: level,
                    today: state.calendarState.todayDayStamp,
                    cycles: state.calendarState.cycles,
                    dispatch: dispatch
                )

            case .saveComment(let stamp, let text):
                await handleSaveComment(stamp: stamp, text: text, dispatch: dispatch)

            case .setDayTags(let stamp, let tagIds):
                await handleSetDayTags(stamp: stamp, tagIds: tagIds, dispatch: dispatch)

            case .createUserTag(let tag):
                await write(.userTag, dispatch: dispatch) { try await dbService.upsert([tag]) }

            case .updateUserTag(let tag):
                await write(.userTag, detail: "update", dispatch: dispatch) { try await dbService.upsert([tag]) }

            case .deleteUserTag(let tag):
                await write(.userTag, detail: "delete", dispatch: dispatch) { try await dbService.upsert([tag]) }

            // Values this middleware produced, on their way to the reducer.
            case .setCycles, .setUserTags, .setVisibleComments, .setVisibleDayTags, .setLoadedRange:
                break

            // A UI signal with nothing to write — `FeedbackMiddleware` is what reacts to it.
            case .beganEditingUserTag:
                break

            // The outcome of a write, which the reducer and the UI deal with.
            case .writeFailed, .dismissWriteFailure:
                break
            }

        default:
            break
        }
    }

    // MARK: - Private Methods

    private func startPermanentObservations(dispatch: @escaping Dispatch) {
        let service = dbService
        cyclesToken = service.observeCycles { records in
            dispatch(.data(.setCycles(records)))
        }
        userTagsToken = service.observeUserTags { records in
            dispatch(.data(.setUserTags(records)))
        }
    }

    // The previous observations are cancelled explicitly rather than left to the assignment
    // dropping their last reference and `deinit` doing it: this way the moment of cancellation is
    // this line, not wherever ARC got around to releasing the object.
    private func startRangeObservations(for range: ClosedRange<Daystamp>, dispatch: @escaping Dispatch) {
        commentsToken?.cancel()
        dayTagsToken?.cancel()
        observedRange = range

        let service = dbService
        commentsToken = service.observeComments(in: range) { records in
            dispatch(.data(.setVisibleComments(Self.commentsByDay(records))))
        }

        dayTagsToken = service.observeDayTags(in: range) { records in
            dispatch(.data(.setVisibleDayTags(Self.dayTagsByDay(records))))
        }
    }

    /// Shared by the observation and by the re-read a failed comment write triggers, so the two
    /// cannot disagree about what a soft-deleted comment looks like in state: absent, not empty.
    private static func commentsByDay(_ records: [CommentRecord]) -> [Daystamp: String] {
        Dictionary(
            records.compactMap { record in record.comment.map { (record.dayNumber, $0) } },
            uniquingKeysWith: { $1 }
        )
    }

    /// The same sharing, for the same reason. `day_tags` has no soft delete, so a day stripped of
    /// its tags keeps an empty row and an empty list — which is what `appReducer` writes when the
    /// edit is made, and what this has to keep writing for the round trip to change nothing.
    private static func dayTagsByDay(_ records: [DayTagsRecord]) -> [Daystamp: [String]] {
        Dictionary(
            records.map { ($0.dayNumber, $0.tagIds) },
            uniquingKeysWith: { $1 }
        )
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

    private func handleMarkPeriodStart(
        stamp: Daystamp,
        today: Daystamp,
        cycles: [CycleRecord],
        dispatch: @escaping Dispatch
    ) async {
        if let existing = cycles.first(where: { $0.startDay == stamp }) {
            // Toggle off: soft delete if synced, physical delete if not
            if existing.updatedAt != nil {
                var deleted = existing
                deleted.periodLength = nil
                deleted.updatedAt = nil
                await write(.periodStart, detail: "soft delete", dispatch: dispatch) {
                    try await dbService.upsert([deleted])
                }
            } else {
                await write(.periodStart, detail: "delete", dispatch: dispatch) {
                    try await dbService.deleteCycle(startDay: stamp)
                }
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
            await write(.periodStart, detail: "insert", dispatch: dispatch) {
                try await dbService.upsert([newCycle])
            }
        }
    }

    private func handleMarkPeriodEnd(
        stamp: Daystamp,
        today: Daystamp,
        cycles: [CycleRecord],
        dispatch: @escaping Dispatch
    ) async {
        guard stamp <= today, let cycle = cycles.recordedPeriodCycle(covering: stamp) else {
            AppLogger.warn("markPeriodEnd rejected for \(stamp): in the future, or no period covers the day")
            return
        }

        let raw = stamp - cycle.startDay + 1
        var updated = cycle
        updated.periodLength = max(Constants.Cycle.minPeriodLength, min(Constants.Cycle.maxPeriodLength, raw))
        updated.updatedAt = nil
        await write(.periodEnd, dispatch: dispatch) { try await dbService.upsert([updated]) }
    }

    private func handleUnmarkPeriodEnd(
        stamp: Daystamp,
        cycles: [CycleRecord],
        dispatch: @escaping Dispatch
    ) async {
        guard let cycle = cycles.completedCycle(covering: stamp),
              let periodLength = cycle.periodLength,
              cycle.startDay.advanced(by: periodLength - 1) == stamp else { return }
        var updated = cycle
        updated.periodLength = 0
        updated.updatedAt = nil
        await write(.periodEnd, detail: "unmark", dispatch: dispatch) {
            try await dbService.upsert([updated])
        }
    }

    private func handleSetFlowLevel(
        stamp: Daystamp,
        level: Int?,
        today: Daystamp,
        cycles: [CycleRecord],
        dispatch: @escaping Dispatch
    ) async {
        guard stamp <= today, var cycle = cycles.recordedPeriodCycle(covering: stamp) else {
            AppLogger.warn("setFlowLevel rejected for \(stamp): in the future, or no recorded period covers the day")
            return
        }
        cycle.setFlowLevel(level, on: stamp)
        cycle.updatedAt = nil
        await write(.flowLevel, dispatch: dispatch) { try await dbService.upsert([cycle]) }
    }

    private func handleSaveComment(stamp: Daystamp, text: String, dispatch: @escaping Dispatch) async {
        let record = CommentRecord(
            dayNumber: stamp,
            comment: text.isEmpty ? nil : text,
            updatedAt: nil
        )
        await write(.comment, dispatch: dispatch) { try await dbService.upsert([record]) }
    }

    private func handleSetDayTags(stamp: Daystamp, tagIds: [String], dispatch: @escaping Dispatch) async {
        let record = DayTagsRecord(
            dayNumber: stamp,
            tagIds: tagIds,
            updatedAt: nil
        )
        await write(.dayTags, dispatch: dispatch) { try await dbService.upsert([record]) }
    }

    /// A user edit that does not reach the disk is reported twice: to the log, and to the user.
    ///
    /// The log alone was what this did, and it was defensible only while every one of these
    /// writes was invisible in state — the day card redraws from the observation, so a write that
    /// failed simply left the old value on screen and the user saw their tap do nothing. That
    /// stopped being true for the comment and for the day's tags, which the reducer puts on
    /// screen before the disk has taken them, and it will stop being true for anything else that
    /// follows them. So the failure goes into `CalendarState.writeFailure` and the UI says so.
    ///
    /// The transaction goes to the GRDB queue and is awaited, so the main thread never stands on
    /// it. Order is preserved: requests reach that queue in the order the main actor reached the
    /// corresponding `await`.
    private func write(
        _ operation: DataWriteOperation,
        detail: String? = nil,
        dispatch: @escaping Dispatch,
        _ work: () async throws -> Void
    ) async {
        do {
            try await work()
        } catch {
            let label = detail.map { "\(operation.logLabel) \($0)" } ?? operation.logLabel
            AppLogger.error("Database write failed: \(label)", error: error)
            dispatch(.data(.writeFailed(operation)))

            // These are the edits whose new value is already in state, so telling the user
            // it failed is not enough on its own — what they were told was lost is still on the
            // card. Re-reading puts the stored value back, which is what the
            // observation would have done had the write changed anything. Spelled out rather
            // than defaulted, so an edit that starts reducing has to say which side it is on.
            switch operation {
            case .comment:
                await reloadComments(dispatch: dispatch)
            case .dayTags:
                await reloadDayTags(dispatch: dispatch)
            case .userTag:
                await reloadUserTags(dispatch: dispatch)
            case .periodStart, .periodEnd, .flowLevel:
                break
            }
        }
    }

    private func reloadComments(dispatch: @escaping Dispatch) async {
        guard let range = observedRange else { return }
        do {
            let records = try await dbService.fetchComments(in: range)
            dispatch(.data(.setVisibleComments(Self.commentsByDay(records))))
        } catch {
            AppLogger.error("Failed to re-read comments after a failed write", error: error)
        }
    }

    /// No range to guard on, unlike the two either side of it: the catalogue's observation is
    /// one of the permanent pair, so what was subscribed is the whole table.
    private func reloadUserTags(dispatch: @escaping Dispatch) async {
        do {
            let records = try await dbService.fetchUserTags()
            dispatch(.data(.setUserTags(records)))
        } catch {
            AppLogger.error("Failed to re-read user tags after a failed write", error: error)
        }
    }

    private func reloadDayTags(dispatch: @escaping Dispatch) async {
        guard let range = observedRange else { return }
        do {
            let records = try await dbService.fetchDayTags(in: range)
            dispatch(.data(.setVisibleDayTags(Self.dayTagsByDay(records))))
        } catch {
            AppLogger.error("Failed to re-read day tags after a failed write", error: error)
        }
    }
}
