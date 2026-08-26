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

        // The local half of the sync spec (SYNC.md §3.1): a dirty marker on every syncable
        // table, the day-keyed `flow_levels` a cycle's dictionary is unpacked into (§3.4), and
        // the two singleton rows a sync run keeps its state in.
        //
        // `updated_at` and `cycles.flow_levels` stay as columns and leave the Swift structs.
        // GRDB writes only the fields a record declares, so a column nobody mentions costs
        // nothing — and rebuilding four tables to be rid of them would be the expensive way to
        // change nothing. `cycles.flow_levels` is `NOT NULL DEFAULT '{}'`, so an insert that no
        // longer names it still satisfies the constraint.
        migrator.registerMigration("v3_sync_storage") { db in
            for table in ["cycles", "user_tags", "comments", "day_tags"] {
                try db.alter(table: table) { t in
                    t.add(column: "dirty_seq", .integer)
                }
            }

            try db.create(table: "flow_levels") { t in
                t.column("day_number", .integer).notNull().primaryKey()
                t.column("level", .integer)
                t.column("dirty_seq", .integer)
            }

            try db.create(table: "user_profile") { t in
                t.column("id", .integer).notNull().primaryKey()
                t.column("user_id", .text)
                t.column("name", .text)
                t.column("email", .text)
                t.column("phone_number", .text)
                t.column("settings_json", .text)
                t.column("dirty_seq", .integer)
            }

            try db.create(table: "sync_state") { t in
                t.column("id", .integer).notNull().primaryKey()
                t.column("user_id", .text)
                t.column("cursor", .integer).notNull().defaults(to: 0)
                t.column("local_seq", .integer).notNull().defaults(to: 0)
                t.column("import_status", .text)
                t.column("known_tables", .text).notNull()
            }

            // Raw SQL rather than a pass over `CycleRecord`: a migration that has already run on
            // someone's device must never change meaning, and the struct it would have decoded
            // through loses `flowLevels` in this same commit — the same reason
            // `v2_tag_category_not_null` above backfills a literal `0`.
            //
            // One day can appear in two cycles' dictionaries: the keys were windowed on read,
            // never on write. The later cycle wins, which is what `ORDER BY start_day` in front
            // of the upsert says.
            try db.execute(sql: """
                INSERT INTO flow_levels (day_number, level, dirty_seq)
                SELECT CAST(f.key AS INTEGER), CAST(f.value AS INTEGER), 1
                FROM cycles, json_each(cycles.flow_levels) AS f
                WHERE json_valid(cycles.flow_levels) AND f.value IS NOT NULL
                ORDER BY cycles.start_day
                ON CONFLICT(day_number) DO UPDATE SET level = excluded.level
                """)

            // Everything already on this device is unsent by definition — nothing has ever been
            // pushed anywhere — so it all carries the first generation. The rows written just
            // above carry it already.
            for table in ["cycles", "user_tags", "comments", "day_tags"] {
                try db.execute(sql: "UPDATE \(table) SET dirty_seq = 1")
            }

            // The table set is a literal, and has to be: read from a constant it would grow with
            // the build, and the check this row exists for — code set wider than the stored one
            // orders a full resync (§4.6) — could then never fire. `profile` is in it because a
            // sync run treats it as a sixth stream (§5.1).
            try db.execute(sql: """
                INSERT INTO sync_state (id, user_id, cursor, local_seq, import_status, known_tables)
                VALUES (1, NULL, 0, 1, NULL, '["comments","cycles","day_tags","flow_levels","profile","user_tags"]')
                """)
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

    func upsert(_ cycles: [CycleRecord]) async throws { try await upsertStamped(cycles) }
    func upsert(_ flowLevels: [FlowLevelRecord]) async throws { try await upsertStamped(flowLevels) }
    func upsert(_ comments: [CommentRecord]) async throws { try await upsertStamped(comments) }
    func upsert(_ userTags: [UserTagRecord]) async throws { try await upsertStamped(userTags) }
    func upsert(_ dayTags: [DayTagsRecord]) async throws { try await upsertStamped(dayTags) }

    /// Every local write stamps the rows it touched with a fresh generation, in the same
    /// transaction that produced it (SYNC.md §5.4).
    ///
    /// Same transaction is the whole point, not tidiness: an edit made while a sync run is in
    /// flight has to come out carrying a generation *higher* than the one that run reported
    /// sending, or the run clears its flag on the way back and the edit is never pushed. Reading
    /// the counter anywhere but here leaves exactly that gap.
    private func upsertStamped<T: DirtyStamped>(_ records: [T]) async throws {
        try await dbQueue.write { db in
            let seq = try Self.nextLocalSeq(db)
            for record in records {
                var stamped = record
                stamped.dirtySeq = seq
                try stamped.upsert(db)
            }
        }
    }

    /// Bumped and read inside the caller's transaction — see `upsertStamped`. Two statements
    /// rather than `UPDATE ... RETURNING`, which needs SQLite 3.35 and buys nothing here.
    private static func nextLocalSeq(_ db: Database) throws -> Int {
        try db.execute(sql: "UPDATE sync_state SET local_seq = local_seq + 1 WHERE id = 1")
        guard let seq = try Int.fetchOne(db, sql: "SELECT local_seq FROM sync_state WHERE id = 1") else {
            throw DatabaseError(message: "sync_state row is missing — the v3 migration did not run")
        }
        return seq
    }

    // MARK: - Observations

    // All five observations start on the main actor and deliver there: this is
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
    func observeFlowLevels(
        in range: ClosedRange<Daystamp>,
        onChange: @escaping @MainActor @Sendable ([FlowLevelRecord]) -> Void
    ) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try FlowLevelRecord
                .filter(range.contains(FlowLevelRecord.Columns.dayNumber))
                .filter(FlowLevelRecord.Columns.level != nil)
                .fetchAll(db)
        }.removeDuplicates()

        return observation.start(
            in: dbQueue,
            onError: { error in
                AppLogger.error("FlowLevels observation failed", error: error)
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

    /// Whole, like the two permanent observations above rather than the three ranged ones: it's
    /// a singleton row, not something a viewport windows.
    @MainActor
    func observeUserProfile(onChange: @escaping @MainActor @Sendable (UserProfileRecord?) -> Void) -> AnyDatabaseCancellable {
        let observation = ValueObservation.tracking { db in
            try UserProfileRecord.fetchOne(db)
        }.removeDuplicates()

        return observation.start(
            in: dbQueue,
            onError: { error in
                AppLogger.error("UserProfile observation failed", error: error)
            },
            onChange: onChange
        )
    }
}
