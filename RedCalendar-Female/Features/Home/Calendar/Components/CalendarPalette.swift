//
//  CalendarPalette.swift
//  RedCalendar-Female
//

import SwiftUI

// The colours that do not depend on the chosen accent, resolved once instead of per day cell —
// named assets and UIColor bridging are lookups, not literals. Dynamic colors still resolve
// against the current trait collection.
//
// The accent-derived pair — the period bar, the today marker, the predicted outline and the
// numeral inside it — cannot live here: they follow `AccentTheme`, so they are stored on the
// view and resolved in its init.
//
// Shared by the grid and the selection layer above it, which is why it is a file of its own:
// the disc punches a hole in the page's own colour, and a page colour that drifted from the one
// the day cells draw their rings in would put a seam around every marked day.
enum CalendarPalette {
    static let selected = Color("SelectedDayColor")
    static let background = Color("AppBackgroundColor")
    static let futureDay = Color(UIColor.secondaryLabel)
    static let commentDot = Color(UIColor.secondaryLabel)
    // Assets rather than literals: these carry their weight in a 2pt line, and both the
    // fertile line's alpha and the ovulation orange read very differently against white and
    // against a near-black background, so each needs its own light/dark variant.
    static let fertileLine = Color("FertileLineColor")
    static let ovulationLine = Color("OvulationLineColor")
}

// Built once rather than per numeral, for the same reason `CalendarPalette` exists: the grid
// draws upwards of forty of these on a pass, and every one of them was constructing a `Font`
// from scratch. The selected row draws its digits a second time inside the disc's layer, and
// that one runs on a flight.
enum DayNumberFont {
    static let regular = Font.system(size: 16, weight: .medium)
    static let today = Font.system(size: 16, weight: .bold)

    static func font(isToday: Bool) -> Font {
        isToday ? today : regular
    }
}
