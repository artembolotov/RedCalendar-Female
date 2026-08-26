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
