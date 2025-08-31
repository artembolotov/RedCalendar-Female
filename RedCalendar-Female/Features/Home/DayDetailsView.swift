//
//  DayDetailsView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.08.2025.
//

import SwiftUI

struct DayDetailsView: View {
    @EnvironmentObject var store: AppStore
    
    static private var cachedDayStamp: Daystamp?
    
    // MARK: - Swipe to dismiss state
    @State private var dragOffset: CGFloat = 0
    @State private var viewHeight: CGFloat = 0
    
    // MARK: - Constants
    private let velocityThreshold: CGFloat = 1200
    private let rubberBandFactor: CGFloat = 0.3
    private let gestureDetectionThreshold: CGFloat = 5
    private let bottomScreenRatio: CGFloat = 0.6
    
    private var currentDayStamp: Daystamp? {
        if case .authenticated(_, _, let calendarState) = store.state.authState {
            if let dayStamp = calendarState.selectedDayStamp {
                Self.cachedDayStamp = dayStamp
                return dayStamp
            }
        }
        return nil
    }
    
    private func formattedDate(date: Date) -> String {
        
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    var body: some View {
        if let dayStamp = currentDayStamp ?? Self.cachedDayStamp {
            VStack(spacing: 20) {
                // Header with close button
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
                .padding(.horizontal)
                
                Divider()
                
                // Day information
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
                .padding(.horizontal)
            }
            .padding([.top, .bottom])
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { viewHeight = geometry.size.height }
                        .onChange(of: geometry.size.height) { newHeight in
                            viewHeight = newHeight
                        }
                }
            )
            .padding(.bottom, -dragOffset)
            .background(
                Rectangle()
                    .fill(Color(.systemBackground))
                    .cornerRadius(16, corners: [.topLeft, .topRight])
                    .shadow(color: .black.opacity(0.1), radius: 10, x: -2, y: -5)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 2, y: -5)
            )
            .background(
                currentDayStamp.map { _ in
                   WindowGestureHandler(
                       onGestureChange: { translation, velocity, state in
                           handlePanGesture(translation: translation, velocity: velocity, state: state)
                       }
                   )
               }
            )
            .onChange(of: viewHeight) { newValue in
                AppLogger.info("viewHeight changed to \(newValue)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handlePanGesture(translation: CGFloat, velocity: CGFloat, state: PanGestureState) {
        switch state {
        case .began:
            break
        case .changed:
            handleDragChanged(translation: translation)
        case .ended:
            handleDragEnded(translation: translation, velocity: velocity)
        case .cancelled, .failed:
            withAnimation(.bouncy) {
                dragOffset = 0
            }
        }
    }
    
    private func handleDragChanged(translation: CGFloat) {
        dragOffset = translation < 0 ? translation * rubberBandFactor : translation
    }
    
    private func handleDragEnded(translation: CGFloat, velocity: CGFloat) {
        guard viewHeight > 0 else {
            withAnimation(.bouncy) { dragOffset = 0 }
            return
        }
        
        let dismissThreshold = viewHeight / 3
        let shouldDismiss = dragOffset > dismissThreshold || velocity > velocityThreshold
        
        if shouldDismiss {
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

// MARK: - Pan Gesture Support

enum PanGestureState {
    case began, changed, ended, cancelled, failed
}

struct WindowGestureHandler: UIViewRepresentable {
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
        
        if context.coordinator.gesture == nil {
            setupGestureIfPossible(view: uiView, context: context)
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.cleanUp()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func findWindow(from view: UIView) -> UIWindow? {
        return view.window ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: { $0.isKeyWindow })
    }
    
    private func setupGestureIfPossible(view: UIView, context: Context) {
        guard let targetWindow = findWindow(from: view) else { return }
        
        targetWindow.gestureRecognizers?.forEach { gesture in
            if let panGesture = gesture as? UIPanGestureRecognizer,
               panGesture.name == "DayDetailsSwipeToDismiss" {
                targetWindow.removeGestureRecognizer(panGesture)
            }
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
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onGestureChange: ((CGFloat, CGFloat, PanGestureState) -> Void)?
        weak var gesture: UIPanGestureRecognizer?
        
        private enum GestureDirection {
            case undecided, vertical, horizontal
        }
        
        private var gestureDirection: GestureDirection = .undecided
        private let gestureDetectionThreshold: CGFloat = 5
        private let bottomScreenRatio: CGFloat = 0.6
        
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
            let screenHeight = UIScreen.main.bounds.height
            
            return location.y > screenHeight * bottomScreenRatio
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Let taps take priority
            if otherGestureRecognizer is UITapGestureRecognizer {
                return true
            }
            return false
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
            .ignoresSafeArea()
        
        DayDetailsView()
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
