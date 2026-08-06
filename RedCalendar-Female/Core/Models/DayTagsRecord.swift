import Foundation
import GRDB

nonisolated struct DayTagsRecord: Codable, FetchableRecord, PersistableRecord {
    var dayNumber: Daystamp
    var tagIds: [String]
    var updatedAt: Int?

    static let databaseTableName = "day_tags"

    enum Columns: String, CodingKey, ColumnExpression {
        case dayNumber = "day_number"
        case tagIds = "tag_ids"
        case updatedAt = "updated_at"
    }

    typealias CodingKeys = Columns
}

extension DayTagsRecord: Equatable {
    static func == (lhs: DayTagsRecord, rhs: DayTagsRecord) -> Bool {
        lhs.dayNumber == rhs.dayNumber &&
        Set(lhs.tagIds) == Set(rhs.tagIds)
    }
}
