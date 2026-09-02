//
//  SyncPayload.swift
//  RedCalendar-Female
//

import Foundation

// The `POST /data/sync` vocabulary (SYNC.md §4.1, §4.2), and the conversions between it and the
// GRDB records.
//
// It lives here rather than in `APIService.swift` with the auth request/response models, because
// it is not only an API type: `DatabaseServiceProtocol.applySync` is handed these same rows, and
// the whole of §5.1 step 7 is expressed in them. A shape two services share is a model.

// MARK: - Tables

/// The data streams a sync run knows about — the keys of `changes`, profile included: the cursor
/// treats it as a sixth stream, not as something attached to the user (§3.1, §4.4).
///
/// `allCases` is what `known_tables` is compared against on every launch (§4.6). Adding a case
/// here is therefore a full resync on the next run of the updated build, which is the point:
/// rows of a table this build did not understand are below its cursor forever otherwise.
enum SyncTable: String, Codable, Sendable, CaseIterable {
    case cycles
    case flowLevels = "flow_levels"
    case comments
    case userTags = "user_tags"
    case dayTags = "day_tags"
    case profile

    static var knownTables: Set<String> { Set(allCases.map(\.rawValue)) }
}

// MARK: - Rows
//
// Every one of these writes its optional fields with `encode`, never `encodeIfPresent`, and that
// is the single most load-bearing line of this file. `null` in a tombstone column means "delete"
// (§4.5); a synthesized encoder omits the key instead, which the server reads as "this field did
// not change" — so clearing a comment, a flow level, a period or a tag name would silently do
// nothing, on every device, forever. Foundation has no "encode nulls" option, so the encoders are
// spelled out. `init(from:)` stays synthesized: it already tolerates both null and absent.

struct SyncCycleRow: Codable, Sendable, Equatable {
    var startDay: Daystamp
    var periodLength: Int?
    var ovulation: OvulationData?

    enum CodingKeys: String, CodingKey {
        case startDay = "start_day"
        case periodLength = "period_length"
        case ovulation
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startDay, forKey: .startDay)
        try container.encode(periodLength, forKey: .periodLength)
        try container.encode(ovulation, forKey: .ovulation)
    }
}

struct SyncFlowLevelRow: Codable, Sendable, Equatable {
    var dayNumber: Daystamp
    var level: Int?

    enum CodingKeys: String, CodingKey {
        case dayNumber = "day_number"
        case level
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dayNumber, forKey: .dayNumber)
        try container.encode(level, forKey: .level)
    }
}

struct SyncCommentRow: Codable, Sendable, Equatable {
    var dayNumber: Daystamp
    var comment: String?

    enum CodingKeys: String, CodingKey {
        case dayNumber = "day_number"
        case comment
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dayNumber, forKey: .dayNumber)
        try container.encode(comment, forKey: .comment)
    }
}

struct SyncUserTagRow: Codable, Sendable, Equatable {
    var id: String
    var name: String?
    /// Not optional, and the asymmetry with `name` is the server's rule mirrored: the column is
    /// `NOT NULL`, so a row that omits it is rejected rather than written (§4.5).
    var category: Int

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
    }
}

/// The one table with no tombstone: a day stripped of every tag keeps its row with an empty
/// array, and the empty array *is* the deletion (§3.3).
struct SyncDayTagsRow: Codable, Sendable, Equatable {
    var dayNumber: Daystamp
    var tagIds: [String]

    enum CodingKeys: String, CodingKey {
        case dayNumber = "day_number"
        case tagIds = "tag_ids"
    }
}

/// What a device may write to the profile — `name` and `settings`, and nothing else. `email` and
/// `phone_number` are the login, so the server ignores them in `changes` whatever we send
/// (§4.4, "правило личности"); leaving them out of the type says so once instead of hoping.
///
/// **A field is encoded only when it is being edited, and that distinction is the server's.**
/// `name: null` means "erase the name"; an absent `name` means "leave it alone" (§4.5, and
/// `sync.js`'s `pickProfileFields` picks by `hasOwnProperty`, as `writeProfile` builds its `SET`
/// list). Encoding both keys unconditionally was safe only while nothing produced a push at all:
/// the first producer was the cycle-settings screen, which touches no name, and a device whose
/// profile has not been pulled yet has none to send — so a `null` would go out and erase the name
/// the user gave at registration, on the server, for every device. `UserProfileRecord.nameDirtySeq`
/// is what still keeps that safe now that a name editor exists: `init(_:)` below only ever reads
/// `record.name` into this type when that column says the name itself is what got edited.
struct SyncProfilePush: Encodable, Sendable, Equatable {
    /// Двойной optional умышленно: `nil` — "имя не редактируется", `.some(nil)` — "стереть".
    /// `ProfileView`'s name field produces both: `init(_:)` below wraps `record.name` in `.some`
    /// whenever `nameDirtySeq` says the name itself was edited, and an edit that cleared the field
    /// to empty is stored locally as `record.name == nil` — so the same wrapping yields
    /// `.some(nil)`, the real erase, without a separate code path for it.
    var name: String??
    var settings: JSONValue?

    enum CodingKeys: String, CodingKey {
        case name
        case settings
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let name {
            try container.encode(name, forKey: .name)
        }
        if let settings {
            try container.encode(settings, forKey: .settings)
        }
    }
}

/// What comes back — the two fields above plus the two only the server writes.
struct SyncProfilePull: Codable, Sendable, Equatable {
    var name: String?
    var email: String?
    var phoneNumber: String?
    var settings: JSONValue?

    enum CodingKeys: String, CodingKey {
        case name
        case email
        case phoneNumber = "phone_number"
        case settings
    }
}

// MARK: - Request

struct SyncRequest: Encodable, Sendable {
    var since: Int
    var syncSchema: Int
    var device: Device
    /// Absent, not empty, when there is nothing to push: the server counts "changes are
    /// non-empty" by rows, so an omitted key and `{"cycles": []}` mean the same thing to it, and
    /// the first is what a pull-only run (§5.2) actually is.
    var changes: SyncChangesPush?

    struct Device: Encodable, Sendable {
        /// IANA, not an offset — groundwork for notifications at 9am local (§4.1, §15).
        var timezone: String
        /// The hardware identifier (§19.5). Sent on every run rather than kept from sign-in
        /// because a restore carries the session onto a new phone: the `device_id` survives the
        /// hardware, so a model written once would name the old phone in the device list forever.
        /// The server merges it with `COALESCE`, so an omitted one never blanks what is known.
        var deviceModel: String

        enum CodingKeys: String, CodingKey {
            case timezone
            case deviceModel = "device_model"
        }
    }

    enum CodingKeys: String, CodingKey {
        case since
        case syncSchema = "sync_schema"
        case device
        case changes
    }
}

struct SyncChangesPush: Encodable, Sendable {
    var cycles: [SyncCycleRow] = []
    var flowLevels: [SyncFlowLevelRow] = []
    var comments: [SyncCommentRow] = []
    var userTags: [SyncUserTagRow] = []
    var dayTags: [SyncDayTagsRow] = []
    var profile: SyncProfilePush?

    enum CodingKeys: String, CodingKey {
        case cycles
        case flowLevels = "flow_levels"
        case comments
        case userTags = "user_tags"
        case dayTags = "day_tags"
        case profile
    }

    var isEmpty: Bool {
        cycles.isEmpty && flowLevels.isEmpty && comments.isEmpty
            && userTags.isEmpty && dayTags.isEmpty && profile == nil
    }
}

// MARK: - Response

struct SyncResponse: Decodable, Sendable {
    var userId: String?
    var changes: SyncChangesPull?
    var rejected: [SyncRejection]
    var nextCursor: Int
    var hasMore: Bool
    /// The server never sets it today. It is read from the first day anyway, because a build that
    /// ignores it cannot be taught to honour it retroactively — and that build is exactly the one
    /// that would lose rows when tombstones start being swept (§4.6).
    var fullResyncRequired: Bool
    var importStatus: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case changes
        case rejected
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
        case fullResyncRequired = "full_resync_required"
        case importStatus = "import_status"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        changes = try container.decodeIfPresent(SyncChangesPull.self, forKey: .changes)
        rejected = try container.decodeIfPresent([SyncRejection].self, forKey: .rejected) ?? []
        nextCursor = try container.decode(Int.self, forKey: .nextCursor)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        fullResyncRequired = try container.decodeIfPresent(Bool.self, forKey: .fullResyncRequired) ?? false
        importStatus = try container.decodeIfPresent(String.self, forKey: .importStatus)
    }
}

struct SyncChangesPull: Decodable, Sendable {
    var cycles: [SyncCycleRow] = []
    var flowLevels: [SyncFlowLevelRow] = []
    var comments: [SyncCommentRow] = []
    var userTags: [SyncUserTagRow] = []
    var dayTags: [SyncDayTagsRow] = []
    var profile: SyncProfilePull?

    enum CodingKeys: String, CodingKey {
        case cycles
        case flowLevels = "flow_levels"
        case comments
        case userTags = "user_tags"
        case dayTags = "day_tags"
        case profile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cycles = try container.decodeIfPresent([SyncCycleRow].self, forKey: .cycles) ?? []
        flowLevels = try container.decodeIfPresent([SyncFlowLevelRow].self, forKey: .flowLevels) ?? []
        comments = try container.decodeIfPresent([SyncCommentRow].self, forKey: .comments) ?? []
        userTags = try container.decodeIfPresent([SyncUserTagRow].self, forKey: .userTags) ?? []
        dayTags = try container.decodeIfPresent([SyncDayTagsRow].self, forKey: .dayTags) ?? []
        profile = try container.decodeIfPresent(SyncProfilePull.self, forKey: .profile)
    }

    var isEmpty: Bool {
        cycles.isEmpty && flowLevels.isEmpty && comments.isEmpty
            && userTags.isEmpty && dayTags.isEmpty && profile == nil
    }
}

/// A row the server refused, with its authoritative version attached — or with `row == nil`,
/// which means "there is nothing here, drop yours" (§4.2).
///
/// `key` is what identifies the local row in that second case: the natural key exactly as we sent
/// it. It is redundant when `row` is present and indispensable when it is not.
struct SyncRejection: Decodable, Sendable {
    /// `nil` when the server names a table this build has never heard of. Nothing can be done
    /// with such a rejection, and it is not an error — see `SyncTable`.
    var table: SyncTable?
    var key: SyncKey?
    var reason: String?
    var row: Row?

    /// Decoded according to `table`, which is why this type cannot lean on synthesis.
    enum Row: Sendable {
        case cycle(SyncCycleRow)
        case flowLevel(SyncFlowLevelRow)
        case comment(SyncCommentRow)
        case userTag(SyncUserTagRow)
        case dayTags(SyncDayTagsRow)
        case profile(SyncProfilePull)
    }

    enum CodingKeys: String, CodingKey {
        case table, key, reason, row
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        table = try? container.decodeIfPresent(SyncTable.self, forKey: .table)
        key = try container.decodeIfPresent(SyncKey.self, forKey: .key)
        reason = try container.decodeIfPresent(String.self, forKey: .reason)

        guard let table, !((try? container.decodeNil(forKey: .row)) ?? true) else {
            row = nil
            return
        }
        switch table {
        case .cycles:     row = .cycle(try container.decode(SyncCycleRow.self, forKey: .row))
        case .flowLevels: row = .flowLevel(try container.decode(SyncFlowLevelRow.self, forKey: .row))
        case .comments:   row = .comment(try container.decode(SyncCommentRow.self, forKey: .row))
        case .userTags:   row = .userTag(try container.decode(SyncUserTagRow.self, forKey: .row))
        case .dayTags:    row = .dayTags(try container.decode(SyncDayTagsRow.self, forKey: .row))
        case .profile:    row = .profile(try container.decode(SyncProfilePull.self, forKey: .row))
        }
    }
}

/// A natural key, as it went out: an integer day or start day for four of the tables, a UUID
/// string for the tags, absent for the profile. A key the server could not echo back as a scalar
/// arrives as `null` and this stays `nil` (§4.2).
enum SyncKey: Decodable, Sendable, Equatable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "A rejection key is neither an integer nor a string"
            )
        }
    }

    var intValue: Int? { if case .int(let value) = self { value } else { nil } }
    var stringValue: String? { if case .string(let value) = self { value } else { nil } }
}

// MARK: - Record conversions

extension SyncCycleRow {
    init(_ record: CycleRecord) {
        self.init(startDay: record.startDay, periodLength: record.periodLength, ovulation: record.ovulation)
    }

    /// `dirtySeq` is nil by construction: a row that came from the server has nothing local left
    /// to push. Step 7.2 never sees these — they are written already clean.
    var record: CycleRecord {
        CycleRecord(startDay: startDay, periodLength: periodLength, ovulation: ovulation, dirtySeq: nil)
    }
}

extension SyncFlowLevelRow {
    init(_ record: FlowLevelRecord) {
        self.init(dayNumber: record.dayNumber, level: record.level)
    }

    var record: FlowLevelRecord {
        FlowLevelRecord(dayNumber: dayNumber, level: level, dirtySeq: nil)
    }
}

extension SyncCommentRow {
    init(_ record: CommentRecord) {
        self.init(dayNumber: record.dayNumber, comment: record.comment)
    }

    var record: CommentRecord {
        CommentRecord(dayNumber: dayNumber, comment: comment, dirtySeq: nil)
    }
}

extension SyncUserTagRow {
    init(_ record: UserTagRecord) {
        self.init(id: record.id, name: record.name, category: record.category)
    }

    var record: UserTagRecord {
        UserTagRecord(id: id, name: name, category: category, dirtySeq: nil)
    }
}

extension SyncDayTagsRow {
    init(_ record: DayTagsRecord) {
        self.init(dayNumber: record.dayNumber, tagIds: record.tagIds)
    }

    var record: DayTagsRecord {
        DayTagsRecord(dayNumber: dayNumber, tagIds: tagIds, dirtySeq: nil)
    }
}

extension SyncProfilePush {
    /// The settings travel as whatever JSON is in the column, not as a re-encoded `UserSettings`:
    /// a key this build does not model would be dropped on the way through, and pushing the
    /// result back would erase it on the server for every device.
    ///
    /// The name is read from the row only when `nameDirtySeq` says it is what got edited — the
    /// row's copy is otherwise a report of what the server said, and sending it back as an edit
    /// would be a claim nobody made. A profile dirtied only by a settings edit (`nameDirtySeq ==
    /// nil`) therefore still omits the key, for the reason on the type: a device whose profile has
    /// never been pulled has no real name to report, and encoding its `nil` would erase whatever
    /// name the server already has for every other device.
    init(_ record: UserProfileRecord) {
        self.init(
            name: record.nameDirtySeq != nil ? .some(record.name) : nil,
            settings: JSONValue(jsonString: record.settingsJSON)
        )
    }
}

extension SyncProfilePull {
    /// `userId` is not in the row — it is the response's own `user_id` — so it is passed in.
    func record(userId: String?) -> UserProfileRecord {
        UserProfileRecord(
            id: 1,
            userId: userId,
            name: name,
            email: email,
            phoneNumber: phoneNumber,
            settingsJSON: settings?.jsonString,
            dirtySeq: nil
        )
    }
}
