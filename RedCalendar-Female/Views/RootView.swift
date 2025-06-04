//
//  ContentView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        switch store.state.authCheckState {
        case .checking:
            ProgressView("Проверка авторизации...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
        case .authenticated:
            HomeView()
        case .notAuthenticated:
            LoginView()
        }
    }
}

// MARK: - Home View (Authorized)
struct HomeView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Добро пожаловать!")
                    .font(.largeTitle)
                
                if let userId = store.state.userId {
                    Text("User ID: \(userId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button("Выйти") {
                    store.send(.logout)
                }
                .foregroundColor(.red)
            }
            .navigationTitle("RedCalendar")
        }
    }
}

// MARK: - Login View (Not Authorized)
struct LoginView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Войдите в аккаунт")
                    .font(.largeTitle)
                
                Button("Войти (тест)") {
                    store.send(.login)
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Авторизация")
        }
    }
}

#Preview {
    RootView()
        .environmentObject(
            AppStore(
                initialState: AppState(),
                reducer: appReducer,
                middleware: authMiddleware
            )
        )
}
