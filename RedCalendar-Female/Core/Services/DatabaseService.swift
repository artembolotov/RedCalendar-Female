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

        // Adds the second half of the device's-write tracking on `user_profile`: `dirty_seq`
        // alone said "the row has an unsent local edit", which was enough while the only local
        // writer was `updateCycleSettings`. `updateName` shares that same row and that same
        // column, so a settings-only edit and a name edit are indistinguishable by `dirty_seq`
        // alone — and `SyncProfilePush(_:)` has to tell them apart, or a settings-only push would
        // resend (or, worse, on a profile never pulled, erase) a name nobody touched.
        migrator.registerMigration("v4_profile_name_dirty") { db in
            try db.alter(table: "user_profile") { t in
                t.add(column: "name_dirty_seq", .integer)
            }
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

    /// One of the two local writes to `user_profile` — the settings half — and, with `updateName`
    /// below, one of the two places other than a pull that may create its row. See the protocol
    /// for why either may have to.
    ///
    /// The settings are *merged* into the stored JSON rather than rebuilt from `UserSettings`:
    /// the column holds what the server sent, character for character in meaning, and a key this
    /// build does not model would otherwise be dropped here and erased on the server by the very
    /// next push (SYNC.md §15).
    func updateCycleSettings(_ patch: CycleSettingsPatch) async throws {
        try await dbQueue.write { db in
            // The first row rather than the row keyed 1, which is how the observation reads it:
            // the two must never disagree about which row is "the" profile.
            let existing = try UserProfileRecord.fetchOne(db)
            let owner = try String.fetchOne(db, sql: "SELECT user_id FROM sync_state WHERE id = 1")

            var record = existing ?? UserProfileRecord(
                id: 1,
                userId: owner,
                name: nil,
                email: nil,
                phoneNumber: nil,
                settingsJSON: nil,
                dirtySeq: nil
            )

            let stored = JSONValue(jsonString: record.settingsJSON) ?? .object([:])
            var merged = stored
            if let cycleLength = patch.cycleLength {
                merged = merged.setting(["cycle", "default_length"], to: .int(cycleLength))
            }
            if let periodLength = patch.periodLength {
                merged = merged.setting(["cycle", "default_period_length"], to: .int(periodLength))
            }

            // An edit that lands on the value already stored is not an edit, and writing it
            // anyway is not free: it stamps the row dirty, asks for a sync run, and spends a
            // server revision that every *other* device then pulls. Tapping + and back to − is
            // enough to cause it. Compared as values rather than as strings — two encodings of
            // the same settings are the same settings.
            if existing != nil, merged == stored { return }

            record.settingsJSON = merged.jsonString
            record.dirtySeq = try Self.nextLocalSeq(db)
            try record.upsert(db)
        }
    }

    /// The other local write to `user_profile` — the name half, and `AccountView`'s write path.
    /// Stamps `nameDirtySeq` to the same generation as `dirtySeq`, in the same transaction: that
    /// is what lets `SyncProfilePush(_:)` tell a name edit apart from a settings-only one sharing
    /// the same row, and what lets the two be cleared by the same `sentMax` a push confirms (see
    /// `applySync`).
    ///
    /// `name == nil` is this table's tombstone, the same as every other soft-deleted field
    /// (`periodLength`, `comment`, `UserTagRecord.name`) — a field cleared back to empty is stored
    /// this way, not as `""`, and `SyncProfilePush(_:)` turns it into the real `.some(nil)` erase.
    func updateName(_ name: String?) async throws {
        try await dbQueue.write { db in
            let existing = try UserProfileRecord.fetchOne(db)
            let owner = try String.fetchOne(db, sql: "SELECT user_id FROM sync_state WHERE id = 1")

            var record = existing ?? UserProfileRecord(
                id: 1,
                userId: owner,
                name: nil,
                email: nil,
                phoneNumber: nil,
                settingsJSON: nil,
                dirtySeq: nil
            )

            // `existing != nil` is *not* the guard `updateCycleSettings` uses on its own field —
            // deliberately narrower. A patch always carries a real chosen value, so creating the
            // row on a first edit is always correct there; `nil` here is also the tombstone, so
            // `existing == nil, name == nil` is not "first edit", it is "nothing to edit yet",
            // and creating a dirty row for it would be the exact hazard `nameDirtySeq` exists to
            // prevent: a push reading that row's `name` back out as `nil` would encode it as
            // `.some(nil)` — an erase — for a device that has never pulled a real name to erase.
            // Comparing straight against `existing?.name` (itself `nil` when there is no row)
            // covers both "no row, no name" and "row exists, unchanged" in one guard, so this
            // holds even if a future caller forgets the check `AccountView.commitDraft` makes.
            guard name != existing?.name else { return }

            let seq = try Self.nextLocalSeq(db)
            record.name = name
            record.dirtySeq = seq
            record.nameDirtySeq = seq
            try record.upsert(db)
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

    // MARK: - Sync

    // The four transactions of SYNC.md §5.1. Each is whole because the run between them lives on
    // the main actor and gives it up at every `await`: a step split in two is a window for a
    // local edit to land in, and every one of those windows loses a row without saying so.

    func prepareSyncState(knownTables: Set<String>) async throws -> LocalSyncState {
        try await dbQueue.write { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT user_id, cursor, import_status, known_tables FROM sync_state WHERE id = 1"
            ) else {
                throw DatabaseError(message: "sync_state row is missing — the v3 migration did not run")
            }

            let userId: String? = row["user_id"]
            var cursor: Int = row["cursor"]
            let importStatus: String? = row["import_status"]
            let storedJSON: String = row["known_tables"]
            let stored = Set(
                (try? JSONDecoder().decode([String].self, from: Data(storedJSON.utf8))) ?? []
            )

            // Wider in code than in the row means this build understands a table the one that
            // wrote the row did not — and that table's rows are all below the stored cursor,
            // where they would stay forever (§4.6). A full resync is idempotent, so the fix is
            // one extra pass per upgrade. A *narrower* code set is a downgrade and rewrites
            // nothing: overwrite the row here and re-upgrading would no longer notice anything.
            if !knownTables.subtracting(stored).isEmpty {
                cursor = 0
                let encoded = try String(
                    data: JSONEncoder().encode(knownTables.sorted()),
                    encoding: .utf8
                ) ?? storedJSON
                try db.execute(
                    sql: "UPDATE sync_state SET cursor = 0, known_tables = ? WHERE id = 1",
                    arguments: [encoded]
                )
                AppLogger.info("Sync: known_tables grew — full resync ordered")
            }

            return LocalSyncState(userId: userId, cursor: cursor, importStatus: importStatus)
        }
    }

    func fetchDirty() async throws -> DirtyBatch {
        try await dbQueue.read { db in
            var batch = DirtyBatch()
            batch.cycles = try CycleRecord.filter(CycleRecord.Columns.dirtySeq != nil).fetchAll(db)
            batch.flowLevels = try FlowLevelRecord.filter(FlowLevelRecord.Columns.dirtySeq != nil).fetchAll(db)
            batch.comments = try CommentRecord.filter(CommentRecord.Columns.dirtySeq != nil).fetchAll(db)
            batch.userTags = try UserTagRecord.filter(UserTagRecord.Columns.dirtySeq != nil).fetchAll(db)
            batch.dayTags = try DayTagsRecord.filter(DayTagsRecord.Columns.dirtySeq != nil).fetchAll(db)
            batch.profile = try UserProfileRecord.filter(UserProfileRecord.Columns.dirtySeq != nil).fetchOne(db)

            // Over the rows just read, inside the same transaction that read them — never a
            // separate `SELECT MAX(dirty_seq)`. A write landing between the two would be counted
            // as sent and have its flag cleared on the way back, which is the exact loss the
            // column exists to prevent (§5.4).
            let generations = batch.cycles.compactMap(\.dirtySeq)
                + batch.flowLevels.compactMap(\.dirtySeq)
                + batch.comments.compactMap(\.dirtySeq)
                + batch.userTags.compactMap(\.dirtySeq)
                + batch.dayTags.compactMap(\.dirtySeq)
                + [batch.profile?.dirtySeq].compactMap { $0 }
            batch.sentMax = generations.max()

            return batch
        }
    }

    func applySync(_ application: SyncApplication) async throws {
        try await dbQueue.write { db in
            // 7.1 — pulled rows, skipping every key that has a local edit waiting. Nothing is
            // lost by the skip: that edit goes out on the next round and wins there, because push
            // runs before pull. A key with no local row cannot be dirty, so it always applies.
            if let changes = application.changes {
                try Self.applyPulled(changes, userId: application.userId, db: db)
            }

            // 7.2 — clear what the server accepted, and only up to the generation this run
            // actually sent. An edit made while the request was in flight carries a higher one
            // and survives. Skipped entirely when nothing was sent: `sentMax` is nil then, and
            // "clear every flag" would declare the whole backfilled history pushed (§5.1).
            if let sentMax = application.sentMax {
                for table in Self.syncedTables {
                    try db.execute(
                        sql: "UPDATE \(table) SET dirty_seq = NULL WHERE dirty_seq <= ?",
                        arguments: [sentMax]
                    )
                }

                // `user_profile`'s second flag, cleared by the same threshold: `nameDirtySeq` is
                // always `<= dirtySeq` (both are stamped together, in `updateName`, from the same
                // counter), so whatever `sentMax` already clears above also covers whatever this
                // clears here. A name edit that lands while this request is still in flight stamps
                // a fresh, higher generation and survives exactly as an unsent `dirty_seq` does.
                try db.execute(
                    sql: "UPDATE user_profile SET name_dirty_seq = NULL WHERE name_dirty_seq <= ?",
                    arguments: [sentMax]
                )
            }

            // 7.3 — the server's word on rows it refused, applied last and unconditionally. This
            // is the one place a local edit is overwritten while still dirty: the server has
            // already said it will not take that row, and it will not take a second copy of it
            // either (§5.1).
            for rejection in application.rejected {
                try Self.applyRejection(rejection, userId: application.userId, db: db)
            }

            // 7.4 — the cursor moves only here, inside the transaction that applied the page.
            // `user_id` is claimed only if the row has none: a mismatch is handled a step earlier,
            // by wiping (§5.1 step 5), and must not be quietly overwritten here.
            try db.execute(
                sql: """
                    UPDATE sync_state
                       SET cursor = ?,
                           user_id = COALESCE(user_id, ?),
                           import_status = COALESCE(?, import_status)
                     WHERE id = 1
                    """,
                arguments: [application.nextCursor, application.userId, application.importStatus]
            )
        }
    }

    func resetSyncCursor() async throws {
        try await dbQueue.write { db in
            try db.execute(sql: "UPDATE sync_state SET cursor = 0 WHERE id = 1")
        }
    }

    func wipeAll(newOwner: String?) async throws {
        try await dbQueue.write { db in
            try Self.wipe(db, newOwner: newOwner)
        }
        AppLogger.info("Local database wiped")
    }

    func claimOwner(_ userId: String) async throws -> Bool {
        let wiped = try await dbQueue.write { db -> Bool in
            let owner = try String.fetchOne(db, sql: "SELECT user_id FROM sync_state WHERE id = 1")

            // Someone else's rows. They are wiped before the new device_id is saved, so that
            // nothing of theirs can be pushed into this account (§6).
            if let owner, owner != userId {
                try Self.wipe(db, newOwner: userId)
                return true
            }

            try db.execute(
                sql: "UPDATE sync_state SET user_id = ? WHERE id = 1",
                arguments: [userId]
            )
            return false
        }

        if wiped {
            AppLogger.info("Local database wiped: it belonged to another user")
        }
        return wiped
    }

    private static func wipe(_ db: Database, newOwner: String?) throws {
        for table in syncedTables {
            try db.execute(sql: "DELETE FROM \(table)")
        }
        // `known_tables` is deliberately not touched — it describes this build, not this user.
        try db.execute(
            sql: """
                UPDATE sync_state
                   SET user_id = ?, cursor = 0, local_seq = 0, import_status = NULL
                 WHERE id = 1
                """,
            arguments: [newOwner]
        )
    }

    /// Everything a wipe empties and step 7.2 unflags. `sync_state` is not one of them: it is
    /// reset rather than emptied, and it carries the flags' counter.
    private static let syncedTables = [
        "cycles", "flow_levels", "comments", "user_tags", "day_tags", "user_profile"
    ]

    private static func applyPulled(_ changes: SyncChangesPull, userId: String?, db: Database) throws {
        let dirtyCycles = Set(try Int.fetchAll(db, sql: "SELECT start_day FROM cycles WHERE dirty_seq IS NOT NULL"))
        for row in changes.cycles where !dirtyCycles.contains(row.startDay.rawValue) {
            try row.record.upsert(db)
        }

        let dirtyFlow = Set(try Int.fetchAll(db, sql: "SELECT day_number FROM flow_levels WHERE dirty_seq IS NOT NULL"))
        for row in changes.flowLevels where !dirtyFlow.contains(row.dayNumber.rawValue) {
            try row.record.upsert(db)
        }

        let dirtyComments = Set(try Int.fetchAll(db, sql: "SELECT day_number FROM comments WHERE dirty_seq IS NOT NULL"))
        for row in changes.comments where !dirtyComments.contains(row.dayNumber.rawValue) {
            try row.record.upsert(db)
        }

        let dirtyUserTags = Set(try String.fetchAll(db, sql: "SELECT id FROM user_tags WHERE dirty_seq IS NOT NULL"))
        for row in changes.userTags where !dirtyUserTags.contains(row.id) {
            try row.record.upsert(db)
        }

        let dirtyDayTags = Set(try Int.fetchAll(db, sql: "SELECT day_number FROM day_tags WHERE dirty_seq IS NOT NULL"))
        for row in changes.dayTags where !dirtyDayTags.contains(row.dayNumber.rawValue) {
            try row.record.upsert(db)
        }

        // The profile is two halves with different owners (§4.4), and the dirty flag speaks for
        // only one of them. `name` and `settings` are the device's, so a local edit waiting to go
        // out holds them back exactly as it does in every table above. `user_id`, `email` and
        // `phone_number` are the server's alone — a device never writes them — so they are
        // applied whatever the flag says.
        //
        // Holding those back too would strand the device that edited its cycle settings before
        // the profile had ever been pulled: this response is the only one that will ever carry
        // that revision, `next_cursor` moves past it, `profile_revision > since` never matches
        // again, and the row keeps no identity at all.
        if let profile = changes.profile {
            if try Self.isProfileDirty(db) {
                try db.execute(
                    sql: """
                        UPDATE user_profile
                           SET user_id = COALESCE(?, user_id),
                               email = ?,
                               phone_number = ?
                         WHERE id = 1
                        """,
                    arguments: [userId, profile.email, profile.phoneNumber]
                )
            } else {
                try profile.record(userId: userId ?? Self.profileOwner(db)).upsert(db)
            }
        }
    }

    private static func applyRejection(_ rejection: SyncRejection, userId: String?, db: Database) throws {
        if let row = rejection.row {
            switch row {
            case .cycle(let value): try value.record.upsert(db)
            case .flowLevel(let value): try value.record.upsert(db)
            case .comment(let value): try value.record.upsert(db)
            case .userTag(let value): try value.record.upsert(db)
            case .dayTags(let value): try value.record.upsert(db)
            case .profile(let value): try value.record(userId: userId ?? Self.profileOwner(db)).upsert(db)
            }
            return
        }

        // No authoritative row means the server has nothing under that key, so neither should we.
        // This is the only physical delete outside a wipe (§3.3 says removals are tombstones) and
        // it is not an exception to the rule so much as its endpoint: a row the server does not
        // acknowledge has nobody left to tell.
        guard let table = rejection.table else {
            AppLogger.warn("Sync: a rejection names a table this build does not know")
            return
        }
        switch table {
        case .cycles:
            if let key = rejection.key?.intValue {
                try db.execute(sql: "DELETE FROM cycles WHERE start_day = ?", arguments: [key])
            }
        case .flowLevels:
            if let key = rejection.key?.intValue {
                try db.execute(sql: "DELETE FROM flow_levels WHERE day_number = ?", arguments: [key])
            }
        case .comments:
            if let key = rejection.key?.intValue {
                try db.execute(sql: "DELETE FROM comments WHERE day_number = ?", arguments: [key])
            }
        case .dayTags:
            if let key = rejection.key?.intValue {
                try db.execute(sql: "DELETE FROM day_tags WHERE day_number = ?", arguments: [key])
            }
        case .userTags:
            if let key = rejection.key?.stringValue {
                try db.execute(sql: "DELETE FROM user_tags WHERE id = ?", arguments: [key])
            }
        case .profile:
            // The flag comes off, the row stays. It is a singleton carrying the owner's id, and
            // deleting it to express "the server refused your name" would take the identity with
            // it — and the identity is the server's own, not something we pushed.
            try db.execute(sql: "UPDATE user_profile SET dirty_seq = NULL WHERE id = 1")
        }
    }

    private static func isProfileDirty(_ db: Database) throws -> Bool {
        try Bool.fetchOne(db, sql: "SELECT EXISTS(SELECT 1 FROM user_profile WHERE id = 1 AND dirty_seq IS NOT NULL)") ?? false
    }

    private static func profileOwner(_ db: Database) throws -> String? {
        try String.fetchOne(db, sql: "SELECT user_id FROM user_profile WHERE id = 1")
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
