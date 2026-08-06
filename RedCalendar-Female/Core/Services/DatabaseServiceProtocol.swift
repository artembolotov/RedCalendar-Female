import Foundation
import GRDB

/// Every SQLite call here is `async` and `nonisolated`: a caller waits for its transaction without
/// blocking a thread on it, and the wait itself does not occupy the main actor. `async` alone
/// would not give the second half — under the module's main-actor default an unmarked `async`
/// method resumes on the main actor.
///
/// The observations go the other way — started on the main actor and delivering there. An
/// `AnyDatabaseCancellable` is shared mutable state whose `deinit` cancels the observation, so
/// whoever holds one has to be isolated; the main actor is the natural place, since the values
/// are headed for the store anyway. That split is the whole reason this protocol says `nonisolated`
/// at the top and `@MainActor` on four methods, rather than either one everywhere.
nonisolated protocol DatabaseServiceProtocol: Sendable {
    // Fetch
    func fetchCycles() async throws -> [CycleRecord]
    func fetchUserTags() async throws -> [UserTagRecord]
    func fetchComments(in range: ClosedRange<Daystamp>) async throws -> [CommentRecord]
    func fetchDayTags(in range: ClosedRange<Daystamp>) async throws -> [DayTagsRecord]

    // Upsert
    func upsert(_ cycles: [CycleRecord]) async throws
    func upsert(_ comments: [CommentRecord]) async throws
    func upsert(_ userTags: [UserTagRecord]) async throws
    func upsert(_ dayTags: [DayTagsRecord]) async throws

    // Delete
    func deleteCycle(startDay: Daystamp) async throws

    // Sync
    func lastSyncTimestamp() async throws -> Int?

    // Observations
    @MainActor
    func observeCycles(onChange: @escaping @MainActor ([CycleRecord]) -> Void) -> AnyDatabaseCancellable

    @MainActor
    func observeUserTags(onChange: @escaping @MainActor ([UserTagRecord]) -> Void) -> AnyDatabaseCancellable

    @MainActor
    func observeComments(
        in range: ClosedRange<Daystamp>,
        onChange: @escaping @MainActor ([CommentRecord]) -> Void
    ) -> AnyDatabaseCancellable

    @MainActor
    func observeDayTags(
        in range: ClosedRange<Daystamp>,
        onChange: @escaping @MainActor ([DayTagsRecord]) -> Void
    ) -> AnyDatabaseCancellable
}
