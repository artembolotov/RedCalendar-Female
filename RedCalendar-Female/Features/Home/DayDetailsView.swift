import SwiftUI

struct DayDetailsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var colorScheme
    
    let dayStamp: Daystamp
    
    @Binding var dragOffset: CGFloat
    @Binding var height: CGFloat
    
    @State private var viewFrame: CGRect = .zero
    
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

    private var displayState: DayDisplayState? {
        store.state.calendarState.dayDisplayStates[dayStamp]
    }

    private var comment: String? {
        store.state.calendarState.visibleComments[dayStamp]?.comment
    }

    private var resolvedTags: [UserTagRecord] {
        let tagIds = store.state.calendarState.visibleDayTags[dayStamp] ?? []
        let userTags = store.state.calendarState.userTags
        return tagIds.compactMap { id in
            userTags.first(where: { $0.id == id && $0.name != nil })
        }
    }

    private var flowLevel: Int? {
        let cycles = store.state.calendarState.cycles
        guard let cycle = cycles.filter({ $0.startDay <= dayStamp.rawValue })
                                .max(by: { $0.startDay < $1.startDay }) else { return nil }
        return cycle.flowLevels[String(dayStamp.rawValue)]
    }

    private var isPeriodDay: Bool {
        if case .period = displayState?.cyclePhase { return true }
        return false
    }

    private var hasAnyContent: Bool {
        if let displayState {
            if case .period = displayState.cyclePhase { return true }
            if displayState.fertilePhase != nil { return true }
        }
        if !resolvedTags.isEmpty { return true }
        if comment != nil { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text(titleText)
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button(action: {
                    dismissView()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            ScrollView {
                detailsContent
            }
            .frame(height: 250)
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
    }
    
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

    // MARK: - Details Content

    @ViewBuilder
    private var detailsContent: some View {
        if hasAnyContent {
            VStack(alignment: .leading, spacing: 16) {
                cyclePhaseRow
                flowLevelRow
                tagsRow
                commentRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        } else {
            Text("Нет записей")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)
        }
    }

    @ViewBuilder
    private var cyclePhaseRow: some View {
        if let displayState {
            if case let .period(_, isPredicted) = displayState.cyclePhase {
                HStack(spacing: 12) {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.red)
                        .frame(width: 20)
                    Text(isPredicted ? "Менструация (прогноз)" : "Менструация")
                        .font(.body)
                }
            } else if case let .ovulation(confirmed) = displayState.fertilePhase {
                HStack(spacing: 12) {
                    Image(systemName: "circle.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.65, blue: 0.0))
                        .frame(width: 20)
                    Text(confirmed ? "Овуляция (подтверждена)" : "Овуляция (прогноз)")
                        .font(.body)
                }
            } else if case .fertile = displayState.fertilePhase {
                HStack(spacing: 12) {
                    Image(systemName: "leaf.fill")
                        .foregroundColor(Color(red: 0.55, green: 0.40, blue: 0.85))
                        .frame(width: 20)
                    Text("Фертильное окно")
                        .font(.body)
                }
            }
        }
    }

    @ViewBuilder
    private var flowLevelRow: some View {
        if isPeriodDay, let level = flowLevel {
            HStack(spacing: 12) {
                Image(systemName: "drop.halffull")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text(flowLevelText(level))
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func flowLevelText(_ level: Int) -> String {
        switch level {
        case 1: return "Светлые выделения"
        case 2: return "Умеренные выделения"
        case 3: return "Обильные выделения"
        default: return ""
        }
    }

    @ViewBuilder
    private var tagsRow: some View {
        if !resolvedTags.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(resolvedTags, id: \.id) { tag in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(tagColor(for: tag.category))
                            .frame(width: 10, height: 10)
                        Text(tag.name ?? "")
                            .font(.body)
                    }
                }
            }
        }
    }

    private func tagColor(for category: Int?) -> Color {
        switch category {
        case 0: return .blue
        case 1: return .green
        case 2: return Color(red: 0.20, green: 0.73, blue: 0.68)
        case 3: return .purple
        default: return .gray
        }
    }

    @ViewBuilder
    private var commentRow: some View {
        if let comment {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "text.bubble")
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text(comment)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
