//
//  StatisticsView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.07.2025.
//

import SwiftUI

// Reports a header's own (unwrapped-by-height) rendered height so `averagesRow` can give both
// tiles' headers the same box — reduced to the taller one, same pattern as
// `DayDetailsPagerView`'s `DayCardNaturalHeightKey`.
private struct StatisticsHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Cycle history: the two windowed averages (`StatisticsAverages`), a trend of the last few
/// cycles, and every recorded cycle underneath. Read-only — nothing here is edited from this
/// screen, `ProfileView` owns that.
struct StatisticsView: View {
    @EnvironmentObject var store: AppStore
    @State private var headerHeight: CGFloat = 0

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

    // Falls back to `cycleSettings` — the forecast/typed value — whenever the window has nothing
    // plausible to average, so a tile is never left blank.
    private var averages: StatisticsAverages {
        StatisticsAverages(cycles: cycles, today: today)
    }

    // Reversed from `cycleTrendBars`' chronological order: the chart reads the same direction
    // as the history list below it, current cycle first.
    private var trendBars: [CycleTrendBar] {
        Array(cycleTrendBars(cycles: cycles, flowLevels: store.state.calendarState.flowLevels, today: today).reversed())
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
            averageTile(
                header: "Statistics.CycleLength.Header",
                value: (averages.cycleLength ?? cycleSettings.cycleLength).localizedDays
            )
            averageTile(
                header: "Statistics.PeriodLength.Header",
                value: (averages.periodLength ?? cycleSettings.periodLength).localizedDays
            )
        }
        .padding(.vertical, 4)
        .onPreferenceChange(StatisticsHeaderHeightKey.self) { headerHeight = $0 }
    }

    // One of the two headers ("Average period length") wraps onto more lines in Russian than the
    // other, so a plain VStack puts the two values on different baselines. `headerHeight` is
    // measured from whichever header actually wraps the most — at the current Dynamic Type size,
    // not a guessed line count — and applied as a floor to both, so the shorter header leaves
    // blank space below it instead of the value sitting higher.
    private func averageTile(header: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(header)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(key: StatisticsHeaderHeightKey.self, value: geometry.size.height)
                    }
                )
                .frame(minHeight: headerHeight, alignment: .topLeading)
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

            trailerView(for: row.trailer)
        }
    }

    // MARK: - History Trailer

    @ViewBuilder
    private func trailerView(for trailer: StatisticsRow.Trailer) -> some View {
        switch trailer {
        case .cycleLength(let days):
            // The same gray pill `DayDetailsView`'s cycle-day readout draws in — a recorded
            // cycle's length is the same kind of plain fact, not a control.
            durationChip(days.localizedDays)
        case .cycleLengthImplausible:
            // A gap this large almost always means a period went unlogged in between — showing
            // the raw number would read as a real, very long cycle rather than a data gap.
            durationChip("—")
        case .daysElapsed(let days):
            // Still counting, not yet a settled fact — same chip shape so the row still lines up
            // with the others, just with nothing filled in behind it.
            durationChip(days.localizedDays, filled: false)
        }
    }

    private func durationChip(_ text: String, filled: Bool = true) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: TagChipMetrics.cornerRadius)
                    .fill(filled ? Color(UIColor.tertiarySystemFill) : Color.clear)
            )
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
