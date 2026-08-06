import Foundation
import GRDB

nonisolated struct UserTagRecord: Codable, FetchableRecord, PersistableRecord {
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
