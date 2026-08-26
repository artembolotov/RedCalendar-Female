//
//  SyncMiddleware.swift
//  RedCalendar-Female
//

import Foundation
import UIKit

/// The sync run of SYNC.md §5.
///
/// A class with state, like `DatabaseMiddleware` and for the same reason: one run at a time, one
/// debounce timer, one backoff, and a remembered request that arrived while a run was in flight.
/// `@MainActor` is what owns that state — the store drains actions serially, but this middleware
/// is also entered from outside the store entirely (see `syncNow`), so scheduling is not
/// ownership here any more than it is there.
///
/// **The run is not a chain of actions.** Push, pull and apply all happen inside `syncNow`, which
/// awaits the network and must therefore never be awaited by `handle` — a long `await` in a
/// middleware delays every action queued behind it. `handle` starts a `Task` and returns.
@MainActor
final class SyncMiddleware {
    static let shared = SyncMiddleware()

    @Injected private var dbService: DatabaseServiceProtocol
    @Injected private var apiService: APIServiceProtocol
    @Injected private var keychain: KeychainServiceProtocol

    /// Where a run sends what it learns. It is captured from `handle` rather than held as a store
    /// reference, because `syncNow` has a second caller with no store in hand — the background
    /// push handler of §8, which may run before the store's queue has drained a single action.
    ///
    /// A run that starts before this is set still applies everything correctly; what it cannot do
    /// is move the indicator or bracket a full resync. Both are safe to lose in exactly that
    /// window: nothing has processed `.auth(.set(.authenticated))` yet either, so there are no
    /// observations to pause and no screen to indicate to.
    private var sink: Dispatch?

    private var isRunning = false
    /// A run was asked for while one was going. It is remembered rather than dropped: an edit
    /// made in an unlucky second would otherwise wait for the next unrelated trigger, which in
    /// practice means until the app is backgrounded (§5.6).
    private var pendingRun = false

    /// Bumped every time the session ends. A run in flight when the user signs out would
    /// otherwise finish against a database that has just been wiped (§6) — applying the page it
    /// already asked for, moving the cursor, and leaving the previous account's rows on a phone
    /// whose whole point was that they are gone. There is nothing to cancel from the outside: a
    /// run is a `Task` nobody holds, and the network call it is waiting on is not the step that
    /// does damage. So it checks, at the two points where it would touch the database next.
    private var sessionEpoch = 0

    private var debounceTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var backoff: TimeInterval?

    /// Kept apart from `retryTask`/`backoff` rather than folded into them. Both are "one future
    /// run, at most one pending", but a retry follows a failure and a poll follows a success —
    /// sharing the delay would let an import that is merely slow inflate the backoff a real
    /// outage is measured with, and reset it on every answer that came back fine.
    private var importPollTask: Task<Void, Never>?
    private var importPoll: TimeInterval?

    private init() {}

    // MARK: - Handle

    func handle(state: AppState, action: AppAction, dispatch: @escaping Dispatch) async {
        sink = dispatch

        switch action {

        // This middleware owns the sync domain, so the inner switch is exhaustive.
        case .sync(let syncAction):
            switch syncAction {
            case .requested(let reason):
                if reason.isDebounced {
                    scheduleDebouncedRun(reason: reason)
                } else {
                    debounceTask?.cancel()
                    debounceTask = nil
                    start(reason: reason)
                }

            // Reduced, drawn, and of no interest to the run that emitted them.
            case .setState, .beganFullResync, .finishedFullResync:
                break
            }

        // The one trigger without which a cold start would never sync at all: `.onAppear` is
        // gone (§8) and `.onChange(of: scenePhase)` does not fire for the initial value. This is
        // the same signal `DatabaseMiddleware` starts its observations on, and it arrives both
        // after a session restored from the keychain and after a fresh login.
        case .auth(.set(.authenticated)):
            start(reason: .authenticated)

        case .auth(.set(.notAuthenticated)), .auth(.logout):
            sessionEpoch += 1
            cancelPendingWork()

        case .retryFailedTasks:
            if state.isAuthenticated {
                start(reason: .appActive)
            }

        default:
            break
        }
    }

    // MARK: - Entry points

    /// One run, start to finish — including every `has_more` page, a wipe and its restart, and a
    /// `full_resync_required` and its restart.
    ///
    /// Returns a `UIBackgroundFetchResult` because the background push handler of §8 needs one and
    /// `send` returns nothing. `.sync(.requested)` leads here too: one implementation, two entry
    /// points, and the one that needs an answer gets it.
    ///
    /// `serverRevision` is the `r` a silent push carries (§7) — the revision the server had when
    /// it sent it. A device already at or past it has nothing to fetch and says so without a
    /// request, which is the whole reason APNs tolerates these pushes at all. It is compared
    /// against the cursor read in the run's own first transaction rather than against one read
    /// beforehand: a run may already be moving that cursor as the push lands.
    @discardableResult
    func syncNow(reason: SyncReason, serverRevision: Int? = nil) async -> UIBackgroundFetchResult {
        guard !isRunning else {
            // Not "wait for the other one": the caller may be a push handler holding iOS's
            // completion handler open. Remembering the request is what keeps the edit that
            // triggered it from being dropped.
            pendingRun = true
            return .noData
        }

        // From the keychain, never from `state.deviceId`. The store reduces synchronously but
        // drains effects in a `Task`, so on a background launch the queue has *probably* passed
        // by the time the push handler runs — and "probably" is not a thing to build on when the
        // keychain is synchronous and correct at any moment (§8).
        guard let deviceId = keychain.getDeviceID() else { return .noData }

        let epoch = sessionEpoch
        isRunning = true
        // This run supersedes the question a previous one left pending; how it ends decides
        // whether it is asked again. The interval is deliberately left alone — clearing it here
        // would reset the doubling on every poll and leave an import that never finishes being
        // asked about every few seconds for as long as the app is open.
        importPollTask?.cancel()
        importPollTask = nil
        // Without it, a run in flight when the user swipes the app away is suspended mid-request
        // and resumes minutes later, if at all.
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "sync")
        var pausedObservations = false
        var appliedAnything = false

        defer {
            isRunning = false
            // On **every** exit, failure and cancellation included. Observations that never came
            // back up are a calendar frozen until the app is relaunched (§5.5).
            if pausedObservations {
                sink?(.sync(.finishedFullResync))
            }
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
            }
            if pendingRun && epoch == sessionEpoch {
                pendingRun = false
                Task { await self.syncNow(reason: reason) }
            }
        }

        sink?(.sync(.setState(.syncing)))

        do {
            var rounds = 0
            // The import status as of the last round that named one (§10.4). A response may omit
            // it and `applySync` coalesces rather than clears, so the last named value is still
            // the current one — which is why this is carried across rounds rather than read off
            // the final response.
            var importStatus: String?
            while true {
                rounds += 1
                guard rounds <= Constants.Sync.maxRoundsPerRun else {
                    AppLogger.warn("Sync: gave up after \(rounds - 1) rounds in one run")
                    break
                }

                // Signed out since this run started — including the logout that wipes. Nothing
                // this response carries may reach the disk, and the next sign-in starts from a
                // cursor of zero anyway.
                guard epoch == sessionEpoch else {
                    AppLogger.info("Sync: abandoning the run — the session ended")
                    return .noData
                }

                // Step 1. Also the moment a grown `known_tables` resets the cursor, which is why
                // it is re-read every round rather than once per run.
                let local = try await dbService.prepareSyncState(knownTables: SyncTable.knownTables)
                importStatus = local.importStatus

                // Only on the first round, and only for the push path. Nothing has been pushed
                // yet, so this is not "we are up to date" in general — it is "the change this
                // push is about is already here". Local edits get their own trigger (§5.6).
                if rounds == 1, let serverRevision, serverRevision <= local.cursor {
                    AppLogger.info("Sync: push revision \(serverRevision) is not ahead of the cursor — nothing to do")
                    // Explicit, because the `defer` above does not touch the indicator: it was set
                    // `.syncing` a moment ago and nothing else on this path would take it down.
                    finish(importStatus: importStatus)
                    return .noData
                }

                // A run that starts from zero is a full resync however few rows it turns out to
                // carry (§5.5), and the pause spans every page of it — hence the flag rather than
                // a bracket per round.
                if local.cursor == 0 && !pausedObservations {
                    pausedObservations = true
                    sink?(.sync(.beganFullResync))
                }

                // Steps 2 and 3. Until the database's owner is known, nothing is pushed: if these
                // rows belong to the previous user of this phone, sending them files them under
                // the current account, and the wipe below would only undo the local copy (§5.2).
                let pullOnly = local.userId == nil
                let batch = pullOnly ? DirtyBatch() : try await dbService.fetchDirty()
                let push = batch.push

                let response = try await apiService.sync(
                    deviceId: deviceId,
                    request: SyncRequest(
                        since: local.cursor,
                        syncSchema: Constants.Sync.schemaVersion,
                        device: SyncRequest.Device(timezone: TimeZone.current.identifier),
                        changes: push.isEmpty ? nil : push
                    )
                )

                // Step 5, before step 6: a wipe contains a full resync and makes one pointless,
                // so the other order costs a round.
                if let owner = local.userId, let responseOwner = response.userId, responseOwner != owner {
                    AppLogger.warn("Sync: the database belongs to another user — wiping")
                    try await dbService.wipeAll(newOwner: responseOwner)
                    continue
                }

                // Step 6. The rest of this response is deliberately not applied: its rows were
                // selected against a cursor the server has just disowned.
                if response.fullResyncRequired {
                    AppLogger.info("Sync: server ordered a full resync")
                    try await dbService.resetSyncCursor()
                    continue
                }

                // Checked again here, and this is the one that matters: everything above only
                // read, and the wipe can land while the request is in flight.
                guard epoch == sessionEpoch else {
                    AppLogger.info("Sync: dropping a response — the session ended mid-request")
                    return .noData
                }

                // Step 7 — one transaction, four ordered steps, and the cursor moves only if all
                // of it committed.
                try await dbService.applySync(
                    SyncApplication(
                        userId: response.userId,
                        changes: response.changes,
                        rejected: response.rejected,
                        sentMax: pullOnly ? nil : batch.sentMax,
                        nextCursor: response.nextCursor,
                        importStatus: response.importStatus
                    )
                )

                if let status = response.importStatus {
                    importStatus = status
                }

                if !(response.changes?.isEmpty ?? true) || !response.rejected.isEmpty {
                    appliedAnything = true
                }
                if !response.rejected.isEmpty {
                    AppLogger.warn("Sync: \(response.rejected.count) row(s) rejected by the server")
                }

                // Step 8 — the next page immediately, with no debounce.
                guard response.hasMore else { break }
            }

            backoff = nil
            retryTask?.cancel()
            retryTask = nil
            finish(importStatus: importStatus)
            return appliedAnything ? .newData : .noData

        } catch {
            return handleFailure(error, reason: reason)
        }
    }

    // MARK: - Private Methods

    private func start(reason: SyncReason) {
        // In its own `Task` rather than awaited: this waits on the network, and the store's
        // effect queue is serial.
        Task { await syncNow(reason: reason) }
    }

    private func scheduleDebouncedRun(reason: SyncReason) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Constants.Sync.localEditDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            await self?.syncNow(reason: reason)
        }
    }

    private func cancelPendingWork() {
        debounceTask?.cancel()
        debounceTask = nil
        retryTask?.cancel()
        retryTask = nil
        backoff = nil
        pendingRun = false
        cancelImportPoll()
        sink?(.sync(.setState(.idle)))
    }

    /// The table of §5.7, and its first row is the important one: **offline is not an error.**
    /// The app is built to work without a network, so no network means `.pending` — there is
    /// something to send and it will go — and never a red indicator.
    private func handleFailure(_ error: Error, reason: SyncReason) -> UIBackgroundFetchResult {
        switch error {

        case APIServiceError.unauthorized:
            // The database is **not** touched. This device was signed out from elsewhere; the
            // person is the same one, and their history is theirs (§6).
            AppLogger.warn("Sync: 401 — signing out, leaving the database alone")
            sink?(.sync(.setState(.idle)))
            sink?(.auth(.set(.notAuthenticated)))
            return .failed

        case APIServiceError.rateLimited(let retryAfter, _):
            scheduleRetry(after: retryAfter ?? nextBackoff())
            sink?(.sync(.setState(.pending)))
            return .failed

        case APIServiceError.serverUnavailable(_, _), APIServiceError.networkError(_), is URLError:
            scheduleRetry(after: nextBackoff())
            sink?(.sync(.setState(.pending)))
            return .failed

        default:
            // A 4xx on the whole request, or a response this build cannot decode. Retrying does
            // not fix either, but stopping outright would need a person to notice — so it backs
            // off like the rest and says so in the indicator.
            AppLogger.error("Sync run failed (\(reason.rawValue))", error: error)
            scheduleRetry(after: nextBackoff())
            sink?(.sync(.setState(.failed)))
            return .failed
        }
    }

    private func nextBackoff() -> TimeInterval {
        let next = min((backoff ?? 0) * 2, Constants.Sync.maxBackoff)
        let delay = max(Constants.Sync.minBackoff, next)
        backoff = delay
        return delay
    }

    /// How a successful run ends: the indicator, and the one thing such a run may schedule.
    ///
    /// **The rescheduling reads the drawn state, not the status string.** A run that ends still
    /// showing work is exactly the run whose import has not finished — §9's table says so — and
    /// making that the condition keeps `running` spelled out in one place (`SyncState`) instead
    /// of two.
    private func finish(importStatus: String?) {
        let state = SyncState(afterImport: importStatus)
        sink?(.sync(.setState(state)))

        if state == .syncing {
            scheduleImportPoll()
        } else {
            cancelImportPoll()
        }
    }

    /// The silent push at the end of an import (§10.4) is a hint, and on the one run that matters
    /// it is a hint that can miss: the import starts at authentication, while this device's APNs
    /// token is still on its way to the server, so the push may go out before there is anything
    /// to send it to. Nothing is lost when it does — `import_status` rides every response — but
    /// without asking again the calendar sits empty under a spinning indicator until the next
    /// time the app comes forward.
    ///
    /// This is `has_more` between runs rather than inside one: the server has said it is not
    /// finished, so the client asks again, which is what it does for every other unfinished
    /// answer in §5.
    private func scheduleImportPoll() {
        let next = min((importPoll ?? 0) * 2, Constants.Sync.maxImportPoll)
        let delay = max(Constants.Sync.minImportPoll, next)
        importPoll = delay

        importPollTask?.cancel()
        importPollTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.syncNow(reason: .importPoll)
        }
    }

    private func cancelImportPoll() {
        importPollTask?.cancel()
        importPollTask = nil
        importPoll = nil
    }

    private func scheduleRetry(after delay: TimeInterval) {
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.syncNow(reason: .retry)
        }
    }
}
