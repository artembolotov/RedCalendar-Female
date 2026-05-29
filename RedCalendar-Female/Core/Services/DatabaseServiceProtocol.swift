import Foundation
import GRDB

protocol DatabaseServiceProtocol {
    // Fetch
    func fetchCycles() throws -> [CycleRecord]
    func fetchUserTags() throws -> [UserTagRecord]
    func fetchComments(in range: ClosedRange<Int>) throws -> [CommentRecord]
    func fetchDayTags(in range: ClosedRange<Int>) throws -> [DayTagsRecord]

    // Upsert
    func upsert(_ cycles: [CycleRecord]) throws
    func upsert(_ comments: [CommentRecord]) throws
    func upsert(_ userTags: [UserTagRecord]) throws
    func upsert(_ dayTags: [DayTagsRecord]) throws

    // Delete
    func deleteCycle(startDay: Int) throws

    // Sync
    func lastSyncTimestamp() throws -> Int?

    // Observations
    func observeCycles(onChange: @escaping ([CycleRecord]) -> Void) -> AnyDatabaseCancellable
    func observeUserTags(onChange: @escaping ([UserTagRecord]) -> Void) -> AnyDatabaseCancellable
    func observeComments(in range: ClosedRange<Int>, onChange: @escaping ([CommentRecord]) -> Void) -> AnyDatabaseCancellable
    func observeDayTags(in range: ClosedRange<Int>, onChange: @escaping ([DayTagsRecord]) -> Void) -> AnyDatabaseCancellable
}
