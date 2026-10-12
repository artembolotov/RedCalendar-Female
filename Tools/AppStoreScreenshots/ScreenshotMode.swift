//
//  ScreenshotMode.swift
//  RedCalendar-Female
//
//  TEMPORARY. `Tools/AppStoreScreenshots/capture.sh` copies this file into the target, applies
//  `hooks.patch`, builds, and takes both out again before it captures anything. Never commit it
//  into `RedCalendar-Female/`.
//
//  Active only when the app is launched with `-ScreenshotMode YES`. The launch arguments land in
//  `UserDefaults`' argument domain, which is why they are read from there.
//

import Foundation
import GRDB

enum ScreenshotMode {
    static let isActive = UserDefaults.standard.bool(forKey: "ScreenshotMode")

    static let scene = Scene(rawValue: UserDefaults.standard.string(forKey: "ScreenshotScene") ?? "") ?? .calendar

    /// What `Daystamp.today` answers while the mode is on.
    static let today: Daystamp? = isActive ? day(2026, 4, 8) : nil

    enum Scene: String, Sendable {
        /// The calendar with today selected.
        case calendar
        /// The day card of a period day with flow, tags and a comment.
        case period
        /// The tag picker over that same period day.
        case tags
        /// The comment editor over today.
        case comment
        case statistics
        case settings
        /// The calendar with nothing selected.
        case empty

        var selectedDay: Daystamp? {
            switch self {
            case .calendar, .comment: return ScreenshotMode.day(2026, 4, 8)
            case .period, .tags: return ScreenshotMode.day(2026, 3, 26)
            case .statistics, .settings, .empty: return nil
            }
        }
    }

    enum DaySheet {
        case tags
        case comment
    }

    // MARK: - Hooks

    static var middlewares: [Middleware] {
        // No auth, sync, push, consent, migration or analytics: nothing here may reach the
        // network with a device id the server has never issued, and nothing may put a system
        // alert over the screen.
        [
            loggerMiddleware,
            appearanceMiddleware,
            feedbackMiddleware,
            { state, action, dispatch in
                await DatabaseMiddleware.shared.handle(state: state, action: action, dispatch: dispatch)
            }
        ]
    }

    /// Replaces the whole of `didFinishLaunching`.
    @MainActor
    static func launch() {
        removeDatabase()
        Configurator.shared.setup()

        do {
            try seed()
        } catch {
            fatalError("ScreenshotMode: seeding failed: \(error)")
        }

        let store = AppStore.shared
        if let raw = UserDefaults.standard.string(forKey: "ScreenshotAccent"),
           let theme = AccentTheme(rawValue: raw) {
            store.send(.appearance(.setAccentTheme(theme)))
        } else {
            store.send(.appearance(.setAccentTheme(.coral)))
        }
        store.send(.auth(.set(.authenticated(deviceId: "screenshots-device"))))

        // After the calendar has laid itself out, the way a tap would arrive.
        guard let day = scene.selectedDay else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            store.send(.calendar(.selectDay(day)))
        }
    }

    @MainActor
    static func menuSheet() async -> HomeMenuSheet? {
        guard isActive else { return nil }
        let sheet: HomeMenuSheet
        switch scene {
        case .statistics: sheet = .statistics
        case .settings: sheet = .settings(openingOnEmail: false)
        default: return nil
        }
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        return sheet
    }

    @MainActor
    private static var didPresentDaySheet = false

    @MainActor
    static func daySheet(isSelectedCard: Bool) async -> DaySheet? {
        guard isActive, isSelectedCard, !didPresentDaySheet else { return nil }
        let sheet: DaySheet
        switch scene {
        case .tags: sheet = .tags
        case .comment: sheet = .comment
        default: return nil
        }
        didPresentDaySheet = true
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        return sheet
    }

    // MARK: - Dates

    static func day(_ year: Int, _ month: Int, _ day: Int) -> Daystamp {
        let calendar = Calendar.current
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        return Daystamp(from: date, calendar: calendar)
    }

    private static var isRussian: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ru") ?? true
    }

    private static func text(_ ru: String, _ en: String) -> String {
        isRussian ? ru : en
    }

    // MARK: - Database

    private static func databaseURL() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("redcalendar.sqlite")
    }

    /// Every launch starts from the same rows, whatever the previous one left behind.
    private static func removeDatabase() {
        guard let path = try? databaseURL().path else { return }
        for suffix in ["", "-wal", "-shm", "-journal"] {
            try? FileManager.default.removeItem(atPath: path + suffix)
        }
    }

    /// A second connection to the file `DatabaseService` has just created and migrated. Rows are
    /// written clean (`dirty_seq` NULL) — nothing will ever push them.
    private static func seed() throws {
        let queue = try DatabaseQueue(path: databaseURL().path)
        try queue.write { db in
            let userId = "screenshots-user"
            try db.execute(sql: "UPDATE sync_state SET user_id = ? WHERE id = 1", arguments: [userId])
            try db.execute(
                sql: """
                    INSERT INTO user_profile (id, user_id, name, email, phone_number, settings_json)
                    VALUES (1, ?, ?, ?, NULL, ?)
                    """,
                arguments: [
                    userId,
                    text("Анна", "Anna"),
                    "anna@example.com",
                    #"{"cycle":{"default_length":28,"default_period_length":5,"luteal_phase_length":14},"notifications":{"muted":false}}"#
                ]
            )

            try seedCycles(db)
            try seedTags(db)
            try seedComments(db)
        }
    }

    // MARK: - Cycles

    /// The newest start first. The intervals and the period lengths wobble by a day either way,
    /// so the statistics have something to draw, and their medians are exactly 28 and 5 — the
    /// forecast and the settings both read 28/5.
    private static let cycleIntervals = [28, 29, 27, 28, 28, 30, 27, 28, 29, 28, 27, 28]
    private static let periodLengths = [5, 5, 6, 5, 4, 5, 5, 6, 5, 5, 4, 5, 5]

    private static func flowPattern(length: Int) -> [Int] {
        switch length {
        case 4: return [2, 3, 2, 1]
        case 6: return [2, 3, 3, 2, 1, 1]
        default: return [2, 3, 3, 2, 1]
        }
    }

    private static var cycleStarts: [Daystamp] {
        var starts = [day(2026, 3, 25)]
        for interval in cycleIntervals {
            starts.append(starts.last! - interval)
        }
        return starts
    }

    private static func seedCycles(_ db: Database) throws {
        let starts = cycleStarts
        for (index, start) in starts.enumerated() {
            // The current cycle stays automatic (today is its predicted ovulation); four of the
            // completed ones carry a confirmed day, drawn solid instead of dashed.
            let ovulation: OvulationData? = (1...4).contains(index)
                ? .confirmed(day: starts[index - 1] - 14)
                : nil
            let length = periodLengths[index]
            try CycleRecord(startDay: start, periodLength: length, ovulation: ovulation).insert(db)

            for (offset, level) in flowPattern(length: length).enumerated() {
                try FlowLevelRecord(dayNumber: start + offset, level: level).insert(db)
            }
        }
    }

    // MARK: - Tags

    private struct TagSeed {
        let id: String
        let category: TagCategory
        let ru: String
        let en: String
    }

    private static let tags: [TagSeed] = [
        TagSeed(id: "cramps", category: .symptom, ru: "Спазмы", en: "Cramps"),
        TagSeed(id: "headache", category: .symptom, ru: "Головная боль", en: "Headache"),
        TagSeed(id: "bloating", category: .symptom, ru: "Вздутие", en: "Bloating"),
        TagSeed(id: "breasts", category: .symptom, ru: "Чувствительная грудь", en: "Tender breasts"),
        TagSeed(id: "acne", category: .symptom, ru: "Акне", en: "Acne"),
        TagSeed(id: "fatigue", category: .symptom, ru: "Усталость", en: "Fatigue"),

        TagSeed(id: "calm", category: .mood, ru: "Спокойствие", en: "Calm"),
        TagSeed(id: "energetic", category: .mood, ru: "Бодрость", en: "Energetic"),
        TagSeed(id: "happy", category: .mood, ru: "Радость", en: "Happy"),
        TagSeed(id: "irritable", category: .mood, ru: "Раздражительность", en: "Irritable"),
        TagSeed(id: "anxious", category: .mood, ru: "Тревога", en: "Anxious"),
        TagSeed(id: "teary", category: .mood, ru: "Плаксивость", en: "Teary"),

        TagSeed(id: "yoga", category: .activity, ru: "Йога", en: "Yoga"),
        TagSeed(id: "running", category: .activity, ru: "Бег", en: "Running"),
        TagSeed(id: "walk", category: .activity, ru: "Прогулка", en: "Walk"),
        TagSeed(id: "swimming", category: .activity, ru: "Бассейн", en: "Swimming"),
        TagSeed(id: "meditation", category: .activity, ru: "Медитация", en: "Meditation"),
        TagSeed(id: "intimacy", category: .activity, ru: "Близость", en: "Intimacy"),

        TagSeed(id: "vitamins", category: .medication, ru: "Витамины", en: "Vitamins"),
        TagSeed(id: "painkiller", category: .medication, ru: "Обезболивающее", en: "Painkiller"),
        TagSeed(id: "magnesium", category: .medication, ru: "Магний", en: "Magnesium"),
        TagSeed(id: "iron", category: .medication, ru: "Железо", en: "Iron"),
        TagSeed(id: "omega", category: .medication, ru: "Омега-3", en: "Omega-3"),
    ]

    /// The two most recent cycles, day by day — the part of the calendar the screenshots show.
    private static let recentDayTags: [(Daystamp, [String])] = [
        // The cycle before (started 25 February).
        (day(2026, 2, 25), ["cramps", "fatigue", "painkiller"]),
        (day(2026, 2, 26), ["cramps", "headache", "painkiller"]),
        (day(2026, 2, 27), ["bloating", "teary"]),
        (day(2026, 3, 2), ["walk", "calm"]),
        (day(2026, 3, 5), ["yoga", "omega"]),
        (day(2026, 3, 8), ["happy", "walk"]),
        (day(2026, 3, 11), ["energetic", "intimacy"]),
        (day(2026, 3, 14), ["swimming", "vitamins"]),
        (day(2026, 3, 17), ["acne"]),
        (day(2026, 3, 19), ["breasts", "irritable"]),
        (day(2026, 3, 20), ["bloating", "irritable", "magnesium"]),
        (day(2026, 3, 21), ["headache", "anxious", "painkiller"]),
        (day(2026, 3, 23), ["breasts", "fatigue", "magnesium"]),
        (day(2026, 3, 24), ["cramps", "teary"]),

        // The current cycle (started 25 March).
        (day(2026, 3, 25), ["cramps", "fatigue", "painkiller"]),
        (day(2026, 3, 26), ["cramps", "bloating", "teary", "painkiller", "iron"]),
        (day(2026, 3, 27), ["fatigue", "calm", "magnesium"]),
        (day(2026, 3, 28), ["walk", "calm", "iron"]),
        (day(2026, 3, 31), ["yoga", "energetic"]),
        (day(2026, 4, 2), ["running", "happy", "vitamins"]),
        (day(2026, 4, 4), ["swimming", "energetic"]),
        (day(2026, 4, 5), ["walk", "happy", "vitamins"]),
        (day(2026, 4, 6), ["meditation", "calm"]),
        (day(2026, 4, 7), ["running", "energetic", "intimacy"]),
        (day(2026, 4, 8), ["energetic", "happy", "yoga", "vitamins"]),
    ]

    /// Older cycles get the same rhythm in miniature, offsets from each start, so scrolling back
    /// does not reach an empty calendar.
    private static let olderCycleTemplate: [(Int, [String])] = [
        (0, ["cramps", "painkiller"]),
        (1, ["cramps", "fatigue"]),
        (8, ["yoga"]),
        (13, ["energetic"]),
        (17, ["running", "vitamins"]),
        (23, ["breasts", "irritable"]),
        (25, ["bloating", "magnesium"]),
    ]

    private static func seedTags(_ db: Database) throws {
        for tag in tags {
            try UserTagRecord(id: tag.id, name: text(tag.ru, tag.en), category: tag.category.rawValue).insert(db)
        }

        var byDay: [Daystamp: [String]] = [:]
        for start in cycleStarts.dropFirst(2) {
            for (offset, ids) in olderCycleTemplate {
                byDay[start + offset] = ids
            }
        }
        for (day, ids) in recentDayTags {
            byDay[day] = ids
        }
        for (day, ids) in byDay {
            try DayTagsRecord(dayNumber: day, tagIds: ids).insert(db)
        }
    }

    // MARK: - Comments

    private static func seedComments(_ db: Database) throws {
        let comments: [(Daystamp, String)] = [
            (day(2026, 4, 8), text(
                "Отличное самочувствие и много сил. Вечером — йога 🧘‍♀️",
                "Feeling great and full of energy. Yoga in the evening 🧘‍♀️"
            )),
            (day(2026, 4, 4), text(
                "Бассейн, проплыла 1 км 🏊‍♀️",
                "Swam 1 km at the pool 🏊‍♀️"
            )),
            (day(2026, 3, 26), text(
                "Тянет низ живота. Грелка и чай с ромашкой — и стало легче",
                "Lower belly ache. A heating pad and chamomile tea helped"
            )),
            (day(2026, 3, 25), text(
                "Начались день в день с прогнозом",
                "Started right on the predicted day"
            )),
            (day(2026, 3, 20), text(
                "ПМС: хочется сладкого и поспать подольше",
                "PMS: craving sweets and extra sleep"
            )),
            (day(2026, 3, 8), text(
                "Цветы и бранч с подругами 🌷",
                "Flowers and brunch with friends 🌷"
            )),
        ]
        for (day, comment) in comments {
            try CommentRecord(dayNumber: day, comment: comment).insert(db)
        }
    }
}
