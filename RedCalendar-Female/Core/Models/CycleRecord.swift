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

/// What the user has explicitly said about a cycle's ovulation — confirmed on a specific day, or
/// an anovulatory cycle with no ovulation at all. `nil` on `CycleRecord.ovulation` is not a third
/// case of this type: it means nothing has been said yet, and the day stays automatic — see
/// `CycleRecord.effectiveOvulationDay`.
///
/// `.confirmed` carries no distinction between "confirmed on the day the editor opened on" and "a
/// different day picked from the calendar" — `OvulationEditorView` tells those apart from which day
/// it was opened on, not from anything stored, so both write the same shape.
enum OvulationData: Codable, Equatable {
    case confirmed(day: Daystamp)
    case anovulatory

    private enum CodingKeys: String, CodingKey {
        case day, confirmed, anovulatory
    }

    /// Reads the shape RedCalendar 2.0's Firebase import already wrote (`{day, confirmed}`) —
    /// `confirmed` itself is not re-checked on the way in. An explicit `ovulation` object has
    /// always meant a real answer: `confirmed: false` was never imported (SYNC.md §10.3), and
    /// nothing wrote one at all before this feature existed.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if try container.decodeIfPresent(Bool.self, forKey: .anovulatory) == true {
            self = .anovulatory
            return
        }
        self = .confirmed(day: try container.decode(Daystamp.self, forKey: .day))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .confirmed(let day):
            try container.encode(day, forKey: .day)
            try container.encode(true, forKey: .confirmed)
        case .anovulatory:
            try container.encode(true, forKey: .anovulatory)
        }
    }
}
