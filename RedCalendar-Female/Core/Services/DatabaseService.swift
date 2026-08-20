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

        // A tag has always had a category in every build that could make one — the creation form
        // starts on the first swatch and there is no way to clear it — but `v1_initial` let the
        // column be NULL, and `UserTagRecord.category` was optional to match. It is not optional
        // any more: a tag without a category has no colour, so it has nothing to draw as on the
        // day's dots or in the picker.
        //
        // SQLite cannot add NOT NULL to an existing column, so the table is rebuilt. The
        // backfill is a literal 0 rather than `TagCategory.fallback.rawValue`: a migration that
        // has already run somewhere must never change meaning, and a constant can be edited.
        migrator.registerMigration("v2_tag_category_not_null") { db in
            try db.execute(sql: "UPDATE user_tags SET category = 0 WHERE category IS NULL")

            try db.create(table: "user_tags_new") { t in
                t.column("id", .text).notNull().primaryKey()
                t.column("name", .text)
                t.column("category", .integer).notNull()
                t.column("updated_at", .integer)
            }
            try db.execute(sql: """
                INSERT INTO user_tags_new (id, name, category, updated_at)
                SELECT id, name, category, updated_at FROM user_tags
                """)
            try db.drop(table: "user_tags")
            try db.rename(table: "user_tags_new", to: "user_tags")
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Fetch

    func fetchCycles() async throws -> [CycleRecord] {
        try await dbQueue.read { db in
            try CycleRecord
                .filter(CycleRecord.Columns.periodLength != nil)
                .fetchAll(db)
        }
    }

    func fetchUserTags() async throws -> [UserTagRecord] {
        try await dbQueue.read { db in
            try UserTagRecord
                .filter(UserTagRecord.Columns.name != nil)
                .fetchAll(db)
        }
    }

    func fetchComments(in range: ClosedRange<Daystamp>) async throws -> [CommentRecord] {
        try await dbQueue.read { db in
            try CommentRecord
                .filter(range.contains(CommentRecord.Columns.dayNumber))
                .filter(CommentRecord.Columns.comment != nil)
                .fetchAll(db)
        }
    }

    func fetchDayTags(in range: ClosedRange<Daystamp>) async throws -> [DayTagsRecord] {
        try await dbQueue.read { db in
            try DayTagsRecord
                .filter(range.contains(DayTagsRecord.Columns.dayNumber))
                .fetchAll(db)
        }
    }

    // MARK: - Upsert

    func upsert(_ cycles: [CycleRecord]) async throws {
        try await dbQueue.write { db in
            for cycle in cycles {
                try cycle.upsert(db)
            }
        }
    }

    func upsert(_ comments: [CommentRecord]) async throws {
        try await dbQueue.write { db in
            for comment in comments {
                try comment.upsert(db)
            }
        }
    }

    func upsert(_ userTags: [UserTagRecord]) async throws {
        try await dbQueue.write { db in
            for tag in userTags {
                try tag.upsert(db)
            }
        }
    }

    func upsert(_ dayTags: [DayTagsRecord]) async throws {
        try await dbQueue.write { db in
            for dayTag in dayTags {
                try dayTag.upsert(db)
            }
        }
    }

    // MARK: - Delete

    func deleteCycle(startDay: Daystamp) async throws {
        _ = try await dbQueue.write { db in
            try CycleRecord
                .filter(CycleRecord.Columns.startDay == startDay)
                .deleteAll(db)
        }
    }

    // MARK: - Sync

    func lastSyncTimestamp() async throws -> Int? {
        try await dbQueue.read { db in
            let cyclesMax = try Int.fetchOne(db, sql: "SELECT MAX(updated_at) FROM cycles")
            let userTagsMax = try Int.fetchOne(db, sql: "SELECT MAX(updated_at) FROM user_tags")
            let commentsMax = try Int.fetchOne(db, sql: "SELECT MAX(updated_at) FROM comments")
            let dayTagsMax = try Int.fetchOne(db, sql: "SELECT MAX(updated_at) FROM day_tags")
            return [cyclesMax, userTagsMax, commentsMax, dayTagsMax].compactMap { $0 }.max()
        }
    }

    // MARK: - Observations

    // All four observations start on the main actor and deliver there: this is
    // `ValueObservation.start`'s `@MainActor` overload, whose default `.mainActor` scheduler is
    // the same `DispatchQueue.main` delivery as before — the difference is that the compiler now
    // checks it instead of the caller assuming it.

    @MainActor
    func observeCycles(onChange: @escaping @MainActor @Sendable ([CycleRecord]) -> Void) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try CycleRecord
                .filter(CycleRecord.Columns.periodLength != nil)
                .fetchAll(db)
        }.removeDuplicates()

        return observation.start(
            in: dbQueue,
            onError: { error in
                AppLogger.error("Cycles observation failed", error: error)
            },
            onChange: onChange
        )
    }

    @MainActor
    func observeUserTags(onChange: @escaping @MainActor @Sendable ([UserTagRecord]) -> Void) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try UserTagRecord
                .filter(UserTagRecord.Columns.name != nil)
                .fetchAll(db)
        }.removeDuplicates()

        return observation.start(
            in: dbQueue,
            onError: { error in
                AppLogger.error("UserTags observation failed", error: error)
            },
            onChange: onChange
        )
    }

    @MainActor
    func observeComments(
        in range: ClosedRange<Daystamp>,
        onChange: @escaping @MainActor @Sendable ([CommentRecord]) -> Void
    ) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try CommentRecord
                .filter(range.contains(CommentRecord.Columns.dayNumber))
                .filter(CommentRecord.Columns.comment != nil)
                .fetchAll(db)
        }.removeDuplicates()

        return observation.start(
            in: dbQueue,
            onError: { error in
                AppLogger.error("Comments observation failed", error: error)
            },
            onChange: onChange
        )
    }

    @MainActor
    func observeDayTags(
        in range: ClosedRange<Daystamp>,
        onChange: @escaping @MainActor @Sendable ([DayTagsRecord]) -> Void
    ) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try DayTagsRecord
                .filter(range.contains(DayTagsRecord.Columns.dayNumber))
                .fetchAll(db)
        }.removeDuplicates()

        return observation.start(
            in: dbQueue,
            onError: { error in
                AppLogger.error("DayTags observation failed", error: error)
            },
            onChange: onChange
        )
    }
}
