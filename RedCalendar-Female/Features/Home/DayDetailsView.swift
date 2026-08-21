import SwiftUI

enum DayDetailsMetrics {
    // The card's inset from the screen edge. `DayDetailsPagerView` reuses it as the gap
    // between two cards, so it has to be an explicit shared number rather than the
    // system's default padding.
    static let screenInset: CGFloat = 16
}

// Building a `DateFormatter` from a template costs more than the rest of the header put
// together, and a swipe can rebuild three titles per frame — so the two templates the card
// needs are memoized, and dropped when the user's region changes.
private enum DayTitleFormatters {
    private static let lock = NSLock()
    // Every read and write happens inside `lock`'s critical section below — `nonisolated(unsafe)`
    // hands the type system what the lock already guarantees at runtime.
    nonisolated(unsafe) private static var cachedLocaleIdentifier: String?
    nonisolated(unsafe) private static var formatters: [String: DateFormatter] = [:]

    static func formatter(template: String) -> DateFormatter {
        lock.lock()
        defer { lock.unlock() }

        let locale = Locale.current
        if cachedLocaleIdentifier != locale.identifier {
            formatters.removeAll()
            cachedLocaleIdentifier = locale.identifier
        }

        if let cached = formatters[template] {
            return cached
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        formatters[template] = formatter

        return formatter
    }
}

// Natural height of the flow level options, reported from outside the card's layout so the
// card can slide the notes down by exactly that much.
private struct FlowPickerHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
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

    @State private var showFlowPicker = false
    @State private var showTagsSheet = false
    @State private var showCommentSheet = false
    // Measured from the options themselves rather than assumed, so the notes travel the right
    // distance at any Dynamic Type size.
    @State private var flowPickerHeight: CGFloat = 0
    // Whether the content this frame asked for is taller than `maxHeight` — set from the same
    // measurement `reportedHeight` clips, so the two never disagree about whether a cut
    // happened. Drives the fade at the bottom edge that stands in for the part that got cut.
    @State private var isContentClipped = false

    private let globalBottomOffset: CGFloat = 25
    private let cardPadding: CGFloat = 16
    private let cardCornerRadius: CGFloat = 16
    private let flowPickerDuration: TimeInterval = 0.15
    // Shared box for the close button and the flow level circles so both sit
    // trailing-aligned to the same edge and share a centre line.
    private let trailingControlWidth: CGFloat = 28

    // The period button and the flow controls are the accent, not the system red — they mark
    // the same thing the calendar's period bar marks, and two reds in one card read as two
    // different meanings.
    private var accent: Color { store.state.accentTheme.accent }

    private var titleText: String {
        switch dayStamp - today {
        case -2: return "Позавчера"
        case -1: return "Вчера"
        case 0: return "Сегодня"
        case 1: return "Завтра"
        case 2: return "Послезавтра"
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

    private var comment: String? {
        store.state.calendarState.visibleComments[dayStamp]
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

    private func flowLevelLabel(for level: Int?) -> String {
        switch level {
        case 1: return "Скудные"
        case 2: return "Умеренные"
        case 3: return "Обильные"
        default: return "Не указано"
        }
    }

    private let flowLevelOptions: [(Int?, String)] = [
        (1, "Скудные"),
        (2, "Умеренные"),
        (3, "Обильные"),
        (nil, "Не указано")
    ]

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
        let cycleLength = ResolvedCycleSettings(store.state.currentUser?.settings?.cycle).cycleLength
        if let predictedStart = context.predictedCycleStart(cycleLength: cycleLength) {
            let predictedDay = dayStamp - predictedStart + 1
            return "\(cycleDay) (\(predictedDay)) день цикла"
        }
        return "\(cycleDay) день цикла"
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

        VStack(alignment: .leading, spacing: 0) {
            header(subtitle: cycleSubtitleText(context: context))
            if isPeriodActionValid(context: context, buttonState: buttonState) {
                periodButtonRow(buttonState: buttonState)
                    .padding(.top, 12)
            }

            VStack(alignment: .leading, spacing: 0) {
                if context.canSetFlowLevel(today: today) {
                    periodSection(currentLevel: context.recorded?.flowLevel(on: dayStamp))
                        .padding(.top, 16)
                        // The options hang out of the section's box, so the section has to draw
                        // over the notes it pushes down rather than under them.
                        .zIndex(1)
                }
                notesSection
                    .padding(.top, 16)
                    .offset(y: notesOffset)
                    .animation(.easeInOut(duration: flowPickerDuration), value: notesOffset)
            }
            .padding(.top, 4)
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
                        value: isActive && naturalHeight(boxHeight: geometry.size.height) > maxHeight
                    )
            }
        )
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
        .onPreferenceChange(FlowPickerHeightKey.self) { height in
            // The options report nothing while they're closed — keeping the last measurement
            // means the notes have a distance to travel on the very first frame of an opening.
            guard height > 0 else { return }
            flowPickerHeight = height
        }
        .onPreferenceChange(DayCardClippedKey.self) { clipped in
            isContentClipped = clipped
        }
    }

    private var notesOffset: CGFloat {
        showFlowPicker ? flowPickerHeight : 0
    }

    // MARK: - Header

    private func header(subtitle: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titleText)
                    .font(.title)
                    .fontWeight(.bold)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: {
                dismissView()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .frame(width: trailingControlWidth, height: trailingControlWidth)
            }
        }
    }

    // MARK: - Period button

    // The button is the calendar's period bar with a word in it, and it borrows the bar's whole
    // vocabulary rather than approximating it: `periodBarCornerRadius` with `.continuous`
    // corners, a solid accent fill where the day is recorded, and where it is not, the same
    // hollow `predictedBarStrokeWidth` outline the grid draws a prediction with — down to the
    // label taking `predictedDayText`, which is the colour of a numeral inside such an outline.
    // The two shapes mark the same thing, so a difference between them would read as a
    // difference in meaning.
    //
    // The height is not borrowed. At the bar's 22pt the box stops growing with Dynamic Type and
    // a large accessibility size clips the title, so the button keeps sizing to its own text.
    private func periodButtonRow(buttonState: PeriodButtonState) -> some View {
        let isStart = buttonState == .startOutline || buttonState == .startFilled
        let isFilled = buttonState == .startFilled || buttonState == .endFilled
        let title = isStart ? "Начало месячных" : "Конец месячных"
        let shape = RoundedRectangle(
            cornerRadius: CalendarConstants.periodBarCornerRadius,
            style: .continuous
        )

        return Button(action: handlePeriodButton) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isFilled ? .white : store.state.accentTheme.predictedDayText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if isFilled {
                            shape.fill(accent)
                        } else {
                            // `strokeBorder`, as in the grid: the outline stays inside the box
                            // rather than straddling its edge, so the filled and hollow states
                            // occupy exactly the same footprint.
                            shape.strokeBorder(
                                accent,
                                lineWidth: CalendarConstants.predictedBarStrokeWidth
                            )
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

    private func sectionHeader(_ title: String) -> some View {
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
            sectionHeader("Менструация")
            flowLevelRow(currentLevel: currentLevel)
            if showFlowPicker {
                flowLevelPicker(currentLevel: currentLevel)
            }
        }
    }

    private func flowLevelRow(currentLevel: Int?) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: flowPickerDuration)) {
                showFlowPicker.toggle()
            }
        }) {
            HStack {
                Text("Обильность")
                    .foregroundColor(.primary)
                Spacer()
                Text(flowLevelLabel(for: currentLevel))
                    .foregroundColor(accent)
            }
            .padding(.vertical, 12)
        }
    }

    // Opening the picker must not resize the card — the calendar centres on the card's box, so
    // a card that grew would drag the month under it. The options are therefore laid out at
    // their natural height inside a zero-height frame: they hang below the row without the
    // section ever measuring taller, and `notesOffset` slides the notes down by the same
    // distance so the two don't overlap once the animation has settled.
    private func flowLevelPicker(currentLevel: Int?) -> some View {
        VStack(spacing: 0) {
            ForEach(flowLevelOptions, id: \.1) { level, label in
                Button(action: {
                    store.send(.data(.setFlowLevel(dayStamp, level)))
                    withAnimation(.easeInOut(duration: flowPickerDuration)) {
                        showFlowPicker = false
                    }
                }) {
                    HStack {
                        Text(label)
                            .foregroundColor(.primary)
                        Spacer()
                        ZStack {
                            // strokeBorder keeps the outline inside the 22pt box, so the
                            // drawn circle matches the box the centring below aligns.
                            Circle()
                                .strokeBorder(currentLevel == level ? accent : Color.secondary, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            if currentLevel == level {
                                Circle()
                                    .fill(accent)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .frame(width: trailingControlWidth)
                    }
                    .padding(.vertical, 12)
                    .padding(.leading, 16)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: FlowPickerHeightKey.self, value: geometry.size.height)
            }
        )
        .frame(height: 0, alignment: .top)
        .transition(.opacity)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Заметки")

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
                Text("Теги")
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            } else {
                tagsText
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // Concatenated `Text` rather than `FlowLayout`: wrapping is resolved by SwiftUI's own text
    // layout in the same pass as the rest of the card, so it rides the `.cardEntrance` transition
    // like every other label here. `FlowLayout` needs a `GeometryReader`-measured width first,
    // and that measurement lands in its own untransacted `@State` write — the chips pop into
    // their final layout outside the entrance animation instead of sliding in with the card.
    private var tagsText: Text {
        resolvedTags.enumerated().reduce(Text("")) { partial, element in
            let (index, tag) = element
            let segment = Text("#\(tag.name ?? "")")
                .foregroundColor(Color.tagColor(for: tag.category))
            return index == 0 ? segment : partial + Text("  ") + segment
        }
    }

    // The row reads as a writing area rather than a one-line strip, so it keeps a floor of
    // four text lines. Derived from the body font so it grows with Dynamic Type instead of
    // clipping a taller line height.
    private var commentRowMinimumHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .body).lineHeight * 4
    }

    private var commentRowContent: some View {
        Group {
            if let comment = comment, !comment.isEmpty {
                Text(comment)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            } else {
                Text("Комментарий")
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
        }
        .frame(maxWidth: .infinity, minHeight: commentRowMinimumHeight, alignment: .topLeading)
        .padding(.top, 8)
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
            maxHeight: .infinity
        )
    }
    .environmentObject(
        AppStore(
            initialState: AppState(
                authState: .authenticated(deviceId: "test", userDetails: nil),
                calendarState: CalendarState(selectedDayStamp: Daystamp(rawValue: 100))
            ),
            reducer: appReducer,
            middlewares: []
        )
    )
}
