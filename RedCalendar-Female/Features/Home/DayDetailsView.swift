import SwiftUI

struct DayDetailsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var colorScheme

    let dayStamp: Daystamp

    @Binding var dragOffset: CGFloat
    @Binding var height: CGFloat

    @State private var viewFrame: CGRect = .zero
    @State private var showFlowPicker = false
    @State private var showTagsSheet = false
    @State private var showCommentSheet = false

    private var isCurrentlySelected: Bool {
        store.state.calendarState.selectedDayStamp?.rawValue == dayStamp.rawValue
    }

    private let velocityThreshold: CGFloat = 1200
    private let rubberBandFactor: CGFloat = 0.3
    private let bottomThreshold: CGFloat = 250
    private let maxUpwardOffset: CGFloat = 150
    private let globalBottomOffset: CGFloat = 25

    private var titleText: String {
        let today = store.state.calendarState.todayDayStamp
        let diff = dayStamp.rawValue - today.rawValue

        switch diff {
        case -2: return "Позавчера"
        case -1: return "Вчера"
        case 0: return "Сегодня"
        case 1: return "Завтра"
        case 2: return "Послезавтра"
        default:
            let calendar = Calendar.current
            let date = dayStamp.toDate(calendar: calendar)
            let todayDate = today.toDate(calendar: calendar)
            let formatter = DateFormatter()
            formatter.locale = Locale.current

            let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: todayDate)
            formatter.setLocalizedDateFormatFromTemplate(sameYear ? "MMMMd" : "yMMMMd")

            return formatter.string(from: date)
        }
    }

    // MARK: - Day Data

    private var cycles: [CycleRecord] {
        store.state.calendarState.cycles
    }

    private var displayState: DayDisplayState? {
        store.state.calendarState.dayDisplayStates[dayStamp]
    }

    private var comment: String? {
        store.state.calendarState.visibleComments[dayStamp]
    }

    private var resolvedTags: [UserTagRecord] {
        let tagIds = store.state.calendarState.visibleDayTags[dayStamp] ?? []
        let tagsById = Dictionary(uniqueKeysWithValues: store.state.calendarState.userTags.map { ($0.id, $0) })
        return tagIds
            .compactMap { tagsById[$0] }
            .filter { $0.name != nil }
            .sorted { ($0.category ?? 0, $0.name ?? "") < ($1.category ?? 0, $1.name ?? "") }
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
        let cycleDay = dayStamp.rawValue - cycle.startDay + 1

        // Beyond max cycle length the user most likely forgot to log a new cycle —
        // hide the day count rather than show unrealistic values.
        guard cycleDay <= Constants.Cycle.maxCycleLength else { return "" }

        // Once we've stepped past the first cycle from the last confirmed start, show
        // both the running day count and the day within the current predicted cycle.
        let defaultLength = store.state.currentUser?.settings?.cycle?.defaultLength
            ?? Constants.Cycle.defaultCycleLength
        if let predictedStart = cycle.predictedCycleStart(for: dayStamp.rawValue, defaultLength: defaultLength) {
            let predictedDay = dayStamp.rawValue - predictedStart + 1
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
        if context.owning?.startDay == dayStamp.rawValue {
            return .startFilled
        }

        if context.ongoing != nil {
            return .endOutline
        }

        if let cycle = context.completed {
            let lastDay = cycle.startDay + (cycle.periodLength ?? 0) - 1
            return dayStamp.rawValue == lastDay ? .endFilled : .endOutline
        }

        return .startOutline
    }

    // Hides the button when there's no meaningful action (middle of a completed period,
    // or when the tap would violate cycle/period limits enforced by middleware).
    private func isPeriodActionValid(context: CycleDayContext, buttonState: PeriodButtonState) -> Bool {
        switch buttonState {
        case .startFilled, .endFilled:
            return true
        case .startOutline:
            return cycles.canStartPeriod(at: dayStamp.rawValue)
        case .endOutline:
            // Inside a completed period (not the last day) — period is already closed, hide.
            if let completed = context.completed,
               completed.startDay < dayStamp.rawValue,
               dayStamp.rawValue < completed.startDay + (completed.periodLength ?? 0) - 1 {
                return false
            }
            return true
        }
    }

    // MARK: - Body

    var body: some View {
        // All cycle lookups for this day resolved once per render
        let context = cycles.dayContext(for: dayStamp.rawValue)
        let buttonState = periodButtonState(context: context)

        VStack(alignment: .leading, spacing: 0) {
            header(subtitle: cycleSubtitleText(context: context))
            if isPeriodActionValid(context: context, buttonState: buttonState) {
                periodButtonRow(buttonState: buttonState)
                    .padding(.top, 12)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if case .period = displayState?.cyclePhase {
                        periodSection(currentLevel: context.owning?.flowLevel(on: dayStamp))
                            .padding(.top, 16)
                    }
                    notesSection
                        .padding(.top, 16)
                }
            }
            .frame(maxHeight: 320)
            .padding(.top, 4)
        }
        .padding()
        .padding(.bottom, globalBottomOffset - dragOffset)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .adaptiveBackground(colorScheme: colorScheme)
                .adaptiveShadow(colorScheme: colorScheme)
        )
        .padding([.horizontal, .top])
        .offset(y: globalBottomOffset)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .global)) { newFrame in
                        Task { @MainActor in
                            if isCurrentlySelected {
                                updateViewFrame(newFrame)
                            }
                        }
                    }
            }
        )
        .background(
           WindowGestureHandler(
               gestureFrame: viewFrame,
               onGestureChange: { translation, velocity, state in
                   handlePanGesture(translation: translation, velocity: velocity, state: state)
               }
           )
        )
        .sheet(isPresented: $showTagsSheet) {
            TagsSheetView(dayStamp: dayStamp, isPresented: $showTagsSheet)
                .environmentObject(store)
                .tint(.accent)
        }
        .sheet(isPresented: $showCommentSheet) {
            CommentSheetView(dayStamp: dayStamp, isPresented: $showCommentSheet)
                .environmentObject(store)
                .tint(.accent)
        }
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
            }
        }
    }

    // MARK: - Period button

    private func periodButtonRow(buttonState: PeriodButtonState) -> some View {
        let isStart = buttonState == .startOutline || buttonState == .startFilled
        let isFilled = buttonState == .startFilled || buttonState == .endFilled
        let title = isStart ? "Начало месячных" : "Конец месячных"

        return Button(action: handlePeriodButton) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isFilled ? .white : .red)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isFilled ? Color.red : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: 1.5)
                )
        }
    }

    private func handlePeriodButton() {
        switch periodButtonState(context: cycles.dayContext(for: dayStamp.rawValue)) {
        case .startOutline, .startFilled:
            store.send(.markPeriodStart(dayStamp))
        case .endOutline:
            store.send(.markPeriodEnd(dayStamp))
        case .endFilled:
            store.send(.unmarkPeriodEnd(dayStamp))
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
        }
    }

    private func flowLevelRow(currentLevel: Int?) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showFlowPicker.toggle()
                }
            }) {
                HStack {
                    Text("Обильность")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(flowLevelLabel(for: currentLevel))
                        .foregroundColor(.red)
                }
                .padding(.vertical, 12)
            }

            if showFlowPicker {
                VStack(spacing: 0) {
                    ForEach(flowLevelOptions, id: \.1) { level, label in
                        Button(action: {
                            store.send(.setFlowLevel(dayStamp, level))
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showFlowPicker = false
                            }
                        }) {
                            HStack {
                                Text(label)
                                    .foregroundColor(.primary)
                                Spacer()
                                if currentLevel == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.red)
                                } else {
                                    Circle()
                                        .stroke(Color.secondary, lineWidth: 1.5)
                                        .frame(width: 22, height: 22)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.leading, 16)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Заметки")

            Button(action: { showTagsSheet = true }) {
                tagsRowContent
            }

            Divider()

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
                FlowLayout(data: resolvedTags, id: \.id, spacing: 6, rowSpacing: 6) { tag in
                    Text(tag.name ?? "")
                        .font(.caption)
                        .foregroundColor(Color.tagColor(for: tag.category))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.tagColor(for: tag.category), lineWidth: 1)
                        )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    // MARK: - Gesture & frame

    private func updateViewFrame(_ globalFrame: CGRect) {
        let fixedFrame = CGRect(
            x: globalFrame.minX,
            y: globalFrame.minY + globalBottomOffset,
            width: globalFrame.width,
            height: globalFrame.height - globalBottomOffset
        )

        viewFrame = fixedFrame
        height = fixedFrame.height
    }

    private func handlePanGesture(translation: CGFloat, velocity: CGFloat, state: PanGestureState) {
        switch state {
        case .began:
            break
        case .changed:
            handleDragChanged(translation: translation)
        case .ended:
            handleDragEnded(velocity: velocity)
        case .cancelled, .failed:
            withAnimation(.bouncy) {
                dragOffset = 0
            }
        }
    }

    private func handleDragChanged(translation: CGFloat) {
        if translation < 0 {
            let absTranslation = abs(translation)
            let initialVisualThreshold = maxUpwardOffset / 3
            let initialTranslationThreshold = initialVisualThreshold / rubberBandFactor

            if absTranslation <= initialTranslationThreshold {
                dragOffset = translation * rubberBandFactor
            } else {
                let baseOffset = initialVisualThreshold
                let excessTranslation = absTranslation - initialTranslationThreshold

                let remainingDistance = maxUpwardOffset - initialVisualThreshold
                let resistanceFactor = 1.0 / (1.0 + excessTranslation / (remainingDistance * 2.0))
                let excessOffset = excessTranslation * rubberBandFactor * resistanceFactor

                let totalOffset = baseOffset + excessOffset
                dragOffset = -min(totalOffset, maxUpwardOffset)
            }
        } else {
            dragOffset = translation
        }
    }

    private func handleDragEnded(velocity: CGFloat) {
        guard viewFrame.height > 0 else {
            withAnimation(.bouncy) { dragOffset = 0 }
            return
        }

        if (viewFrame.height < bottomThreshold) && velocity >= -150  || velocity > velocityThreshold {
            dismissView()
        } else {
            withAnimation(.bouncy) {
                dragOffset = 0
            }
        }
    }

    private func dismissView() {
        store.send(.setSelectedDayStamp(nil))
    }
}

enum PanGestureState {
    case began, changed, ended, cancelled, failed
}

struct WindowGestureHandler: UIViewRepresentable {
    let gestureFrame: CGRect
    let onGestureChange: (CGFloat, CGFloat, PanGestureState) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        setupGestureIfPossible(view: view, context: context)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onGestureChange = onGestureChange
        context.coordinator.gestureFrame = gestureFrame

        if context.coordinator.gesture == nil {
            setupGestureIfPossible(view: uiView, context: context)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.cleanUp()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(gestureFrame: gestureFrame)
    }

    private func findWindow(from view: UIView) -> UIWindow? {
        return view.window ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: { $0.isKeyWindow })
    }

    private func setupGestureIfPossible(view: UIView, context: Context) {
        guard let targetWindow = findWindow(from: view) else { return }

        if let existingGesture = context.coordinator.gesture {
            existingGesture.view?.removeGestureRecognizer(existingGesture)
        }

        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.maximumNumberOfTouches = 2
        panGesture.minimumNumberOfTouches = 1
        panGesture.delegate = context.coordinator
        panGesture.cancelsTouchesInView = false
        panGesture.delaysTouchesBegan = false
        panGesture.delaysTouchesEnded = false
        panGesture.name = "DayDetailsSwipeToDismiss"

        targetWindow.addGestureRecognizer(panGesture)
        context.coordinator.gesture = panGesture
        context.coordinator.onGestureChange = onGestureChange
        context.coordinator.gestureFrame = gestureFrame
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onGestureChange: ((CGFloat, CGFloat, PanGestureState) -> Void)?
        var gestureFrame: CGRect
        weak var gesture: UIPanGestureRecognizer?

        private enum GestureDirection {
            case undecided, vertical, horizontal
        }

        private var gestureDirection: GestureDirection = .undecided
        private let gestureDetectionThreshold: CGFloat = 5

        init(gestureFrame: CGRect) {
            self.gestureFrame = gestureFrame
        }

        func cleanUp() {
            if let gesture = gesture, let view = gesture.view {
                view.removeGestureRecognizer(gesture)
            }
            gesture = nil
            onGestureChange = nil
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            let translation = gesture.translation(in: gesture.view).y
            let velocity = gesture.velocity(in: gesture.view).y

            switch gesture.state {
            case .began:
                gestureDirection = .undecided
                onGestureChange?(0, 0, .began)

            case .changed:
                if gestureDirection == .undecided {
                    let translation2D = gesture.translation(in: gesture.view)
                    if abs(translation2D.x) > gestureDetectionThreshold || abs(translation2D.y) > gestureDetectionThreshold {
                        gestureDirection = abs(translation2D.y) >= abs(translation2D.x) ? .vertical : .horizontal
                    }
                }

                if gestureDirection != .horizontal {
                    onGestureChange?(translation, velocity, .changed)
                }

            case .ended:
                if gestureDirection != .horizontal {
                    onGestureChange?(translation, velocity, .ended)
                }
                gestureDirection = .undecided

            case .cancelled, .failed:
                onGestureChange?(translation, velocity, .cancelled)
                gestureDirection = .undecided

            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()

        DayDetailsView(
            dayStamp: 2000,
            dragOffset: .constant(0),
            height: .constant(0)
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
