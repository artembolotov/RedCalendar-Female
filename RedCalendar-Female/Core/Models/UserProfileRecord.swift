import Foundation
import GRDB

/// The one `user_profile` row (SYNC.md §3.1) — id, name, email, phone number and cycle settings,
/// as last written by a sync run or a local edit.
///
/// Written by a sync run applying what the server sent (§5.1 step 7), and by the two local
/// writers of the device's half of the row: `updateCycleSettings` for the settings, `updateName`
/// for the name. Both stamp `dirty_seq`, the row-wide flag a push reads to decide whether to send
/// this row at all.
struct UserProfileRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "user_profile"

    var id: Int
    var userId: String?
    var name: String?
    var email: String?
    var phoneNumber: String?
    var settingsJSON: String?
    var dirtySeq: Int?
    /// The generation `updateName` last stamped, separately from `dirty_seq` — the row-wide flag
    /// says only that *something* in the device's half is unsent, and `settings` is the other
    /// thing that can dirty it. `SyncProfilePush(_:)` reads this to decide whether `name` belongs
    /// in the push at all: sending it whenever the row happens to be dirty would resend an unedited
    /// name every time the settings alone changed, and — for a device whose profile has never been
    /// pulled — encode the real edit's `nil` as an erasure of a name it has simply never seen.
    ///
    /// Always `<= dirtySeq`: both are stamped from the same generation counter in the same
    /// transaction whenever `updateName` runs, and nothing else advances this one. That is what
    /// lets it be cleared by the same `sentMax` a push's `dirty_seq` is cleared by.
    var nameDirtySeq: Int? = nil

    enum Columns: String, CodingKey, ColumnExpression {
        case id
        case userId = "user_id"
        case name
        case email
        case phoneNumber = "phone_number"
        case settingsJSON = "settings_json"
        case dirtySeq = "dirty_seq"
        case nameDirtySeq = "name_dirty_seq"
    }

    typealias CodingKeys = Columns
}

extension UserProfileRecord {
    /// The stored `settings`, as much of them as this build models.
    ///
    /// Decoded on demand rather than stored: the column is the authority and holds the server's
    /// own JSON, keys this build knows nothing about included (SYNC.md §15). Anything that does
    /// not decode is `nil`, which every reader already treats as "no settings" — a profile is not
    /// worth failing over.
    var settings: UserSettings? {
        settingsJSON
            .flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(UserSettings.self, from: $0) }
    }
}

/// `id`, `dirtySeq` and `nameDirtySeq` are out of the comparison for the same reason
/// `FlowLevelRecord` leaves `dirtySeq` out: `id` never varies (one row, always 1) and the two
/// generation columns move on every local write whether or not they change what's drawn — a push
/// confirmation clearing them is exactly such a write — so none of the three should wake
/// `removeDuplicates()`.
extension UserProfileRecord: Equatable {
    static func == (lhs: UserProfileRecord, rhs: UserProfileRecord) -> Bool {
        lhs.userId == rhs.userId &&
        lhs.name == rhs.name &&
        lhs.email == rhs.email &&
        lhs.phoneNumber == rhs.phoneNumber &&
        lhs.settingsJSON == rhs.settingsJSON
    }
}
