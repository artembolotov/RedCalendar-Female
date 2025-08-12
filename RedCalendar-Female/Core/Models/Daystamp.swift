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

// MARK: - Daystamp Structure
struct Daystamp {
    let rawValue: Int
    
    // MARK: - Initializers
    init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    init(from date: Date, calendar: Calendar) {
        let components = DateComponents.componentsForReferenceDate()
        let referenceDate = calendar.date(from: components)!
        
        self.rawValue = calendar.dateComponents([.day], from: referenceDate, to: date).day!
    }
    
    // MARK: - Conversion Methods
    func toDate(calendar: Calendar) -> Date {
        let components = DateComponents.componentsForReferenceDate()
        let referenceDate = calendar.date(from: components)!
        
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

// MARK: - Comparable
extension Daystamp: Comparable {
    static func < (lhs: Daystamp, rhs: Daystamp) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    static func == (lhs: Daystamp, rhs: Daystamp) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}

// MARK: - AdditiveArithmetic
extension Daystamp: AdditiveArithmetic {
    static var zero: Daystamp {
        return Daystamp(rawValue: 0)
    }
    
    static func + (lhs: Daystamp, rhs: Daystamp) -> Daystamp {
        return Daystamp(rawValue: lhs.rawValue + rhs.rawValue)
    }
    
    static func - (lhs: Daystamp, rhs: Daystamp) -> Daystamp {
        return Daystamp(rawValue: lhs.rawValue - rhs.rawValue)
    }
    
    // Additional convenience operators for Int
    static func + (lhs: Daystamp, rhs: Int) -> Daystamp {
        return Daystamp(rawValue: lhs.rawValue + rhs)
    }
    
    static func - (lhs: Daystamp, rhs: Int) -> Daystamp {
        return Daystamp(rawValue: lhs.rawValue - rhs)
    }
    
    static func += (lhs: inout Daystamp, rhs: Int) {
        lhs = lhs + rhs
    }
    
    static func -= (lhs: inout Daystamp, rhs: Int) {
        lhs = lhs - rhs
    }
    
    static func += (lhs: inout Daystamp, rhs: Daystamp) {
        lhs = lhs + rhs
    }
    
    static func -= (lhs: inout Daystamp, rhs: Daystamp) {
        lhs = lhs - rhs
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
        let date = toDate(calendar: calendar)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        return "Daystamp(\(rawValue) -> \(dateString))"
    }
}

// MARK: - Hashable
extension Daystamp: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
