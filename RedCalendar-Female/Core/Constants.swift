//
//  Constants.swift.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.07.2025.
//
import Foundation

struct Constants {
    struct URLs {
        static let appLink = "https://apps.apple.com/app/redcalendar-cycle-tracker/id1535523842"
        static var api: String {
            Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as! String
        }
    }

    struct Calendar {
        // Days loaded around the calendar center (comments/tags observations + display range).
        // Must stay comfortably wider than what the calendar renders around the center
        // (roughly four months either way), otherwise months scroll into view before their
        // cycle bars, dots and comments exist and the data visibly draws itself in.
        static let loadedRangeBuffer = 540
        // Re-center the loaded range when the viewport gets this close to its edge. Kept at
        // half the buffer so the reload happens while the edge is still far offscreen.
        static let rangeExpansionThreshold = 270
        // How far the viewport center must travel before the calendar reports it. Much
        // smaller than the expansion threshold: the store has to learn about the new center
        // in time for the middleware to notice it approached an edge.
        static let centerReportStep = 15
    }

    struct Sheets {
        // How long the comment/tag editors wait after the last edit before autosaving in the
        // background. Long enough that normal typing/tapping doesn't trigger a write per
        // keystroke, short enough that the save has almost always already landed by the time a
        // user who paused then swipes down reaches `onDisappear`. `UInt64` nanoseconds because
        // `Task.sleep(nanoseconds:)` is what the 15.4 deployment target allows — `Task.sleep(for:)`
        // and `Duration` are iOS 16+.
        static let autosaveDebounceNanoseconds: UInt64 = 600_000_000
    }

    struct Sync {
        /// The generation of the table set this build understands (SYNC.md §4.6). Diagnostic on
        /// the server today — it decides nothing there — but it is what makes "which builds are
        /// still calling" answerable from a log.
        static let schemaVersion = 1

        /// How long a local edit waits before it is pushed. The comment editor autosaves every
        /// 600 ms, so without this a sentence typed into a day would be a queue of HTTP requests.
        static let localEditDebounceNanoseconds: UInt64 = 3_000_000_000

        /// Doubling from the first to the second on repeated failure, reset by any success. A
        /// minute's ceiling is also what makes `NWPathMonitor` unnecessary: a network that comes
        /// back while the app is open is noticed within one.
        static let minBackoff: TimeInterval = 2
        static let maxBackoff: TimeInterval = 60

        /// How long the silent-push handler waits for the run that covers its push before it
        /// answers iOS anyway (§8). Under the ~30 s a background delivery is given, with room
        /// left for the handler itself: the point is to answer truthfully *and* to answer.
        static let pushResultBudget: TimeInterval = 20

        /// A run follows `has_more` — and a wipe, and a `full_resync_required` — around this loop
        /// at most this many times before giving up until the next trigger. At the documented
        /// page size of 1000 rows against an observed maximum of ~260 per user, a second page is
        /// already hypothetical; this is here so that a server that always says `has_more` costs
        /// one bounded run rather than an unbounded one.
        static let maxRoundsPerRun = 50

        /// While the server says the Firebase import is still `running` (SYNC.md §10.4), a run
        /// that ends asks again by itself. The same doubling and the same ceiling as the backoff,
        /// from a shorter first step: an import is seconds, so the first question is the one most
        /// likely to be answered, and the ceiling is what keeps an import that will never finish
        /// from costing more than a request a minute.
        static let minImportPoll: TimeInterval = 3
        static let maxImportPoll: TimeInterval = 60

        /// Read by `SyncIndicatorView`, not by anything else in this file's domain — kept here
        /// anyway because it is a sync concept (SYNC.md §9), the same reason
        /// `Sheets.autosaveDebounceNanoseconds` sits next to sync's other debounce rather than in
        /// some future `UI` bucket that does not exist yet.
        ///
        /// How long the indicator waits, once there is something to show, before it actually
        /// draws it. A run that resolves back to `.idle` inside this window — the common case on
        /// a fast connection — never reaches the screen at all: the view keeps the state it is
        /// showing separate from the state it was just handed, and only adopts the new one once
        /// this much time has passed without it reverting.
        ///
        /// 700 ms rather than something closer to Nielsen's ~100 ms "instant" threshold: a sync
        /// round trip is TLS + a server hop + a local GRDB transaction on both ends of it, not a
        /// local computation, so a "fast" run in practice can land anywhere in the hundreds of
        /// milliseconds — 400 ms measured too short on device, still letting an ordinary
        /// successful run flash. 700 ms still sits under the ~1 s where a wait starts reading as
        /// the app hanging, with real headroom above what a normal round trip costs.
        static let indicatorAppearDelayNanoseconds: UInt64 = 700_000_000
    }

    struct Cycle {
        static let minCycleLength = 20
        static let maxCycleLength = 90
        static let minPeriodLength = 1
        static let maxPeriodLength = 14

        // Fallbacks when the user has no cycle settings yet
        static let defaultCycleLength = 28
        static let defaultPeriodLength = 5
        static let defaultLutealPhaseLength = 14

        // Fertile window drawn around ovulation
        static let fertileWindowDaysBefore = 3
        static let fertileWindowDaysAfter = 1
    }
}
