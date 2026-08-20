import Foundation
import GRDB

struct UserTagRecord: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String?
    var category: Int?
    var updatedAt: Int?

    static let databaseTableName = "user_tags"

    enum Columns: String, CodingKey, ColumnExpression {
        case id
        case name
        case category
        case updatedAt = "updated_at"
    }

    typealias CodingKeys = Columns
}

extension UserTagRecord: Equatable {
    static func == (lhs: UserTagRecord, rhs: UserTagRecord) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.category == rhs.category
    }
}

extension UserTagRecord {
    /// A tag the user has just made.
    ///
    /// The id is minted locally because nothing else is in a position to: there is no round trip
    /// to a server to get one from, and the row has to be storable and referable by `day_tags`
    /// the moment it exists. `updatedAt` is `nil`, which is the same "written here, not yet
    /// synced" mark every other local write in `DatabaseMiddleware` leaves.
    ///
    /// One factory rather than a construction in the view, another in the reducer and a third in
    /// the middleware: the same record is put into state and onto the disk, and two spellings of
    /// it are two chances for those to disagree.
    static func newLocal(name: String, category: TagCategory) -> UserTagRecord {
        UserTagRecord(
            id: UUID().uuidString,
            name: name,
            category: category.rawValue,
            updatedAt: nil
        )
    }
}
