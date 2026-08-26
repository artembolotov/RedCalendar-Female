import Foundation
import GRDB

/// A day the user reported flow for.
///
/// Keyed by day rather than living in a dictionary inside its cycle's row (SYNC.md §3.4): while
/// it was one field of one row, two devices marking flow on two days of the same cycle were one
/// unit of synchronization, and one of the two marks lost the merge.
///
/// `level == nil` is this table's tombstone — the same shape `comments` uses, and what the day
/// card's "Не указано" writes.
struct FlowLevelRecord: Codable, FetchableRecord, PersistableRecord {
    var dayNumber: Daystamp
    var level: Int?
    var dirtySeq: Int?

    static let databaseTableName = "flow_levels"

    enum Columns: String, CodingKey, ColumnExpression {
        case dayNumber = "day_number"
        case level
        case dirtySeq = "dirty_seq"
    }

    typealias CodingKeys = Columns
}

extension FlowLevelRecord: DirtyStamped {}

/// `dirtySeq` is out of the comparison, as `updatedAt` was before it and for a sharper version
/// of the same reason: `removeDuplicates()` is what keeps an observation from waking the store,
/// and every local write now moves the generation whether or not it moves the level.
extension FlowLevelRecord: Equatable {
    static func == (lhs: FlowLevelRecord, rhs: FlowLevelRecord) -> Bool {
        lhs.dayNumber == rhs.dayNumber &&
        lhs.level == rhs.level
    }
}
