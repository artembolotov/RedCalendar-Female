import Foundation
import GRDB

/// The one `user_profile` row (SYNC.md §3.1) — id, name, email, phone number and cycle settings,
/// as last written by a sync run.
///
/// `TableRecord`, not `PersistableRecord`: nothing on this side writes the row yet. `changes.profile`
/// is push, and the row is filled by the sync run itself (§12 item 8) — this type only reads what
/// landed there.
struct UserProfileRecord: Codable, FetchableRecord, TableRecord {
    static let databaseTableName = "user_profile"

    var id: Int
    var userId: String?
    var name: String?
    var email: String?
    var phoneNumber: String?
    var settingsJSON: String?
    var dirtySeq: Int?

    enum Columns: String, CodingKey, ColumnExpression {
        case id
        case userId = "user_id"
        case name
        case email
        case phoneNumber = "phone_number"
        case settingsJSON = "settings_json"
        case dirtySeq = "dirty_seq"
    }

    typealias CodingKeys = Columns
}

/// `id` and `dirtySeq` are out of the comparison for the same reason `FlowLevelRecord` leaves
/// `dirtySeq` out: `id` never varies (one row, always 1) and `dirtySeq` moves on every local write
/// whether or not it changes what's drawn — neither should wake `removeDuplicates()`.
extension UserProfileRecord: Equatable {
    static func == (lhs: UserProfileRecord, rhs: UserProfileRecord) -> Bool {
        lhs.userId == rhs.userId &&
        lhs.name == rhs.name &&
        lhs.email == rhs.email &&
        lhs.phoneNumber == rhs.phoneNumber &&
        lhs.settingsJSON == rhs.settingsJSON
    }
}
