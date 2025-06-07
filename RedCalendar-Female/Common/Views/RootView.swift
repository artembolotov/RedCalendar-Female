//
//  RootView.swift
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
                
        case .migrating:
            VStack(spacing: 16) {
                if store.state.migrationError == nil {
                    // Normal migration in progress
                    ProgressView("Обновление системы авторизации...")
                    
                    Text("Переходим на новую систему безопасности")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    // Migration failed - show error and retry button
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                        .padding(.bottom, 8)
                    
                    Text("Ошибка миграции")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let error = store.state.migrationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button("Повторить") {
                        store.send(.startMigration)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 16)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            
        case .authenticated:
            HomeView()
            
        case .notAuthenticated:
            LoginView()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(
            AppStore(
                initialState: AppState(),
                reducer: appReducer,
                middlewares: combineAppMiddlewares()
            )
        )
}

#Preview("Migration Error") {
    RootView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    isInitialized: true,
                    isMigrating: true,
                    migrationError: "Сервер недоступен. Проверьте подключение к интернету."
                ),
                reducer: appReducer,
                middlewares: combineAppMiddlewares()
            )
        )
}
