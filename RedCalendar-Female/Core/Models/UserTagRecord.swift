import Foundation
import GRDB

/// A tag in the user's catalogue.
///
/// **The category is not optional, and the name is.** They look like a pair and they are
/// opposites: every tag belongs to one of the four groups, which is what gives it a colour on
/// the day's dots and in the picker, so there is no such thing as a tag without one. The name is
/// optional because clearing it is how this table deletes — see the soft delete below.
///
/// The category stays an `Int` rather than becoming a `TagCategory`: a record can carry a number
/// this build has never heard of, and it still has to draw rather than vanish
/// (`Color.tagColor(for:)` answers grey). What `TagCategory` decides is what can be *made*.
struct UserTagRecord: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var name: String?
    var category: Int
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
