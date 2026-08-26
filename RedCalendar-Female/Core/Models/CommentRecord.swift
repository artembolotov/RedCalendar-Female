import Foundation
import GRDB

struct CommentRecord: Codable, FetchableRecord, PersistableRecord {
    var dayNumber: Daystamp
    var comment: String?
    var dirtySeq: Int?

    static let databaseTableName = "comments"

    enum Columns: String, CodingKey, ColumnExpression {
        case dayNumber = "day_number"
        case comment
        case dirtySeq = "dirty_seq"
    }

    typealias CodingKeys = Columns
}

extension CommentRecord: DirtyStamped {}

extension CommentRecord: Equatable {
    static func == (lhs: CommentRecord, rhs: CommentRecord) -> Bool {
        lhs.dayNumber == rhs.dayNumber &&
        lhs.comment == rhs.comment
    }
}
