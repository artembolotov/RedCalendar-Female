import Foundation
import GRDB

final class DatabaseService: DatabaseServiceProtocol {
    private let dbQueue: DatabaseQueue

    init() throws {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbURL = appSupportURL.appendingPathComponent("redcalendar.sqlite")
        dbQueue = try DatabaseQueue(path: dbURL.path)

        try Self.runMigrations(dbQueue)

        AppLogger.info("DatabaseService initialized at \(dbURL.path)")
    }

    // MARK: - Migrations

    private static func runMigrations(_ dbQueue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "cycles") { t in
                t.column("start_day", .integer).notNull().primaryKey()
                t.column("period_length", .integer)
                t.column("ovulation", .text)
                t.column("flow_levels", .text).notNull().defaults(to: "{}")
                t.column("updated_at", .integer)
            }

            try db.create(table: "user_tags") { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("name", .text)
                t.column("category", .integer)
                t.column("updated_at", .integer)
            }

            try db.create(table: "comments") { t in
                t.column("day_number", .integer).notNull().primaryKey()
                t.column("comment", .text)
                t.column("updated_at", .integer)
            }

            try db.create(table: "day_tags") { t in
                t.column("day_number", .integer).notNull().primaryKey()
                t.column("tag_ids", .text).notNull().defaults(to: "[]")
                t.column("updated_at", .integer)
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Fetch

    func fetchCycles() throws -> [CycleRecord] {
        try dbQueue.read { db in
            try CycleRecord
                .filter(CycleRecord.Columns.periodLength != nil)
                .fetchAll(db)
        }
    }

    func fetchUserTags() throws -> [UserTagRecord] {
        try dbQueue.read { db in
            try UserTagRecord
                .filter(UserTagRecord.Columns.name != nil)
                .fetchAll(db)
        }
    }

    func fetchComments(in range: ClosedRange<Daystamp>) throws -> [CommentRecord] {
        try dbQueue.read { db in
            try CommentRecord
                .filter(range.contains(CommentRecord.Columns.dayNumber))
                .filter(CommentRecord.Columns.comment != nil)
                .fetchAll(db)
        }
    }

    func fetchDayTags(in range: ClosedRange<Daystamp>) throws -> [DayTagsRecord] {
        try dbQueue.read { db in
            try DayTagsRecord
                .filter(range.contains(DayTagsRecord.Columns.dayNumber))
                .fetchAll(db)
        }
    }

    // MARK: - Upsert

    func upsert(_ cycles: [CycleRecord]) throws {
        try dbQueue.write { db in
            for cycle in cycles {
                try cycle.upsert(db)
            }
        }
    }

    func upsert(_ comments: [CommentRecord]) throws {
        try dbQueue.write { db in
            for comment in comments {
                try comment.upsert(db)
            }
        }
    }

    func upsert(_ userTags: [UserTagRecord]) throws {
        try dbQueue.write { db in
            for tag in userTags {
                try tag.upsert(db)
            }
        }
    }

    func upsert(_ dayTags: [DayTagsRecord]) throws {
        try dbQueue.write { db in
            for dayTag in dayTags {
                try dayTag.upsert(db)
            }
        }
    }

    // MARK: - Delete

    func deleteCycle(startDay: Daystamp) throws {
        _ = try dbQueue.write { db in
            try CycleRecord
                .filter(CycleRecord.Columns.startDay == startDay)
                .deleteAll(db)
        }
    }

    // MARK: - Sync

    func lastSyncTimestamp() throws -> Int? {
        try dbQueue.read { db in
            let cyclesMax = try Int.fetchOne(db, sql: "SELECT MAX(updated_at) FROM cycles")
            let userTagsMax = try Int.fetchOne(db, sql: "SELECT MAX(updated_at) FROM user_tags")
            let commentsMax = try Int.fetchOne(db, sql: "SELECT MAX(updated_at) FROM comments")
            let dayTagsMax = try Int.fetchOne(db, sql: "SELECT MAX(updated_at) FROM day_tags")
            return [cyclesMax, userTagsMax, commentsMax, dayTagsMax].compactMap { $0 }.max()
        }
    }

    // MARK: - Observations

    func observeCycles(onChange: @escaping ([CycleRecord]) -> Void) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try CycleRecord
                .filter(CycleRecord.Columns.periodLength != nil)
                .fetchAll(db)
        }.removeDuplicates()

        return observation.start(
            in: dbQueue,
            scheduling: .async(onQueue: .main),
            onError: { error in
                AppLogger.error("Cycles observation failed", error: error)
            },
            onChange: onChange
        )
    }

    func observeUserTags(onChange: @escaping ([UserTagRecord]) -> Void) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try UserTagRecord
                .filter(UserTagRecord.Columns.name != nil)
                .fetchAll(db)
        }.removeDuplicates()

        return observation.start(
            in: dbQueue,
            scheduling: .async(onQueue: .main),
            onError: { error in
                AppLogger.error("UserTags observation failed", error: error)
            },
            onChange: onChange
        )
    }

    func observeComments(in range: ClosedRange<Daystamp>, onChange: @escaping ([CommentRecord]) -> Void) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try CommentRecord
                .filter(range.contains(CommentRecord.Columns.dayNumber))
                .filter(CommentRecord.Columns.comment != nil)
                .fetchAll(db)
        }.removeDuplicates()

        return observation.start(
            in: dbQueue,
            scheduling: .async(onQueue: .main),
            onError: { error in
                AppLogger.error("Comments observation failed", error: error)
            },
            onChange: onChange
        )
    }

    func observeDayTags(in range: ClosedRange<Daystamp>, onChange: @escaping ([DayTagsRecord]) -> Void) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try DayTagsRecord
                .filter(range.contains(DayTagsRecord.Columns.dayNumber))
                .fetchAll(db)
        }.removeDuplicates()

        return observation.start(
            in: dbQueue,
            scheduling: .async(onQueue: .main),
            onError: { error in
                AppLogger.error("DayTags observation failed", error: error)
            },
            onChange: onChange
        )
    }
}
