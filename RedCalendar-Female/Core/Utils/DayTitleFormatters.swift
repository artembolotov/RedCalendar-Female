//
//  DayTitleFormatters.swift
//  RedCalendar-Female
//

import Foundation

/// Building a `DateFormatter` from a template costs more than the rest of a day title together,
/// and `DayDetailsView`'s pager can rebuild three titles per frame — so the templates callers need
/// are memoized here, and dropped when the user's region changes. Shared with `StatisticsView`,
/// which titles its history rows the same way.
enum DayTitleFormatters {
    private static let lock = NSLock()
    // Every read and write happens inside `lock`'s critical section below — `nonisolated(unsafe)`
    // hands the type system what the lock already guarantees at runtime.
    nonisolated(unsafe) private static var cachedLocaleIdentifier: String?
    nonisolated(unsafe) private static var formatters: [String: DateFormatter] = [:]

    static func formatter(template: String) -> DateFormatter {
        lock.lock()
        defer { lock.unlock() }

        let locale = Locale.current
        if cachedLocaleIdentifier != locale.identifier {
            formatters.removeAll()
            cachedLocaleIdentifier = locale.identifier
        }

        if let cached = formatters[template] {
            return cached
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        formatters[template] = formatter

        return formatter
    }
}
