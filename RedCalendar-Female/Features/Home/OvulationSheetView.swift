//
//  OvulationSheetView.swift
//  RedCalendar-Female
//

import SwiftUI

// Reached from the one row `DayDetailsView.ovulationRow` shows — the day named by
// `CycleRecord.effectiveOvulationDay` for the cycle owning it, whether that day is currently
// drawn as predicted, confirmed, or (an anovulatory cycle) predicted with no fertile window
// around it. RedCalendar 2.0 had the same screen; the four options below are its four options.
//
// Three of the four commit on the tap that chose them, the same way every other edit on the day
// card does — there is nothing to confirm about "automatically", "this day", or "no ovulation
// this cycle", so a second "Готово" tap would only be a second tap. Only "Указать день вручную"
// needs one: a day has to be chosen first, and `confirmManualDayButton` under the picker is what
// commits it. Not a `.toolbar` bottom bar — `ToolbarContentBuilder`'s `if` needs iOS 16, and the
// deployment target is 15.4.
struct OvulationSheetView: View {
    @EnvironmentObject var store: AppStore
    let dayStamp: Daystamp
    @Binding var isPresented: Bool

    private enum Mode: Equatable {
        case automatic, confirmed, manual, anovulatory
    }

    @State private var mode: Mode = .automatic
    // Seeded from the stored value in `.onAppear`, or to `dayStamp` when there is none yet.
    @State private var manualDay: Daystamp = 0

    private var calendar: Calendar { .current }

    // MARK: - Body

    // `context` is resolved once here, the same reason `DayDetailsView.body` resolves its own —
    // everything below that used to read a `context` computed property (and re-scan `cycles` on
    // every access) now reads this local instead.
    var body: some View {
        let context = store.state.calendarState.cycles.dayContext(for: dayStamp)
        let storedOvulation = context.owning?.ovulation
        let options = manualDayOptions(context: context)

        NavigationView {
            Form {
                Section {
                    optionRow(
                        mode: .automatic,
                        title: "OvulationEditor.Automatic.Title",
                        subtitle: "OvulationEditor.Automatic.Subtitle"
                    ) {
                        commit(nil)
                    }
                    optionRow(
                        mode: .confirmed,
                        title: "OvulationEditor.Confirmed.Title",
                        subtitle: "OvulationEditor.Confirmed.Subtitle"
                    ) {
                        commit(.confirmed(day: dayStamp))
                    }
                    optionRow(
                        mode: .manual,
                        title: "OvulationEditor.Manual.Title",
                        subtitle: "OvulationEditor.Manual.Subtitle"
                    ) {
                        mode = .manual
                    }
                    if mode == .manual {
                        manualDayPicker(options: options)
                        confirmManualDayButton
                    }
                    optionRow(
                        mode: .anovulatory,
                        title: "OvulationEditor.Anovulatory.Title",
                        subtitle: "OvulationEditor.Anovulatory.Subtitle"
                    ) {
                        commit(.anovulatory)
                    }
                }
            }
            .navigationTitle("OvulationEditor.Title")
            .navigationBarTitleDisplayMode(.inline)
            .closeButtonToolbar { isPresented = false }
        }
        .onAppear {
            mode = resolvedMode(storedOvulation: storedOvulation)
            manualDay = seedManualDay(storedOvulation: storedOvulation, options: options)
        }
    }

    // MARK: - Rows

    // Checkmark rather than a radio circle — `SettingsView.accentThemeSection`'s picker inside the
    // same kind of grouped list, matched rather than reinvented. Always laid out, only faded, for
    // the same reason that row keeps it laid out: inserting and removing the glyph would move the
    // subtitle under it by the glyph's own width the moment an option is picked.
    private func optionRow(
        mode rowMode: Mode,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        let isSelected = mode == rowMode

        return Button(action: action) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(accent)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // A wheel `Picker` over a short, explicit list of days rather than a `DatePicker` — a
    // `DatePicker` reads as "pick any date", with the actual bound only discovered by scrolling
    // into a wall; this reads, at a glance, as the handful of nearby days it actually is. Matches
    // RedCalendar 2.0's own picker, which was the same single column of "6 мая" rows.
    private func manualDayPicker(options: [Daystamp]) -> some View {
        Picker("", selection: $manualDay) {
            ForEach(options, id: \.self) { day in
                Text(dayLabel(day)).tag(day)
            }
        }
        .pickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }

    private func dayLabel(_ day: Daystamp) -> String {
        DayTitleFormatters.formatter(template: "MMMMd").string(from: day.toDate(calendar: calendar))
    }

    private var confirmManualDayButton: some View {
        Button {
            commit(.confirmed(day: manualDay))
        } label: {
            Text("Common.Done")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    // MARK: - Private Methods

    private var accent: Color {
        store.state.accentTheme.accent
    }

    private var today: Daystamp {
        store.state.calendarState.todayDayStamp
    }

    private func resolvedMode(storedOvulation: OvulationData?) -> Mode {
        switch storedOvulation {
        case nil: return .automatic
        case .anovulatory: return .anovulatory
        case .confirmed(let day): return day == dayStamp ? .confirmed : .manual
        }
    }

    /// The day a stored `.manual` answer names, or `nil` when there isn't one — used only to seed
    /// `manualDay` in `.onAppear`, through `seedManualDay(storedOvulation:options:)` below, which
    /// is what actually guards against this day no longer being one `options` offers.
    private func storedManualDay(storedOvulation: OvulationData?) -> Daystamp? {
        guard case .confirmed(let day) = storedOvulation, day != dayStamp else { return nil }
        return day
    }

    /// What `manualDay` should start at: the stored manual day if `options` still offers it,
    /// `dayStamp` if that is offered instead, and the first option otherwise. The middle
    /// fallbacks matter because `options` is computed fresh, from live store state, at the same
    /// moment `storedOvulation` is — a sync pull landing between this sheet's presentation and
    /// this `.onAppear` firing can move the confirmed day to one `options` (centered on the
    /// `dayStamp` this sheet was opened for) no longer contains, which would otherwise leave the
    /// wheel `Picker`'s selection matching none of its own rows.
    private func seedManualDay(storedOvulation: OvulationData?, options: [Daystamp]) -> Daystamp {
        if let stored = storedManualDay(storedOvulation: storedOvulation), options.contains(stored) {
            return stored
        }
        if options.contains(dayStamp) {
            return dayStamp
        }
        return options.first ?? dayStamp
    }

    /// A few days either side of the day the sheet opened on, clamped to what the owning cycle
    /// actually covers and to `today` — the same "no editing the future" rule the row itself is
    /// gated on. Clamped below the next cycle's start too, not only above this one's, so a picked
    /// day can never resolve to a *different* owning cycle than the one this editor is for — see
    /// `Constants.Cycle.ovulationManualPickerRangeDays`.
    private func manualDayOptions(context: CycleDayContext) -> [Daystamp] {
        let lower = max(dayStamp - Constants.Cycle.ovulationManualPickerRangeDays, context.owning?.startDay ?? dayStamp)
        var upper = min(dayStamp + Constants.Cycle.ovulationManualPickerRangeDays, today)
        if let followingStart = context.following?.startDay {
            upper = min(upper, followingStart.advanced(by: -1))
        }
        return Array(lower...max(lower, upper))
    }

    private func commit(_ value: OvulationData?) {
        store.send(.data(.setOvulation(dayStamp, value)))
        isPresented = false
    }
}

#Preview {
    OvulationSheetView(dayStamp: 2000, isPresented: .constant(true))
        .tint(AccentTheme.coral.accent)
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "test"),
                    calendarState: CalendarState(
                        todayDayStamp: 2005,
                        cycles: [CycleRecord(startDay: 1980, periodLength: 5, ovulation: nil, dirtySeq: nil)]
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
