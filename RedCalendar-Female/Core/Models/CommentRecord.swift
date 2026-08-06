import Foundation
import GRDB

nonisolated struct CommentRecord: Codable, FetchableRecord, PersistableRecord {
    var dayNumber: Daystamp
    var comment: String?
    var updatedAt: Int?

    static let databaseTableName = "comments"

    enum Columns: String, CodingKey, ColumnExpression {
        case dayNumber = "day_number"
        case comment
        case updatedAt = "updated_at"
    }

    typealias CodingKeys = Columns
}

nonisolated extension CommentRecord: Equatable {
    static func == (lhs: CommentRecord, rhs: CommentRecord) -> Bool {
        lhs.dayNumber == rhs.dayNumber &&
        lhs.comment == rhs.comment
    }
}
