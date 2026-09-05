//
//  CycleTrendChartView.swift
//  RedCalendar-Female
//

import SwiftUI

/// One column of `CycleTrendChartView` — a cycle's length, split into the part that was period
/// and the part that wasn't.
struct CycleTrendBar: Identifiable {
    var id: Daystamp { startDay }
    let startDay: Daystamp

    /// Days shown solid, from the start of the cycle: the confirmed period length, or — for a
    /// period still open — how far logged flow says it has run so far. Never more than is
    /// actually known, the same rule the calendar's own period bar follows.
    let periodDays: Int

    /// The cycle's real length. `nil` while it's still the most recent cycle and no following
    /// start has fixed it yet — drawn as a dashed outline up to the stored average instead of a
    /// solid fill.
    let cycleLength: Int?
}

/// Builds the last `Constants.Cycle.forecastWindow` cycles for `CycleTrendChartView`.
///
/// `cycles` must be sorted ascending by `startDay` (see `CycleRecord+Queries`).
func cycleTrendBars(
    cycles: [CycleRecord],
    flowLevels: [Daystamp: Int],
    today: Daystamp
) -> [CycleTrendBar] {
    let bars = cycles.indices.map { index -> CycleTrendBar in
        let cycle = cycles[index]
        let periodLength = cycle.periodLength ?? 0

        // Open period: nothing but `markPeriodEnd` closes one, so its length isn't a fact yet —
        // only what flow was actually logged for it is.
        let periodDays = periodLength > 0
            ? periodLength
            : flowLevels.lastFlowDay(of: cycle, notAfter: today).map { $0 - cycle.startDay + 1 } ?? 0

        let cycleLength = index + 1 < cycles.count ? cycles[index + 1].startDay - cycle.startDay : nil
        return CycleTrendBar(startDay: cycle.startDay, periodDays: periodDays, cycleLength: cycleLength)
    }
    return Array(bars.suffix(Constants.Cycle.forecastWindow))
}

/// The last few cycles' length and period, as one bar per cycle: a solid segment for the period,
/// a lighter one for the rest of the cycle — the same colour language the calendar's own period
/// bar uses, so a cycle reads the same way here as it does there.
///
/// Purely decorative: every number it draws is already said in words by `StatisticsView`'s
/// history rows, so it is hidden from VoiceOver rather than narrated bar by bar.
struct CycleTrendChartView: View {
    let bars: [CycleTrendBar]
    /// The stored average, used only to size the dashed outline of a cycle whose real length
    /// isn't known yet.
    let averageCycleLength: Int
    let accent: Color

    private let chartHeight: CGFloat = 90
    // Reserved above and below every bar for its two value labels, so the tallest bar plus both
    // labels still fits inside `chartHeight` rather than a label pushing the column taller than
    // its neighbours.
    private let labelHeight: CGFloat = 14
    private let labelSpacing: CGFloat = 3
    private let barSpacing: CGFloat = 10
    private let cornerRadius: CGFloat = 3

    private var barsHeight: CGFloat {
        chartHeight - labelHeight * 2 - labelSpacing * 2
    }

    private var maxTotal: Int {
        bars.map { total(for: $0) }.max() ?? averageCycleLength
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(bars) { bar in
                column(for: bar)
            }
        }
        .frame(height: chartHeight, alignment: .bottom)
        .accessibilityHidden(true)
    }

    // MARK: - Private Methods

    private func total(for bar: CycleTrendBar) -> Int {
        bar.cycleLength ?? max(averageCycleLength, bar.periodDays)
    }

    @ViewBuilder
    private func column(for bar: CycleTrendBar) -> some View {
        let totalDays = total(for: bar)
        let scale = barsHeight / CGFloat(max(maxTotal, 1))
        let totalHeight = scale * CGFloat(totalDays)
        let periodHeight = min(scale * CGFloat(bar.periodDays), totalHeight)
        let restHeight = totalHeight - periodHeight
        // Rounded on every side only when the period fills the whole bar — otherwise it caps
        // against the rest-of-cycle segment (or the dashed outline) sitting above it.
        let periodCorners: UIRectCorner = (bar.cycleLength == nil || restHeight > 0)
            ? [.bottomLeft, .bottomRight]
            : .allCorners

        VStack(spacing: labelSpacing) {
            // Blank once the cycle's real length isn't known yet — the dashed, unfilled top
            // already says "still running"; a "?" on top of that was saying it twice.
            Text(bar.cycleLength.map { "\($0)" } ?? "")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(height: labelHeight)

            VStack(spacing: 0) {
                if bar.cycleLength == nil {
                    RoundedCorners(radius: cornerRadius, corners: [.topLeft, .topRight])
                        .strokeBorder(accent.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                        .frame(height: restHeight)
                } else if restHeight > 0 {
                    RoundedCorners(radius: cornerRadius, corners: [.topLeft, .topRight])
                        .fill(accent.opacity(0.22))
                        .frame(height: restHeight)
                }

                RoundedCorners(radius: cornerRadius, corners: periodCorners)
                    .fill(accent)
                    .frame(height: max(periodHeight, 2))
            }

            Text(verbatim: "\(bar.periodDays)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(height: labelHeight)
        }
    }
}
