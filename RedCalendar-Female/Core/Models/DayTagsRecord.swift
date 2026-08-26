import Foundation
import GRDB

struct DayTagsRecord: Codable, FetchableRecord, PersistableRecord {
    var dayNumber: Daystamp
    var tagIds: [String]
    var dirtySeq: Int?

    static let databaseTableName = "day_tags"

    enum Columns: String, CodingKey, ColumnExpression {
        case dayNumber = "day_number"
        case tagIds = "tag_ids"
        case dirtySeq = "dirty_seq"
    }

    typealias CodingKeys = Columns
}

extension DayTagsRecord: DirtyStamped {}

extension DayTagsRecord: Equatable {
    static func == (lhs: DayTagsRecord, rhs: DayTagsRecord) -> Bool {
        lhs.dayNumber == rhs.dayNumber &&
        Set(lhs.tagIds) == Set(rhs.tagIds)
    }
}
