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
            .overlay(  
                PanGestureOverlay { translation, velocity, state in
                    handlePanGesture(translation: translation, velocity: velocity, state: state)
                } heightCallback: { height in
                    viewHeight = height
                }
            )
            .offset(y: dragOffset)
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

struct PanGestureOverlay: UIViewRepresentable {
    let onGestureChange: (CGFloat, CGFloat, PanGestureState) -> Void
    let heightCallback: (CGFloat) -> Void
    
    init(onGestureChange: @escaping (CGFloat, CGFloat, PanGestureState) -> Void, heightCallback: @escaping (CGFloat) -> Void) {
        self.onGestureChange = onGestureChange
        self.heightCallback = heightCallback
    }
    
    func makeUIView(context: Context) -> GestureView {
        let view = GestureView()
        view.backgroundColor = .clear
        
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan(_:))
        )
        panGesture.maximumNumberOfTouches = 2
        panGesture.minimumNumberOfTouches = 1
        panGesture.delegate = context.coordinator
        panGesture.cancelsTouchesInView = false
        panGesture.delaysTouchesBegan = false
        
        view.addGestureRecognizer(panGesture)
        view.onGestureChange = onGestureChange
        view.heightCallback = heightCallback
        
        return view
    }
    
    func updateUIView(_ uiView: GestureView, context: Context) {
        uiView.onGestureChange = onGestureChange
        uiView.heightCallback = heightCallback
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class GestureView: UIView {
        var onGestureChange: ((CGFloat, CGFloat, PanGestureState) -> Void)?
        var heightCallback: ((CGFloat) -> Void)?
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            return self
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            DispatchQueue.main.async {
                self.heightCallback?(self.bounds.height)
            }
        }
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? GestureView else { return }
            
            let translation = gesture.translation(in: view).y
            let velocity = gesture.velocity(in: view).y
            
            switch gesture.state {
            case .began:
                view.onGestureChange?(0, 0, .began)
            case .changed:
                view.onGestureChange?(translation, velocity, .changed)
            case .ended:
                view.onGestureChange?(translation, velocity, .ended)
            case .cancelled, .failed:
                view.onGestureChange?(translation, velocity, .cancelled)
            default:
                break
            }
        }
        
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let translation = panGesture.translation(in: panGesture.view)
            
            if abs(translation.y) > 3 || abs(translation.x) > 3 {
                return abs(translation.y) >= abs(translation.x)
            }
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
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
