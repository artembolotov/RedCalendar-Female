//
//  StatisticsPeriod.swift
//  RedCalendar-Female
//

import SwiftUI

/// The averaging window `StatisticsView`'s period menu offers, and `StatisticsAverages` measures
/// over. `windowDays` is `nil` for `.allTime` — no cutoff at all, same plausibility filtering as
/// every other window.
enum StatisticsPeriod: CaseIterable, Identifiable, Equatable {
    case sixMonths
    case year
    case allTime

    var id: Self { self }

    var windowDays: Int? {
        switch self {
        case .sixMonths: return 183
        case .year: return 365
        case .allTime: return nil
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .sixMonths: return "Statistics.Period.SixMonths"
        case .year: return "Statistics.Period.Year"
        case .allTime: return "Statistics.Period.AllTime"
        }
    }
}
