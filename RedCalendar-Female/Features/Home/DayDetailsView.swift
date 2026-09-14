import SwiftUI

enum DayDetailsMetrics {
    // The card's inset from the screen edge. `DayDetailsPagerView` reuses it as the gap
    // between two cards, so it has to be an explicit shared number rather than the
    // system's default padding.
    static let screenInset: CGFloat = 16
    // A single-line row with its value or checkmark at the trailing edge — the card's own
    // "Обильность" and "Статус" and the options on the screens they push. One number, so moving
    // from a row to the list it opens does not change how dense a row is.
    static let valueRowVerticalPadding: CGFloat = 15
}

// The four flow levels `FlowLevelEditorView` offers, and the labels both it and
// `DayDetailsView.flowLevelRow` read — one list of the keys rather than two, so the row's own
// trailing value and the editor's options can't disagree.
enum FlowLevelOption {
    static let all: [Int?] = [1, 2, 3, nil]

    static func label(for level: Int?) -> LocalizedStringKey {
        switch level {
        case 1: return "DayDetails.Flow.Light"
        case 2: return "DayDetails.Flow.Moderate"
        case 3: return "DayDetails.Flow.Heavy"
        default: return "DayDetails.Flow.Unset"
        }
    }
}

/// A screen pushed inside the day card, over its root content or over another pushed screen.
/// The pager owns the transitions — it is the one holding the window's pan recognizer, which
/// drives the interactive swipe back.
enum DayCardRoute: Hashable {
    case flowLevel
    case ovulation
    case ovulationManualDay
}

/// A card height together with the day it belongs to.
///
/// The calendar centres the selected day in the space above the card, so it cannot leave until
/// it knows how tall the card for *that* day is. The day travels with the number because the
/// number alone is not the signal: a card keeping its level across a day change reports the same
/// height for a new day, and a new day whose content happens to measure the same as the last
/// one's would otherwise never be reported at all.
struct DayCardHeight: Equatable {
    var day: Daystamp?
    var height: CGFloat

    static let none = DayCardHeight(day: nil, height: 0)
}

// Height the active card's content asks for, reported from inside the card's own layout so the
// pager can decide when to move every card to it. Inactive cards contribute `.none`.
struct DayCardNaturalHeightKey: PreferenceKey {
    static var defaultValue: DayCardHeight { .none }

    static func reduce(value: inout DayCardHeight, nextValue: () -> DayCardHeight) {
        let next = nextValue()
        if next.height > 0 {
            value = next
        }
    }
}

// Whether the active card's content is taller than the ceiling it is being held to, reported
// from the same measurement `DayCardNaturalHeightKey` carries. Read back inside the same view
// that writes it — see the `.onPreferenceChange` in `DayDetailsView.body` — so it never picks up
// a sibling card's overflow while paging.
private struct DayCardClippedKey: PreferenceKey {
    static var defaultValue: Bool { false }

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

// The active card's box, reported up to the pager: it drives the drag gesture's hit test.
// Inactive cards contribute `.zero`. The calendar's centering does not come from here — it is
// written from the level, in `reportedHeight`'s unit, which is the card alone.
struct DayCardFrameKey: PreferenceKey {
    static var defaultValue: CGRect { .zero }

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

struct DayDetailsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var colorScheme

    let dayStamp: Daystamp
    // Only the centre card of the pager reports its frame and follows the dismiss drag.
    // Every input here is a plain value so that sliding the pager doesn't re-run this body.
    let isActive: Bool
    let dragOffset: CGFloat
    // The level every card in the pager is drawn at, in the same units `reportedHeight` uses.
    // `nil` means "your own content decides" — the state of the very first card of an opening.
    let levelHeight: CGFloat?
    // The ceiling on the card's own box, in `reportedHeight`'s unit — see
    // `CalendarView.resolvedMaxCardHeight`. A day whose content asks for more than this is
    // clipped to it rather than pushing its own selected week under the chrome band.
    let maxHeight: CGFloat
    // Written by a row to push a screen and by a screen to go back; the pager animates it.
    @Binding var path: [DayCardRoute]
    // The screens drawn over the root. Keeps the one going away for the whole of its transition.
    let pushedPath: [DayCardRoute]
    // The top screen's transition: 0 is off the card's trailing edge, 1 at rest.
    let navigationProgress: CGFloat
    let cardWidth: CGFloat

    @State private var showTagsSheet = false
    @State private var showCommentSheet = false
    // Whether the content this frame asked for is taller than `maxHeight` — set from the same
    // measurement `reportedHeight` clips, so the two never disagree about whether a cut
    // happened. Drives the fade at the bottom edge that stands in for the part that got cut.
    @State private var isContentClipped = false

    private let globalBottomOffset: CGFloat = 25
    private let cardPadding: CGFloat = 16
    private let cardCornerRadius: CGFloat = 16
    // Shared box for the close button, trailing-aligned to the same edge the other
    // trailing-aligned controls on the card use.
    private let trailingControlWidth: CGFloat = 28

    // The period button and the flow controls are the accent, not the system red — they mark
    // the same thing the calendar's period bar marks, and two reds in one card read as two
    // different meanings.
    private var accent: Color { store.state.accentTheme.accent }

    private var titleText: String {
        switch dayStamp - today {
        case -2: return String(localized: "DayDetails.RelativeDay.DayBeforeYesterday")
        case -1: return String(localized: "DayDetails.RelativeDay.Yesterday")
        case 0: return String(localized: "DayDetails.RelativeDay.Today")
        case 1: return String(localized: "DayDetails.RelativeDay.Tomorrow")
        case 2: return String(localized: "DayDetails.RelativeDay.DayAfterTomorrow")
        default:
            let calendar = Calendar.current
            let date = dayStamp.toDate(calendar: calendar)
            let todayDate = today.toDate(calendar: calendar)

            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: todayDate)

            return DayTitleFormatters
                .formatter(template: sameYear ? "MMMMd" : "yMMMMd")
                .string(from: date)
        }
    }

    // MARK: - Day Data

    private var cycles: [CycleRecord] {
        store.state.calendarState.cycles
    }

    private var today: Daystamp {
        store.state.calendarState.todayDayStamp
    }

    private var cycleSettings: ResolvedCycleSettings {
        store.state.cycleSettings
    }

    private var comment: String? {
        store.state.calendarState.visibleComments[dayStamp]
    }

    /// Read straight off the day, not through the cycle that covers it: the levels are their own
    /// day-keyed table now (see `FlowLevelRecord`). The section this feeds is shown only when
    /// `canSetFlowLevel` holds, which is what still ties it to a recorded period.
    private var flowLevel: Int? {
        store.state.calendarState.flowLevels[dayStamp]
    }

    private var resolvedTags: [UserTagRecord] {
        let tagIds = store.state.calendarState.visibleDayTags[dayStamp] ?? []
        let tagsById = Dictionary(
            store.state.calendarState.userTags.map { ($0.id, $0) },
            uniquingKeysWith: { $1 }
        )
        return tagIds
            .compactMap { tagsById[$0] }
            .filter { $0.name != nil }
            .sorted { ($0.category, $0.name ?? "") < ($1.category, $1.name ?? "") }
    }

    private func ovulationStatusLabel(_ ovulation: OvulationData?) -> LocalizedStringKey {
        switch ovulation {
        case nil: return "DayDetails.Ovulation.Predicted"
        case .anovulatory: return "DayDetails.Ovulation.None"
        case .confirmed: return "DayDetails.Ovulation.Confirmed"
        }
    }

    // MARK: - Cycle subtitle

    private func cycleSubtitleText(context: CycleDayContext) -> String {
        guard let cycle = context.owning else { return "" }
        let cycleDay = dayStamp - cycle.startDay + 1

        // Beyond max cycle length the user most likely forgot to log a new cycle —
        // hide the day count rather than show unrealistic values.
        guard cycleDay <= Constants.Cycle.maxCycleLength else { return "" }

        // Once we've stepped past the first cycle from the last confirmed start, show both
        // the running day count and the day within the current predicted cycle. The context
        // drops the prediction as soon as the next cycle is recorded — the cycle's real
        // length is known then, so a day inside it is only ever its actual day.
        let cycleLength = store.state.cycleSettings.cycleLength
        if let predictedStart = context.predictedCycleStart(cycleLength: cycleLength) {
            let predictedDay = dayStamp - predictedStart + 1
            return String.localized("DayDetails.CycleDay.Predicted.Subtitle", cycleDay, predictedDay)
        }
        return String.localized("DayDetails.CycleDay.Subtitle", cycleDay)
    }

    // MARK: - Period button state

    private enum PeriodButtonState {
        case startOutline
        case startFilled
        case endOutline
        case endFilled
    }

    private func periodButtonState(context: CycleDayContext) -> PeriodButtonState {
        if context.owning?.startDay == dayStamp {
            return .startFilled
        }

        if context.ongoing != nil {
            return .endOutline
        }

        if let cycle = context.completed {
            let lastDay = cycle.startDay.advanced(by: (cycle.periodLength ?? 0) - 1)
            return dayStamp == lastDay ? .endFilled : .endOutline
        }

        return .startOutline
    }

    // Hides the button when there's no meaningful action (middle of a completed period,
    // or when the tap would violate cycle/period limits enforced by middleware).
    //
    // `.startFilled` / `.endFilled` clear existing data, so they stay available even for a
    // future day — otherwise a start or end that arrived from another device could never
    // be undone.
    private func isPeriodActionValid(context: CycleDayContext, buttonState: PeriodButtonState) -> Bool {
        switch buttonState {
        case .startFilled, .endFilled:
            return true
        case .startOutline:
            return cycles.canStartPeriod(at: dayStamp, today: today)
        case .endOutline:
            guard context.canEndPeriod(today: today) else { return false }
            // Inside a completed period (not the last day) — period is already closed, hide.
            if let completed = context.completed,
               completed.startDay < dayStamp,
               dayStamp < completed.startDay.advanced(by: (completed.periodLength ?? 0) - 1) {
                return false
            }
            return true
        }
    }

    // MARK: - Body

    var body: some View {
        // All cycle lookups for this day resolved once per render
        let context = cycles.dayContext(for: dayStamp)
        let buttonState = periodButtonState(context: context)

        let subtitle = cycleSubtitleText(context: context)
        let periodActionValid = isPeriodActionValid(context: context, buttonState: buttonState)
        let showOvulationRow = context.canEditOvulation(today: today, cycleSettings: cycleSettings)

        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                header
                if !subtitle.isEmpty || periodActionValid {
                    chipsRow(subtitle: subtitle, buttonState: buttonState, periodActionValid: periodActionValid)
                        .padding(.top, 8)
                }

                VStack(alignment: .leading, spacing: 0) {
                    if context.canSetFlowLevel(today: today) {
                        periodSection(currentLevel: flowLevel)
                            .padding(.top, 16)
                    }
                    if showOvulationRow {
                        ovulationSection(status: context.owning?.ovulation)
                            .padding(.top, 16)
                    }
                    notesSection
                        .padding(.top, 16)
                }
                // The title and chips are one group above every section, so the first section sits
                // at least as far from them as sections sit from each other (a row's 15 plus 16).
                .padding(.top, 12)
            }
            .padding(cardPadding)
            .padding(.bottom, globalBottomOffset)
            // Keeps the content at the height it asks for so that a level shorter than the content
            // spills past the bottom edge and is cut, rather than squeezing the rows into the box.
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: DayCardNaturalHeightKey.self,
                            value: isActive
                                ? DayCardHeight(day: dayStamp, height: reportedHeight(boxHeight: geometry.size.height))
                                : .none
                        )
                        .preference(
                            key: DayCardClippedKey.self,
                            value: isActive && pushedPath.isEmpty && naturalHeight(boxHeight: geometry.size.height) > maxHeight
                        )
                }
            )
            .offset(x: layerOffset(depth: 0))
            .accessibilityHidden(!isTopLayer(depth: 0))

            // Identified by the route rather than by position: going back to the root from two
            // screens deep drops the middle one first, and the top one must stay the same view.
            ForEach(Array(pushedPath.enumerated()), id: \.element) { index, pushedRoute in
                pushedLayer(pushedRoute, depth: index + 1)
                    .offset(x: layerOffset(depth: index + 1))
                    .accessibilityHidden(!isTopLayer(depth: index + 1))
            }
        }
        // The pull's stretch, and it belongs on this side of the measurement above — which is
        // the only reason it is a padding of its own rather than folded into the one below the
        // content. The two sum to what that single padding always was, so the box is unchanged;
        // what changes is the height the card reports for itself. `dragOffset` returns to zero
        // the instant the finger lifts, while the geometry goes on carrying the pull for the
        // whole `.cardEntrance` spring — so measured from inside, every frame of that return
        // read as the day's own content growing, and the level settle committed about a third
        // of the pull as the card's height a fifth of a second later.
        .padding(.bottom, -dragOffset)
        // A `nil` height is the natural one, so the two cases need no branch here.
        .frame(height: drawnBoxHeight, alignment: .top)
        // `drawnBoxHeight` is `nil` for exactly one window: between mount and the first
        // `DayCardNaturalHeightKey` measurement landing, which is also when `.move(edge: .bottom)`
        // (see `HomeView`) takes its offset from this view's own current height. Left
        // unconstrained, a long comment draws its full natural height there — well past
        // `maxHeight` — and the entrance spring leaves from that inflated height only to have it
        // snap down, without animation, the instant the measurement arrives (`applyLevel` in
        // `DayDetailsPagerView`). The transition's offset, recomputed from the now-smaller box,
        // jumps with it and tears the card's bottom edge away from the screen mid-flight — the
        // rubber-band drag never shows this because its `drawnBoxHeight` is exact from the first
        // frame. Capping this pre-measurement frame at the same ceiling the settled one already
        // obeys removes the inflated starting point instead of papering over its landing: a short
        // card's natural height never reaches it, so nothing here changes for it.
        .frame(maxHeight: levelHeight == nil ? maxHeight + globalBottomOffset : nil, alignment: .top)
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding([.top, .trailing], cardPadding)
        }
        // The card is a fixed box: the open flow picker and the notes it pushes down run past
        // the bottom edge and are cut there instead of making the card taller. A comment long
        // enough to hit `maxHeight` is cut the same way — the fade below is what tells the two
        // apart from a card that simply ends.
        .overlay(alignment: .bottom) {
            if isContentClipped {
                LinearGradient(
                    colors: [cardBackgroundColor.opacity(0), cardBackgroundColor],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: truncationFadeHeight)
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        // Clipping hides the rows pushed past the edge but still lets them take a tap, so the
        // hit area is cut back to the card as well.
        .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius))
        .background(
            RoundedRectangle(cornerRadius: cardCornerRadius)
                .adaptiveBackground(colorScheme: colorScheme)
                .adaptiveShadow(colorScheme: colorScheme)
        )
        .padding([.horizontal, .top], DayDetailsMetrics.screenInset)
        .offset(y: globalBottomOffset)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: DayCardFrameKey.self, value: reportedFrame(geometry.frame(in: .global)))
            }
        )
        .sheet(isPresented: $showTagsSheet) {
            TagsSheetView(dayStamp: dayStamp, isPresented: $showTagsSheet)
                .environmentObject(store)
                .tint(store.state.accentTheme.accent)
        }
        .sheet(isPresented: $showCommentSheet) {
            CommentSheetView(dayStamp: dayStamp, isPresented: $showCommentSheet)
                .environmentObject(store)
                .tint(store.state.accentTheme.accent)
        }
        .onPreferenceChange(DayCardClippedKey.self) { clipped in
            isContentClipped = clipped
        }
    }

    // MARK: - Pushed screens

    private let underlayParallax: CGFloat = 0.3

    // The top screen slides in from the trailing edge; the one under it slides a third of the way
    // out, as a navigation controller's does; anything deeper stays where that left it.
    private func layerOffset(depth: Int) -> CGFloat {
        let top = pushedPath.count
        if depth == top && top > 0 {
            return cardWidth * (1 - navigationProgress)
        }
        if depth == top - 1 {
            return -cardWidth * underlayParallax * navigationProgress
        }
        return depth < top ? -cardWidth * underlayParallax : 0
    }

    private func isTopLayer(depth: Int) -> Bool {
        let top = pushedPath.count
        guard top > 0 else { return depth == 0 }
        return navigationProgress > 0.5 ? depth == top : depth == top - 1
    }

    // Drawn in the root's own box — the card keeps its height while a screen is pushed, so the
    // calendar under it has nothing to re-centre on. Opaque and stretched to the whole box, so
    // the screen underneath does not show below one shorter than it.
    private func pushedLayer(_ pushedRoute: DayCardRoute, depth: Int) -> some View {
        let isTop = depth == pushedPath.count

        return Group {
            switch pushedRoute {
            case .flowLevel:
                FlowLevelEditorView(
                    dayStamp: dayStamp,
                    path: $path,
                    trailingControlWidth: trailingControlWidth
                )
            case .ovulation:
                OvulationEditorView(
                    dayStamp: dayStamp,
                    path: $path,
                    trailingControlWidth: trailingControlWidth
                )
            case .ovulationManualDay:
                OvulationManualDayView(
                    dayStamp: dayStamp,
                    path: $path,
                    trailingControlWidth: trailingControlWidth
                )
            }
        }
        .padding(cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(cardBackgroundColor)
        .shadow(color: .black.opacity(isTop ? 0.12 * (1 - navigationProgress) : 0), radius: 8, x: -2)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            Text(titleText)
                .font(.title)
                .fontWeight(.bold)

            Spacer()

            // The close button's slot — the button itself is `closeButton`, drawn over every
            // screen of the card so a push does not carry it away.
            Color.clear
                .frame(width: trailingControlWidth, height: trailingControlWidth)
        }
    }

    // Above both layers and outside the slide, so it stays put through a push and a swipe back.
    // Whatever slides under it dissolves into a disc of the card's own colour rather than being
    // cut by the glyph's edge; at rest nothing is under it and the disc is invisible.
    private var closeButton: some View {
        Button(action: dismissView) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(stops: [
                                .init(color: cardBackgroundColor, location: 0),
                                .init(color: cardBackgroundColor, location: 0.55),
                                .init(color: cardBackgroundColor.opacity(0), location: 1)
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: closeButtonPlateRadius
                        )
                    )
                    .frame(width: closeButtonPlateRadius * 2, height: closeButtonPlateRadius * 2)

                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .frame(width: trailingControlWidth, height: trailingControlWidth)
            }
            .frame(width: trailingControlWidth, height: trailingControlWidth)
        }
        .accessibilityLabel(Text("Common.Close"))
    }

    private let closeButtonPlateRadius: CGFloat = 26

    // MARK: - Chips row

    // The cycle day and the period action used to be a subtitle followed by a full-width button
    // underneath it — two different vocabularies for two facts about the same day. Both are now
    // chips, in the row `TagsSheetView`'s tag row already draws below: the day card reads as one
    // row of facts about the day, then another. The period chip leads when it's shown — it's the
    // one actionable thing in the row, and the tappable element leading reads as the row's point
    // rather than an afterthought tacked onto a plain fact. The cycle-day chip is neutral and
    // inert — it states a number, it does nothing — so only the period chip needs a tap target.
    private func chipsRow(subtitle: String, buttonState: PeriodButtonState, periodActionValid: Bool) -> some View {
        HStack(spacing: 8) {
            if periodActionValid {
                periodChip(buttonState: buttonState)
            }
            if !subtitle.isEmpty {
                cycleDayChip(subtitle)
            }
        }
    }

    private func cycleDayChip(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: TagChipMetrics.cornerRadius)
                    .fill(Color(UIColor.tertiarySystemFill))
            )
    }

    // Drawn in `TagChip`'s own vocabulary now — 8pt corner, 12/6 padding, outline text in the
    // chip's own colour — rather than the calendar period bar's shape, since it sits in the same
    // row as the cycle-day chip instead of standing alone as a CTA under the title. What still
    // carries over unchanged is `PeriodButtonState`'s meaning: solid accent once a day is
    // recorded, a hollow accent outline while the tap would still start or end one.
    private func periodChip(buttonState: PeriodButtonState) -> some View {
        let isStart = buttonState == .startOutline || buttonState == .startFilled
        let isFilled = buttonState == .startFilled || buttonState == .endFilled
        let title: LocalizedStringKey = isStart ? "DayDetails.Period.Start.Button" : "DayDetails.Period.End.Button"
        let shape = RoundedRectangle(cornerRadius: TagChipMetrics.cornerRadius)

        return Button(action: handlePeriodButton) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isFilled ? .white : accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Group {
                        if isFilled {
                            shape.fill(accent)
                        } else {
                            // `strokeBorder`, as `TagChip` draws it: the outline stays inside the
                            // box rather than straddling its edge, so the filled and hollow
                            // states occupy exactly the same footprint.
                            shape.strokeBorder(accent, lineWidth: TagChipMetrics.lineWidth)
                        }
                    }
                )
        }
    }

    // Resolved here rather than handed down from `body`: this runs once per tap, and a
    // database observation landing between the last render and the tap would leave a
    // captured context stale.
    private func handlePeriodButton() {
        switch periodButtonState(context: cycles.dayContext(for: dayStamp)) {
        case .startOutline, .startFilled:
            store.send(.data(.markPeriodStart(dayStamp)))
        case .endOutline:
            store.send(.data(.markPeriodEnd(dayStamp)))
        case .endFilled:
            store.send(.data(.unmarkPeriodEnd(dayStamp)))
        }
    }

    // MARK: - Sections

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            Divider()
        }
    }

    private func periodSection(currentLevel: Int?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("DayDetails.Period.Header")
            flowLevelRow(currentLevel: currentLevel)
        }
    }

    // Pushes `FlowLevelEditorView` inside the card.
    private func flowLevelRow(currentLevel: Int?) -> some View {
        Button(action: { path = [.flowLevel] }) {
            HStack {
                Text("DayDetails.Flow.Title")
                    .foregroundColor(.primary)
                Spacer()
                // Secondary, as a value cell beside a disclosure chevron draws it — the accent
                // would make the value read as its own control rather than as the row's state.
                Text(FlowLevelOption.label(for: currentLevel))
                    .foregroundColor(.secondary)
                DisclosureIndicator()
            }
            .padding(.vertical, DayDetailsMetrics.valueRowVerticalPadding)
        }
    }

    // Shown only on the one day `context.isOvulationDay` names — see
    // `CycleRecord.effectiveOvulationDay` for why that day exists even for an anovulatory cycle,
    // which is what keeps this reachable to undo "Нет". Built as `periodSection` is: the header
    // names the subject, the row names what about it is being set.
    private func ovulationSection(status: OvulationData?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("DayDetails.Ovulation.Header")
            Button(action: { path = [.ovulation] }) {
                HStack {
                    Text("DayDetails.Ovulation.Status.Title")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(ovulationStatusLabel(status))
                        .foregroundColor(.secondary)
                    DisclosureIndicator()
                }
                .padding(.vertical, DayDetailsMetrics.valueRowVerticalPadding)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("DayDetails.Notes.Header")

            Button(action: { showTagsSheet = true }) {
                tagsRowContent
            }

            Button(action: { showCommentSheet = true }) {
                commentRowContent
            }
        }
    }

    private var tagsRowContent: some View {
        Group {
            if resolvedTags.isEmpty {
                Text("DayDetails.Tags.Placeholder")
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            } else {
                tagsText
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The divider above is as far off as `flowLevelRow`'s. Below, the tags and the comment share
        // `notesRowGap` between them.
        .padding(.top, DayDetailsMetrics.valueRowVerticalPadding)
        .padding(.bottom, notesRowGap / 2)
    }

    // Concatenated `Text` rather than `FlowLayout`: wrapping is resolved by SwiftUI's own text
    // layout in the same pass as the rest of the card, so it rides the `.cardEntrance` transition
    // like every other label here. `FlowLayout` needs a `GeometryReader`-measured width first,
    // and that measurement lands in its own untransacted `@State` write — the chips pop into
    // their final layout outside the entrance animation instead of sliding in with the card.
    private var tagsText: Text {
        resolvedTags.enumerated().reduce(Text(verbatim: "")) { partial, element in
            let (index, tag) = element
            let segment = Text(verbatim: "#" + (tag.name ?? ""))
                .foregroundColor(Color.tagColor(for: tag.category))
            return index == 0 ? segment : partial + Text(verbatim: "  ") + segment
        }
    }

    // The row reads as a writing area rather than a one-line strip, so it keeps a floor of
    // four text lines. Derived from the body font so it grows with Dynamic Type instead of
    // clipping a taller line height.
    private var commentRowMinimumHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight * 4
    }

    // Between the tags and the comment, which have no divider between them. A full row's padding
    // on each side (30) left them looking like unrelated blocks, a single one (15) like two lines
    // of the same paragraph; 22 puts one line of body text every 44pt, the system's row pitch.
    private let notesRowGap: CGFloat = 22

    private var commentRowContent: some View {
        Group {
            if let comment = comment, !comment.isEmpty {
                Text(comment)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            } else {
                Text("DayDetails.Comment.Placeholder")
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
        }
        .frame(maxWidth: .infinity, minHeight: commentRowMinimumHeight, alignment: .topLeading)
        .padding(.top, notesRowGap / 2)
        .padding(.bottom, 12)
    }

    // MARK: - Frame reporting

    // How tall the content actually asked to be, in the same unit `reportedHeight` reports in.
    // Kept separate from it so both `reportedHeight` (which clips) and the clipped-detection
    // preference (which needs the *un*clipped number to notice the clip happened) read off one
    // calculation instead of two that could drift apart.
    private func naturalHeight(boxHeight: CGFloat) -> CGFloat {
        boxHeight - globalBottomOffset
    }

    // The level the pager works in is the card's own box as it stands on screen: the measured
    // height less the bottom offset that hangs off the screen edge, and never past `maxHeight` —
    // the calendar centres the selected day in the space above this box, and a box taller than
    // that ceiling would push the day itself under the chrome band. The inset above the box is
    // deliberately *not* part of it — that band is where the shadow is drawn, and counting it
    // centred the selected day in the space above the shadow rather than above the card. Both
    // conversions live here so the pager only ever handles one unit.
    private func reportedHeight(boxHeight: CGFloat) -> CGFloat {
        min(naturalHeight(boxHeight: boxHeight), maxHeight)
    }

    // Matches `.adaptiveBackground(colorScheme:)`'s two fills exactly, so the fade dissolves
    // into a colour the card's own surface actually is rather than an approximation of it.
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }

    // Tall enough to read as a dissolve rather than a stripe — measured against the same
    // `commentRowMinimumHeight` floor the row itself keeps, so the fade never claims more than
    // a fraction of even the shortest comment box.
    private let truncationFadeHeight: CGFloat = 40

    private var drawnBoxHeight: CGFloat? {
        guard let levelHeight = levelHeight else { return nil }
        return max(0, levelHeight + globalBottomOffset - dragOffset)
    }

    // The pager slides the card with `.offset`, so the reported global frame moves sideways
    // on every drag frame. The card spans the full width at rest, so the horizontal position
    // is dropped rather than reported — otherwise every frame of a swipe would look like a
    // new box to the pager.
    private func reportedFrame(_ globalFrame: CGRect) -> CGRect {
        guard isActive else { return .zero }

        return CGRect(
            x: 0,
            y: globalFrame.minY + globalBottomOffset,
            width: globalFrame.width,
            height: globalFrame.height - globalBottomOffset
        )
    }

    private func dismissView() {
        store.send(.calendar(.selectDay(nil)))
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        DayDetailsView(
            dayStamp: 2000,
            isActive: true,
            dragOffset: 0,
            levelHeight: nil,
            maxHeight: .infinity,
            path: .constant([]),
            pushedPath: [],
            navigationProgress: 0,
            cardWidth: 360
        )
    }
    .environmentObject(
        AppStore(
            initialState: AppState(
                authState: .authenticated(deviceId: "test"),
                calendarState: CalendarState(selectedDayStamp: Daystamp(rawValue: 100))
            ),
            reducer: appReducer,
            middlewares: []
        )
    )
}
