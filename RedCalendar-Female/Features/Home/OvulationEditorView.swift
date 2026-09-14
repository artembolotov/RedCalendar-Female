//
//  OvulationEditorView.swift
//  RedCalendar-Female
//

import SwiftUI

// Pushed inside the day card (see `DayCardRoute`) from the status row of
// `DayDetailsView.ovulationSection` — shown on the day `CycleRecord.effectiveOvulationDay` names
// for the cycle owning it, whether that day is currently drawn as predicted, confirmed, or (an
// anovulatory cycle) predicted with no fertile window around it. RedCalendar 2.0 had the same
// screen; the four options below are its four options.
//
// Three of the four commit on the tap that chose them and go back to the card — there is nothing
// to confirm about "automatically", "this day", or "no ovulation this cycle". "Указать день
// вручную" pushes `OvulationManualDayView` instead: a day has to be chosen first.
//
// Plain rows rather than a `Form`: a scroll view inside the card would race the window's pan
// recognizer for every vertical drag, and four options never need to scroll.
struct OvulationEditorView: View {
    @EnvironmentObject var store: AppStore
    let dayStamp: Daystamp
    @Binding var path: [DayCardRoute]
    let trailingControlWidth: CGFloat

    private enum Mode: Equatable {
        case automatic, confirmed, manual, anovulatory
    }

    // MARK: - Body

    // The mode is read from the store on every pass rather than seeded in `onAppear`, which a
    // screen entering from past the card's edge only receives once the slide is well under way.
    var body: some View {
        let storedOvulation = store.state.calendarState.cycles.dayContext(for: dayStamp).owning?.ovulation
        let mode = resolvedMode(storedOvulation: storedOvulation)

        VStack(alignment: .leading, spacing: 0) {
            DayCardPushedHeader(
                title: "OvulationEditor.Title",
                path: $path,
                trailingControlWidth: trailingControlWidth
            )

            VStack(alignment: .leading, spacing: 0) {
                optionRow(isSelected: mode == .automatic, title: "OvulationEditor.Automatic.Title") {
                    Text("OvulationEditor.Automatic.Subtitle")
                } action: {
                    commit(nil)
                }
                Divider()
                optionRow(isSelected: mode == .confirmed, title: "OvulationEditor.Confirmed.Title") {
                    Text("OvulationEditor.Confirmed.Subtitle")
                } action: {
                    commit(.confirmed(day: dayStamp))
                }
                Divider()
                optionRow(isSelected: mode == .manual, title: "OvulationEditor.Manual.Title", pushes: true) {
                    // The day already chosen, when there is one, says more than a description of
                    // what choosing does.
                    if case .confirmed(let day) = storedOvulation, mode == .manual {
                        Text(verbatim: OvulationEditorView.dayLabel(day))
                    } else {
                        Text("OvulationEditor.Manual.Subtitle")
                    }
                } action: {
                    path.append(.ovulationManualDay)
                }
                Divider()
                optionRow(isSelected: mode == .anovulatory, title: "OvulationEditor.Anovulatory.Title") {
                    Text("OvulationEditor.Anovulatory.Subtitle")
                } action: {
                    commit(.anovulatory)
                }
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Rows

    // Checkmark always laid out, only faded — inserting and removing the glyph would move the
    // subtitle under it by the glyph's own width the moment an option is picked.
    private func optionRow<Subtitle: View>(
        isSelected: Bool,
        title: LocalizedStringKey,
        pushes: Bool = false,
        @ViewBuilder subtitle: () -> Subtitle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundColor(.primary)
                    subtitle()
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(store.state.accentTheme.accent)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
                if pushes {
                    DisclosureIndicator()
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Private Methods

    private func resolvedMode(storedOvulation: OvulationData?) -> Mode {
        switch storedOvulation {
        case nil: return .automatic
        case .anovulatory: return .anovulatory
        case .confirmed(let day): return day == dayStamp ? .confirmed : .manual
        }
    }

    private func commit(_ value: OvulationData?) {
        store.send(.data(.setOvulation(dayStamp, value)))
        path = []
    }

    // MARK: - Shared

    static func dayLabel(_ day: Daystamp) -> String {
        DayTitleFormatters.formatter(template: "MMMMd").string(from: day.toDate(calendar: .current))
    }

    /// A few days either side of the day the editor opened on, clamped to what the owning cycle
    /// covers, to `today` — the same "no editing the future" rule the row itself is gated on — and
    /// below the next cycle's start, so a picked day can never resolve to a *different* owning
    /// cycle than the one this editor is for. See `Constants.Cycle.ovulationManualPickerRangeDays`.
    static func manualDayOptions(dayStamp: Daystamp, context: CycleDayContext, today: Daystamp) -> [Daystamp] {
        let lower = max(dayStamp - Constants.Cycle.ovulationManualPickerRangeDays, context.owning?.startDay ?? dayStamp)
        var upper = min(dayStamp + Constants.Cycle.ovulationManualPickerRangeDays, today)
        if let followingStart = context.following?.startDay {
            upper = min(upper, followingStart.advanced(by: -1))
        }
        return Array(lower...max(lower, upper))
    }
}

// The second level: the days `manualDayOptions` offers, laid out as the weeks they fall in rather
// than as a wheel. A handful of days reads at a glance on the calendar's own grid, and the days
// around them that cannot be chosen stay visible — dimmed — so the week still reads as a week.
// A tap commits and goes all the way back to the card, as every other ovulation answer does.
struct OvulationManualDayView: View {
    @EnvironmentObject var store: AppStore
    let dayStamp: Daystamp
    @Binding var path: [DayCardRoute]
    let trailingControlWidth: CGFloat

    private let cellSize: CGFloat = 40

    private var calendar: Calendar { .current }

    // MARK: - Body

    var body: some View {
        let context = store.state.calendarState.cycles.dayContext(for: dayStamp)
        let options = OvulationEditorView.manualDayOptions(
            dayStamp: dayStamp,
            context: context,
            today: store.state.calendarState.todayDayStamp
        )
        let selected: Daystamp? = {
            if case .confirmed(let day) = context.owning?.ovulation { return day }
            return nil
        }()

        VStack(alignment: .leading, spacing: 0) {
            DayCardPushedHeader(
                title: "OvulationEditor.ManualDay.Title",
                path: $path,
                trailingControlWidth: trailingControlWidth
            )

            if let first = options.first, let last = options.last {
                VStack(spacing: 4) {
                    weekdayHeader

                    ForEach(weeks(from: first, to: last), id: \.self) { weekStart in
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { offset in
                                let day = weekStart + offset
                                dayCell(day, isOption: options.contains(day), isSelected: day == selected)
                            }
                        }
                    }
                }
                .padding(.top, 16)
            }
        }
    }

    // MARK: - Grid

    private var weekdayHeader: some View {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        let ordered = Array(symbols[first...] + symbols[..<first])

        return HStack(spacing: 0) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(verbatim: symbol.localizedCapitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    // The day the editor opened on keeps a ring, so the prediction the manual answer is being
    // measured against stays in sight.
    private func dayCell(_ day: Daystamp, isOption: Bool, isSelected: Bool) -> some View {
        let accent = store.state.accentTheme.accent
        let number = calendar.component(.day, from: day.toDate(calendar: calendar))

        return Button {
            store.send(.data(.setOvulation(dayStamp, .confirmed(day: day))))
            path = []
        } label: {
            Text(verbatim: "\(number)")
                .font(.body.weight(isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : (isOption ? .primary : Color(UIColor.tertiaryLabel)))
                .frame(width: cellSize, height: cellSize)
                .background(Circle().fill(isSelected ? accent : Color.clear))
                .overlay(
                    Circle()
                        .strokeBorder(accent, lineWidth: 1.5)
                        .opacity(day == dayStamp && !isSelected ? 1 : 0)
                )
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .disabled(!isOption)
        .accessibilityLabel(Text(verbatim: OvulationEditorView.dayLabel(day)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func weeks(from first: Daystamp, to last: Daystamp) -> [Daystamp] {
        let start = first - weekdayOffset(of: first)
        return Array(stride(from: start, through: last, by: 7))
    }

    private func weekdayOffset(of day: Daystamp) -> Int {
        let weekday = calendar.component(.weekday, from: day.toDate(calendar: calendar))
        return (weekday - calendar.firstWeekday + 7) % 7
    }
}
