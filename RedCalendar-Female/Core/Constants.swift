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

        /// A run follows `has_more` — and a wipe, and a `full_resync_required` — around this loop
        /// at most this many times before giving up until the next trigger. At the documented
        /// page size of 1000 rows against an observed maximum of ~260 per user, a second page is
        /// already hypothetical; this is here so that a server that always says `has_more` costs
        /// one bounded run rather than an unbounded one.
        static let maxRoundsPerRun = 50
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
