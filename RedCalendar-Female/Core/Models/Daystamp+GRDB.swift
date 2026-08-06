//
//  Daystamp+GRDB.swift
//  RedCalendar-Female
//

import GRDB

// Stored as the plain day number, so day columns keep their INTEGER type and
// range filters (`range.contains(Columns.dayNumber)`) keep working unchanged.
extension Daystamp: DatabaseValueConvertible {
    var databaseValue: DatabaseValue {
        rawValue.databaseValue
    }

    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Daystamp? {
        Int.fromDatabaseValue(dbValue).map(Daystamp.init(rawValue:))
    }
}
