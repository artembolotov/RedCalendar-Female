//
//  HomeView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    
    // НОВОЕ: Состояние для отслеживания кнопки
    @State private var floatingButtonState: FloatingButtonState = .plus
    @State private var isInitialLoad = true // Флаг первичной загрузки
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomLeading) {
                if store.state.isAuthenticated {
                    // Calendar takes full screen
                    CalendarView()
                        .ignoresSafeArea(edges: .bottom)
                        // НОВОЕ: Отслеживаем изменения состояния кнопки из календаря
                        .onPreferenceChange(TodayVisibilityPreferenceKey.self) { newState in
                            if isInitialLoad {
                                // При первой загрузке обновляем без анимации
                                floatingButtonState = newState
                                isInitialLoad = false
                            } else {
                                // При обычных изменениях обновляем с анимацией
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    floatingButtonState = newState
                                }
                            }
                        }
                    
                    // НОВОЕ: Динамическая кнопка с состоянием
                    FloatingAddButton(state: floatingButtonState)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationBarTitleDisplayMode(.inline) // Compact mode
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HomeMenuView()
                }
            }
        }
    }
}

// MARK: - FloatingAddButton Component (ОБНОВЛЕНА)
private struct FloatingAddButton: View {
    let state: FloatingButtonState
    
    var body: some View {
        HStack {
            VStack {
                Spacer()
                
                Button(action: {
                    handleButtonAction()
                }) {
                    Image(systemName: iconName)
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor.opacity(0.8),
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.9)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.bottom, 20) // Safe distance from bottom edge
                // Убираем .animation() отсюда, так как управляем анимацией в HomeView
            }
            .padding(.leading, 20) // Safe distance from left edge
            
            Spacer()
        }
    }
    
    // НОВОЕ: Динамическая иконка
    private var iconName: String {
        switch state {
        case .plus:
            return "plus"
        case .arrowUp:
            return "arrow.up"
        case .arrowDown:
            return "arrow.down"
        }
    }
    
    // НОВОЕ: Обработка действий
    private func handleButtonAction() {
        switch state {
        case .plus:
            // Action for adding new event/record
            print("Add button tapped")
            
        case .arrowUp, .arrowDown:
            // Action for scrolling to today
            scrollToToday()
        }
    }
    
    // НОВОЕ: Функция скролла к сегодняшнему дню (заглушка)
    private func scrollToToday() {
        print("Scroll to today requested - direction: \(state)")
        // TODO: Implement scroll to today functionality
        // Можно реализовать через NotificationCenter или другой механизм
    }
}

// MARK: - HomeMenuView Component (БЕЗ ИЗМЕНЕНИЙ)
private struct HomeMenuView: View {
    @State private var showSettings = false
    @State private var showStatistics = false
    
    var body: some View {
        Menu {
            Button(action: {
                showSettings = true
            }) {
                Label("Настройки", systemImage: "gear")
            }
            
            Button(action: {
                showStatistics = true
            }) {
                Label("Статистика", systemImage: "chart.bar")
            }
            
            if #available(iOS 16.0, *) {
                Divider()
                
                let link = URL(string: Constants.URLs.appLink)!
                ShareLink(item: link) {
                    Label("Поделиться приложением", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Image(systemName: "ellipsis.rectangle.fill")
                .font(.title2)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showStatistics) {
            StatisticsView()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticated(
                        deviceId: "B7DDU4pUigTiAhpNDWnQW83tGQ6R",
                        userDetails: nil
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
