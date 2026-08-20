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
