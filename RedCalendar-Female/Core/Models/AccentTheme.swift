//
//  AccentTheme.swift
//  RedCalendar-Female
//

// The accent the user picked in settings. Every case names two assets rather than carrying
// literals: each colour needs its own light and dark variant, and the constraint behind those
// variants — white numerals on the period bar pulling the accent darker while separation from
// the near-black page pulls it lighter — is recorded in CLAUDE.md.
enum AccentTheme: String, CaseIterable, Identifiable, Equatable {
    case coral
    case rose
    case berry

    static let fallback: AccentTheme = .coral

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coral: return "Коралл"
        case .rose:  return "Роза"
        case .berry: return "Малина"
        }
    }

    // Coral keeps the unqualified asset names on purpose. `AccentColor` is also the target's
    // global accent — it has to go on carrying a real colour whatever the picker says — so
    // giving coral a second name of its own would leave two places to edit for one colour.
    var accentAssetName: String {
        switch self {
        case .coral: return "AccentColor"
        case .rose:  return "AccentRose"
        case .berry: return "AccentBerry"
        }
    }

    var predictedTextAssetName: String {
        switch self {
        case .coral: return "PredictedDayTextColor"
        case .rose:  return "PredictedDayTextRose"
        case .berry: return "PredictedDayTextBerry"
        }
    }
}
