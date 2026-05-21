//
//  WelcomeView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var store: AppStore
    @State private var currentSlide = 0
    
    // Computed binding for sheet presentation
    private var showLoginSheet: Binding<Bool> {
        Binding(
            get: {
                if case .authenticating = store.state.authState {
                    return true
                } else {
                    return false
                }
            },
            set: { isPresented in
                if !isPresented && shouldSetNotAuthenificated {
                    store.send(.setAuthState(.notAuthenticated))
                }
            }
        )
    }
    
    private var shouldSetNotAuthenificated: Bool {
        guard let authState = store.state.authState else {
            return false
        }
        
        switch authState {
        case .authenticated(_, _, _), .notAuthenticated, .migrating(_, _):
            return false
       
        case .authenticating(_):
            return true
        }
    }
    
    private let slides = [
        SlideData(
            image: "calendar.badge.plus",
            title: "Отслеживайте цикл",
            description: "Ведите календарь менструального цикла с точными прогнозами"
        ),
        SlideData(
            image: "heart.text.square",
            title: "Контролируйте самочувствие",
            description: "Записывайте симптомы, настроение и важные события"
        ),
        SlideData(
            image: "bell.badge",
            title: "Получайте напоминания",
            description: "Умные уведомления о важных днях цикла"
        ),
        SlideData(
            image: "lock.shield",
            title: "Ваши данные в безопасности",
            description: "Полная приватность и защита персональной информации"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Slides
            TabView(selection: $currentSlide) {
                ForEach(slides.indices, id: \.self) { index in
                    SlideView(slide: slides[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Page indicator
            HStack(spacing: 8) {
                ForEach(slides.indices, id: \.self) { index in
                    Circle()
                        .fill(currentSlide == index ? Color.accent : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentSlide)
                }
            }
            .padding(.vertical)
            
            Spacer()
            
            PrimaryButton {
                store.send(.setAuthState(.authenticating(.email(.entry()))))
            } content: {
                Text("Войти")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Image(systemName: "arrow.right")
                    .font(.headline)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color.red.opacity(0.05)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .sheet(isPresented: showLoginSheet) {
            LoginView()
                .environmentObject(store)
        }
    }
}

// MARK: - SlideData Model
private struct SlideData {
    let image: String
    let title: String
    let description: String
}

// MARK: - SlideView Component
private struct SlideView: View {
    let slide: SlideData
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: slide.image)
                .font(.system(size: 80))
                .foregroundColor(.accent)
            
            VStack(spacing: 12) {
                Text(slide.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(slide.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Preview
#Preview {
    WelcomeView()
        .environmentObject(
            AppStore(
                initialState: AppState(authState: .notAuthenticated),
                reducer: appReducer,
                middlewares: []
            )
        )
}

#Preview("Login Sheet") {
    WelcomeView()
        .environmentObject(
            AppStore(
                initialState: AppState(authState: .authenticating(.email(.entry()))),
                reducer: appReducer,
                middlewares: []
            )
        )
}
