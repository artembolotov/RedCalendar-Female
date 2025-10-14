import SwiftUI

struct DayDetailsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) var colorScheme
    
    let dayStamp: Daystamp
    
    @Binding var dragOffset: CGFloat
    @Binding var height: CGFloat
    
    @State private var viewFrame: CGRect = .zero
    
    private let velocityThreshold: CGFloat = 1200
    private let rubberBandFactor: CGFloat = 0.3
    private let bottomThreshold: CGFloat = 250
    private let maxUpwardOffset: CGFloat = 150
    private let globalBottomOffset: CGFloat = 25
    
    private func formattedDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Детали дня")
                    .font(.title2)
                    .fontWeight(.semibold)
                
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
            
            VStack(spacing: 12) {
                Text(formattedDate(date: dayStamp.toDate(calendar: Calendar.current)))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("Daystamp: \(dayStamp.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(dayStamp.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
                            updateViewFrame(newFrame)
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
        .onDisappear {
            height = 0
        }
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
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            
            let location = panGesture.location(in: panGesture.view)
            return gestureFrame.contains(location)
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if let panGesture = gestureRecognizer as? UIPanGestureRecognizer {
                let location = panGesture.location(in: panGesture.view)
                return gestureFrame.contains(location)
            }
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
                authState: .authenticated(
                    deviceId: "test",
                    userDetails: nil,
                    calendarState: CalendarState(selectedDayStamp: Daystamp(rawValue: 100))
                )
            ),
            reducer: appReducer,
            middlewares: []
        )
    )
}
