import Foundation
import GRDB

struct CycleRecord: Codable, FetchableRecord, PersistableRecord {
    var startDay: Daystamp
    var periodLength: Int?
    var ovulation: OvulationData?
    var flowLevels: [String: Int]
    var updatedAt: Int?

    static let databaseTableName = "cycles"

    enum Columns: String, CodingKey, ColumnExpression {
        case startDay = "start_day"
        case periodLength = "period_length"
        case ovulation
        case flowLevels = "flow_levels"
        case updatedAt = "updated_at"
    }

    typealias CodingKeys = Columns
}

extension CycleRecord: Equatable {
    static func == (lhs: CycleRecord, rhs: CycleRecord) -> Bool {
        lhs.startDay == rhs.startDay &&
        lhs.periodLength == rhs.periodLength &&
        lhs.ovulation == rhs.ovulation &&
        lhs.flowLevels == rhs.flowLevels
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
