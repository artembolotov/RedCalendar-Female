import Foundation
import GRDB

/// Every SQLite call here is `async`: a caller waits for its transaction without blocking a
/// thread on it, which is what lets the consumer live on the main actor.
///
/// The observations go the other way — started on the main actor and delivering there. An
/// `AnyDatabaseCancellable` is shared mutable state whose `deinit` cancels the observation, so
/// whoever holds one has to be isolated; the main actor is the natural place, since the values
/// are headed for the store anyway.
protocol DatabaseServiceProtocol: Sendable {
    // Fetch
    func fetchCycles() async throws -> [CycleRecord]
    func fetchUserTags() async throws -> [UserTagRecord]
    func fetchComments(in range: ClosedRange<Daystamp>) async throws -> [CommentRecord]
    func fetchDayTags(in range: ClosedRange<Daystamp>) async throws -> [DayTagsRecord]

    // Upsert
    //
    // There is no delete. Every removal is a tombstone written through one of these —
    // `periodLength`, `comment`, `name` and `level` set to nil — so that the row survives to
    // tell the server, and the next pull, that it is gone (SYNC.md §3.3). Physical deletion
    // stays possible only for a wipe of the whole database.
    func upsert(_ cycles: [CycleRecord]) async throws
    func upsert(_ flowLevels: [FlowLevelRecord]) async throws
    func upsert(_ comments: [CommentRecord]) async throws
    func upsert(_ userTags: [UserTagRecord]) async throws
    func upsert(_ dayTags: [DayTagsRecord]) async throws

    /// The device's half of the profile (SYNC.md §4.4): the cycle settings, merged into the JSON
    /// the server last sent and stamped dirty in the same transaction, exactly as `upsert` stamps
    /// a day table.
    ///
    /// It is, with `updateNotificationsMuted` and `updateName` below, one of the only three local
    /// writers of `user_profile`, and therefore one of the only three things that can create the
    /// row outside a pull: nothing but a sync run wrote it before any of them existed (§3.1), so a
    /// user who edits their cycle length before the first run lands has no row to edit. What it
    /// creates carries `sync_state`'s owner if there is one and no identity at all if there is not
    /// — `user_id`, `email` and `phone_number` are the server's to fill in (§4.4), and the next
    /// pull does exactly that.
    ///
    /// Answers whether the row actually changed. The merge is the only place that can tell — it
    /// compares inside the transaction that would do the writing — and the automatic forecast
    /// recompute needs the answer to decide whether there is anything to sync (see
    /// `DatabaseMiddleware.refreshForecast`). A caller acting on the user's own tap has nothing
    /// to decide and discards it.
    @discardableResult
    func updateCycleSettings(_ patch: CycleSettingsPatch) async throws -> Bool

    /// `DatabaseMiddleware.refreshForecast`'s own writer — the same column, one transaction for
    /// all three numbers it might have to report, never split into a second call. Splitting it
    /// once (a separate `updateLutealPhaseLength`, called right after this one) meant a database
    /// error on the `cycleLength`/`periodLength` half left the luteal-phase half to run against a
    /// row that write would have created — on an account with nothing stored yet, that stray
    /// second call still created an empty `user_profile` row and asked for a sync, for a failure
    /// that had nothing to do with luteal phase. One call removes the seam: it either writes
    /// everything this run has evidence for, or (on failure) writes nothing at all, exactly as a
    /// single `updateCycleSettings` call always has.
    ///
    /// `cycleLength`/`periodLength` keep `updateCycleSettings`'s "don't touch" `nil` — protecting
    /// a value someone typed on a run that simply has nothing new to report. `lutealPhaseLength`
    /// cannot mean that, because nothing but this call ever writes it: its `nil` *clears* the key
    /// outright — `JSONValue.removingSetting(_:)`, not `setting(_:to: .null)` — back to exactly
    /// the shape the row would have if ovulation had never been confirmed at all. See
    /// `CycleForecast.lutealPhaseLength` and `CycleSettingsPatch`'s own doc comment for why it is
    /// not folded into that patch type instead — its `nil` would collide with the "don't touch"
    /// the other two fields need.
    ///
    /// Answers whether the row actually changed, for the same reason `updateCycleSettings` does.
    @discardableResult
    func updateForecast(cycleLength: Int?, periodLength: Int?, lutealPhaseLength: Int?) async throws -> Bool

    /// The same column and the same transaction shape, for the other setting a device may choose:
    /// whether this account wants notifications at all, stored as `notifications.muted` — the key
    /// RedCalendar 2.0 already wrote and the import carried over verbatim (§10.2).
    ///
    /// It answers for the *account*, not for this phone: iOS's own permission is asked separately
    /// and never written back here, so a device that has been denied at the system level leaves
    /// the person's other devices alone.
    func updateNotificationsMuted(_ muted: Bool) async throws

    /// The last of the device's writes to the profile (SYNC.md §4.4): the display name,
    /// stamped dirty in the same transaction and by the same generation counter as
    /// `updateCycleSettings` stamps the settings — the two share one row and one `dirty_seq`, and
    /// this is what lets a push tell which of them it is actually sending (see
    /// `UserProfileRecord.nameDirtySeq`).
    ///
    /// `nil` clears the name, the same tombstone shape every soft-deleted field in this app uses.
    /// Like `updateCycleSettings`, it may create the row: a user who edits their name before the
    /// first sync run lands has none to edit yet.
    func updateName(_ name: String?) async throws

    // Sync (SYNC.md §5.1)
    //
    // Four calls, and each one is a whole transaction on purpose. The run itself lives on the
    // main actor between them and must not be able to interleave a step: `sent_max` computed
    // outside the read that produced it, or a cursor moved outside the transaction that applied
    // the page, is a silently lost row rather than an error (§5.4).

    /// Step 1: read `sync_state`, and reset the cursor if this build understands more tables than
    /// the row records (§4.6). One transaction, because the reset is a write that has to be based
    /// on the value just read.
    func prepareSyncState(knownTables: Set<String>) async throws -> LocalSyncState

    /// Step 3: every dirty row of all six streams, plus the generation they carry, in one read.
    func fetchDirty() async throws -> DirtyBatch

    /// Step 7: apply pulled rows, clear the flags of what was accepted, apply the rejections, and
    /// move the cursor — in that order, in one transaction. Killed halfway, it rolls back and the
    /// next run re-reads the same page.
    func applySync(_ application: SyncApplication) async throws

    /// Step 6: `full_resync_required`, where the rest of the response is deliberately *not*
    /// applied — so this cannot be folded into `applySync`.
    func resetSyncCursor() async throws

    /// Everything the user owns, plus `sync_state` back to its initial values with `newOwner` as
    /// the user (§6). The cursor matters more than the rows: left high, it leaves an empty
    /// database that will never pull anything, because it is all "below the cursor" already.
    /// `known_tables` survives — it describes the build, not the user.
    func wipeAll(newOwner: String?) async throws

    /// The owner check of §6, run at sign-in — before the new `device_id` is saved, so that an
    /// interruption leaves either the old database with the old device or a clean one with the
    /// new. One transaction rather than a read followed by `wipeAll`: the decision to wipe has to
    /// rest on the value just read, and the run of §5 can start between the two.
    ///
    /// Returns whether the database was wiped, which is the only thing a caller can act on: an
    /// unclaimed database (`user_id` empty — a fresh install, or an upgrade from v3.2 where the
    /// row was backfilled without one) is claimed silently and keeps its rows.
    @discardableResult
    func claimOwner(_ userId: String) async throws -> Bool

    // Observations
    @MainActor
    func observeCycles(onChange: @escaping @MainActor @Sendable ([CycleRecord]) -> Void) -> AnyDatabaseCancellable

    @MainActor
    func observeUserTags(onChange: @escaping @MainActor @Sendable ([UserTagRecord]) -> Void) -> AnyDatabaseCancellable

    @MainActor
    func observeComments(
        in range: ClosedRange<Daystamp>,
        onChange: @escaping @MainActor @Sendable ([CommentRecord]) -> Void
    ) -> AnyDatabaseCancellable

    @MainActor
    func observeFlowLevels(
        in range: ClosedRange<Daystamp>,
        onChange: @escaping @MainActor @Sendable ([FlowLevelRecord]) -> Void
    ) -> AnyDatabaseCancellable

    @MainActor
    func observeDayTags(
        in range: ClosedRange<Daystamp>,
        onChange: @escaping @MainActor @Sendable ([DayTagsRecord]) -> Void
    ) -> AnyDatabaseCancellable

    @MainActor
    func observeUserProfile(onChange: @escaping @MainActor @Sendable (UserProfileRecord?) -> Void) -> AnyDatabaseCancellable
}
