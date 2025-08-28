//
//  DayDetailsView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.08.2025.
//

import SwiftUI

struct DayDetailsView: View {
    @EnvironmentObject var store: AppStore
    
    // MARK: - Swipe to dismiss state
    @State private var dragOffset: CGFloat = 0
    @State private var viewHeight: CGFloat = 0
    @State private var gestureHandler: WindowGestureHandler.Coordinator?
    
    // MARK: - Constants
    private let velocityThreshold: CGFloat = 1200
    private let rubberBandFactor: CGFloat = 0.3
    
    private var dayStamp: Daystamp? {
        if case .authenticated(_, _, let calendarState) = store.state.authState {
            return calendarState.selectedDayStamp
        }
        return nil
    }
    
    private var formattedDate: String {
        guard let dayStamp = dayStamp else { return "" }
        let date = dayStamp.toDate(calendar: Calendar.current)
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    var body: some View {
        if let dayStamp = dayStamp {
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
                    Text(formattedDate)
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
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
            )
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { viewHeight = geometry.size.height }
                        .onChange(of: geometry.size.height) { newHeight in
                            viewHeight = newHeight
                        }
                }
            )
            .offset(y: dragOffset)
            .background(
                WindowGestureHandler(
                    onGestureChange: { translation, velocity, state in
                        handlePanGesture(translation: translation, velocity: velocity, state: state)
                    },
                    coordinatorBinding: $gestureHandler
                )
            )
            .onDisappear {
                // Clean up gesture when view disappears
                gestureHandler?.cleanUp()
                gestureHandler = nil
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
        if translation < 0 {
            // Drag up - apply rubber band effect
            dragOffset = translation * rubberBandFactor
        } else {
            // Drag down - normal behavior
            dragOffset = translation
        }
    }
    
    private func handleDragEnded(translation: CGFloat, velocity: CGFloat) {
        guard viewHeight > 0 else {
            withAnimation(.bouncy) { dragOffset = 0 }
            return
        }
        
        let dismissThreshold = viewHeight / 3
        let shouldDismiss = dragOffset > dismissThreshold || velocity > velocityThreshold
        
        if shouldDismiss {
            // Reset offset and let SwiftUI transition handle the animation
            dragOffset = 0
            dismissView()
        } else {
            // Return to original position
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
    @Binding var coordinatorBinding: Coordinator?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false // Don't block touches
        
        // Delay all setup to avoid modifying state during view update
        DispatchQueue.main.async {
            // Store coordinator in binding
            self.coordinatorBinding = context.coordinator
            
            guard let window = view.window else { return }
            
            // Remove any existing gestures with our identifier
            window.gestureRecognizers?.forEach { gesture in
                if let panGesture = gesture as? UIPanGestureRecognizer,
                   panGesture.name == "DayDetailsSwipeToDismiss" {
                    window.removeGestureRecognizer(panGesture)
                }
            }
            
            // Add new gesture
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
            
            window.addGestureRecognizer(panGesture)
            context.coordinator.gesture = panGesture
            context.coordinator.onGestureChange = self.onGestureChange
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update callback if needed
        context.coordinator.onGestureChange = onGestureChange
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.cleanUp()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onGestureChange: ((CGFloat, CGFloat, PanGestureState) -> Void)?
        weak var gesture: UIPanGestureRecognizer?
        private var isVerticalGesture = false
        private var hasDecidedDirection = false
        
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
                hasDecidedDirection = false
                isVerticalGesture = false
                onGestureChange?(0, 0, .began)
                
            case .changed:
                if !hasDecidedDirection {
                    let translation2D = gesture.translation(in: gesture.view)
                    if abs(translation2D.x) > 5 || abs(translation2D.y) > 5 {
                        hasDecidedDirection = true
                        isVerticalGesture = abs(translation2D.y) >= abs(translation2D.x)
                    }
                }
                
                if isVerticalGesture || !hasDecidedDirection {
                    onGestureChange?(translation, velocity, .changed)
                }
                
            case .ended:
                if isVerticalGesture || !hasDecidedDirection {
                    onGestureChange?(translation, velocity, .ended)
                }
                hasDecidedDirection = false
                isVerticalGesture = false
                
            case .cancelled, .failed:
                onGestureChange?(translation, velocity, .cancelled)
                hasDecidedDirection = false
                isVerticalGesture = false
                
            default:
                break
            }
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            
            // Get the location and check if it's in the bottom portion of screen
            let location = panGesture.location(in: panGesture.view)
            let screenHeight = UIScreen.main.bounds.height
            
            // Only handle gestures in bottom 40% of screen (where DayDetailsView is)
            guard location.y > screenHeight * 0.6 else {
                return false
            }
            
            let translation = panGesture.translation(in: panGesture.view)
            
            // Check if movement is vertical
            if abs(translation.y) > 3 || abs(translation.x) > 3 {
                return abs(translation.y) >= abs(translation.x)
            }
            
            return true
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
