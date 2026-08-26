import Foundation
import GRDB

struct CycleRecord: Codable, FetchableRecord, PersistableRecord {
    var startDay: Daystamp
    var periodLength: Int?
    var ovulation: OvulationData?
    var dirtySeq: Int?

    static let databaseTableName = "cycles"

    enum Columns: String, CodingKey, ColumnExpression {
        case startDay = "start_day"
        case periodLength = "period_length"
        case ovulation
        case dirtySeq = "dirty_seq"
    }

    typealias CodingKeys = Columns
}

extension CycleRecord: DirtyStamped {}

/// `dirtySeq` is out of the comparison for the same reason `updatedAt` was: this is what
/// `removeDuplicates()` asks, and a generation that moved without the cycle moving is not a
/// change the calendar has to redraw for.
extension CycleRecord: Equatable {
    static func == (lhs: CycleRecord, rhs: CycleRecord) -> Bool {
        lhs.startDay == rhs.startDay &&
        lhs.periodLength == rhs.periodLength &&
        lhs.ovulation == rhs.ovulation
    }
}

// MARK: - OvulationData

struct OvulationData: Codable, Equatable {
    var day: Daystamp
    var confirmed: Bool

    init(day: Daystamp, confirmed: Bool = false) {
        self.day = day
        self.confirmed = confirmed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Daystamp.self, forKey: .day)
        confirmed = try container.decodeIfPresent(Bool.self, forKey: .confirmed) ?? false
    }
}
