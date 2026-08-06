//
//  Daystamp.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.08.2025.
//

import Foundation

// MARK: - DateComponents Extension
extension DateComponents {
    static func componentsForReferenceDate() -> DateComponents {
        var components = DateComponents()
        components.day = 1
        components.month = 1
        components.year = 2001
        return components
    }
}

// MARK: - Reference Date Cache

// Resolving 2001-01-01 in a calendar is a full date computation, and the calendar
// conversions below run per visible day while the calendar scrolls. The calendar
// only changes when the user's region does, so one memoized slot covers every call.
private enum ReferenceDate {
    private static let lock = NSLock()
    private static var cachedCalendar: Calendar?
    private static var cachedDate: Date?

    private static let components = DateComponents.componentsForReferenceDate()

    static func resolved(for calendar: Calendar) -> Date {
        lock.lock()
        defer { lock.unlock() }

        if let cached = cachedDate, cachedCalendar == calendar {
            return cached
        }

        let date = calendar.date(from: components)!
        cachedCalendar = calendar
        cachedDate = date
        return date
    }
}

// MARK: - Daystamp Structure
nonisolated struct Daystamp {
    let rawValue: Int

    // MARK: - Initializers
    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    init(from date: Date, calendar: Calendar) {
        let referenceDate = ReferenceDate.resolved(for: calendar)

        self.rawValue = calendar.dateComponents([.day], from: referenceDate, to: date).day!
    }

    // MARK: - Conversion Methods
    func toDate(calendar: Calendar) -> Date {
        let referenceDate = ReferenceDate.resolved(for: calendar)

        return calendar.date(byAdding: .day, value: rawValue, to: referenceDate)!
    }

    static func today(calendar: Calendar) -> Daystamp {
        return Daystamp(from: Date(), calendar: calendar)
    }
}

// MARK: - ExpressibleByIntegerLiteral
extension Daystamp: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(rawValue: value)
    }
}

// MARK: - Strideable

// Strideable — not AdditiveArithmetic: the distance between two days is a count of
// days, not a day, and adding two daystamps together is meaningless. It also makes
// `ClosedRange<Daystamp>` iterable, so day loops stay in Daystamp throughout.
extension Daystamp: Strideable {
    func advanced(by n: Int) -> Daystamp {
        return Daystamp(rawValue: rawValue + n)
    }

    func distance(to other: Daystamp) -> Int {
        return other.rawValue - rawValue
    }

    static func < (lhs: Daystamp, rhs: Daystamp) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    static func == (lhs: Daystamp, rhs: Daystamp) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

// MARK: - Day Arithmetic

// Spelled out rather than inherited: `Strideable` supplies `advanced(by:)` /
// `distance(to:)` and makes `ClosedRange<Daystamp>` iterable, but the standard library
// vends `+` / `-` only for concrete stridable types, not for the protocol itself.
extension Daystamp {
    static func + (lhs: Daystamp, rhs: Int) -> Daystamp {
        return Daystamp(rawValue: lhs.rawValue + rhs)
    }

    static func - (lhs: Daystamp, rhs: Int) -> Daystamp {
        return Daystamp(rawValue: lhs.rawValue - rhs)
    }

    /// Days between two daystamps — a count, not a day.
    static func - (lhs: Daystamp, rhs: Daystamp) -> Int {
        return lhs.rawValue - rhs.rawValue
    }
}

// MARK: - Codable
extension Daystamp: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(Int.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - CustomStringConvertible
extension Daystamp: CustomStringConvertible {
    var description: String {
        // Use current calendar for display purposes
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: toDate(calendar: calendar))
        let dateString = String(
            format: "%04ld-%02ld-%02ld",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )

        return "Daystamp(\(rawValue) -> \(dateString))"
    }
}

// MARK: - Hashable
extension Daystamp: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
