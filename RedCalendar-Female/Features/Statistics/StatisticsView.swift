//
//  StatisticsView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.07.2025.
//

import SwiftUI

/// Cycle history: the two stored averages, a trend of the last few cycles, and every recorded
/// cycle underneath. Read-only — nothing here is edited from this screen, `ProfileView` owns that.
struct StatisticsView: View {
    @EnvironmentObject var store: AppStore

    private var cycles: [CycleRecord] {
        store.state.calendarState.cycles
    }

    private var today: Daystamp {
        store.state.calendarState.todayDayStamp
    }

    private var cycleSettings: ResolvedCycleSettings {
        store.state.cycleSettings
    }

    private var accent: Color {
        store.state.accentTheme.accent
    }

    private var rows: [StatisticsRow] {
        statisticsRows(cycles: cycles, today: today)
    }

    private var trendBars: [CycleTrendBar] {
        cycleTrendBars(cycles: cycles, flowLevels: store.state.calendarState.flowLevels, today: today)
    }

    var body: some View {
        NavigationView {
            Group {
                if cycles.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            averagesRow
                        }

                        Section {
                            VStack(alignment: .leading, spacing: 10) {
                                CycleTrendChartView(
                                    bars: trendBars,
                                    averageCycleLength: cycleSettings.cycleLength,
                                    accent: accent
                                )
                                legend
                            }
                            .padding(.vertical, 4)
                        } header: {
                            Text("Statistics.Chart.Header")
                        }

                        Section {
                            ForEach(rows) { row in
                                historyRow(row)
                            }
                        } header: {
                            Text("Statistics.History.Header")
                        }
                    }
                }
            }
            .navigationTitle("Statistics.Title")
            .navigationBarTitleDisplayMode(.inline)
            .closeButtonToolbar()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack {
            Text("Statistics.Empty")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Averages

    private var averagesRow: some View {
        HStack(spacing: 16) {
            averageTile(header: "Statistics.CycleLength.Header", value: cycleSettings.cycleLength.localizedDays)
            averageTile(header: "Statistics.PeriodLength.Header", value: cycleSettings.periodLength.localizedDays)
        }
        .padding(.vertical, 4)
    }

    private func averageTile(header: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(header)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Chart Legend

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: accent, label: "Statistics.Chart.LegendPeriod")
            legendItem(color: accent.opacity(0.22), label: "Statistics.Chart.LegendRest")
        }
    }

    private func legendItem(color: Color, label: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 9, height: 9)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - History Row

    private func historyRow(_ row: StatisticsRow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateTitle(for: row.startDay))
                Text(subtitleText(for: row.subtitle))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 2)

            Spacer()

            Text(trailerText(for: row.trailer))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // Same year/cross-year template `DayDetailsView`'s own title uses — a history spanning more
    // than one year needs the year to disambiguate, a recent one doesn't.
    private func dateTitle(for day: Daystamp) -> String {
        let calendar = Calendar.current
        let date = day.toDate(calendar: calendar)
        let todayDate = today.toDate(calendar: calendar)
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: todayDate)

        return DayTitleFormatters
            .formatter(template: sameYear ? "MMMMd" : "yMMMMd")
            .string(from: date)
    }

    private func subtitleText(for subtitle: StatisticsRow.Subtitle) -> String {
        switch subtitle {
        case .periodLength(let days):
            return String.localized("Statistics.Row.Period", days.localizedDays)
        case .currentCycleOpen:
            return String(localized: "Statistics.Row.CurrentCycle")
        case .periodNotConfirmed:
            return String(localized: "Statistics.Row.PeriodNotConfirmed")
        }
    }

    private func trailerText(for trailer: StatisticsRow.Trailer) -> String {
        switch trailer {
        case .cycleLength(let days), .daysElapsed(let days):
            return days.localizedDays
        }
    }
}

#Preview {
    StatisticsView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "test-device-id")
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
