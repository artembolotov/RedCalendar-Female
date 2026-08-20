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
///
/// **A category has no name, by design.** It is a colour on the day's dots, a colour on the
/// chips in the picker, and a colour on the four swatches the creation form offers — nowhere in
/// the app does anything read it out as a word, and naming the four would put a claim on this
/// screen that no other screen could keep. That is why there is no `title` here: it existed
/// briefly, was shown once, and made the creation form the only place in the app that said what
/// a category *is*.
enum TagCategory: Int, CaseIterable, Identifiable, Equatable, Sendable {
    case symptom = 0
    case mood = 1
    case activity = 2
    case medication = 3

    /// What a new tag starts on — the first swatch, so the row is never offered with nothing
    /// chosen in it.
    static let fallback: TagCategory = .symptom

    var id: Int { rawValue }
}
