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
    /// The one `user_profile` row, or `nil` when the table is still empty. Only the re-read after
    /// a failed settings write needs it — everything else watches the observation.
    func fetchUserProfile() async throws -> UserProfileRecord?

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
    /// It is the only local writer of `user_profile`, and therefore the only thing that can
    /// create the row outside a pull: nothing but a sync run has ever written it (§3.1), so a
    /// user who edits their cycle length before the first run lands has no row to edit. What it
    /// creates carries `sync_state`'s owner if there is one and no identity at all if there is
    /// not — `user_id`, `email` and `phone_number` are the server's to fill in (§4.4), and the
    /// next pull does exactly that.
    func updateCycleSettings(_ patch: CycleSettingsPatch) async throws

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
