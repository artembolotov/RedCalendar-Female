//
//  TagCategory.swift
//  RedCalendar-Female
//

/// The four groups a tag can belong to.
///
/// The storage format stays the integer it already was — `UserTagRecord.category` is an `Int?`,
/// the day's dots are a `Set<Int>` — and every *reader* goes on taking that integer, because a
/// record whose category is absent, or is a number this build has never heard of, still has to
/// draw rather than vanish (`Color.tagColor(for:)` answers grey for both). This enum is the
/// other half: what the user is *offered*. A tag can arrive carrying any integer; it can only be
/// made carrying one of these.
enum TagCategory: Int, CaseIterable, Identifiable, Equatable, Sendable {
    case symptom = 0
    case mood = 1
    case activity = 2
    case medication = 3

    /// What a new tag starts on. Symptoms are what the empty-state copy leads with, and what
    /// most first tags will be.
    static let fallback: TagCategory = .symptom

    var id: Int { rawValue }

    /// Plural, because the name labels a group of tags — in the picker it heads a row of them,
    /// and on the creation form it is the answer to "what kind of thing is this".
    var title: String {
        switch self {
        case .symptom:    return "Симптомы"
        case .mood:       return "Настроение"
        case .activity:   return "Активность"
        case .medication: return "Лекарства"
        }
    }
}
