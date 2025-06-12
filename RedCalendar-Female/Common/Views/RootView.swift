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
        if let authState = store.state.authState {
            switch authState {
            case .notAuthenticated, .authenticating(_):
                WelcomeView()
            case .authenticated:
                HomeView()
            case .migrating(let userId, let migrationError):
                VStack(spacing: 16) {
                    if let migrationError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                            .padding(.bottom, 8)
                        
                        Text("Ошибка миграции")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(migrationError.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Повторить") {
                            store.send(.setAuthState(.migrating(userId: userId, error: nil)))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.top, 16)
                    } else {
                        ProgressView("Обновление системы авторизации...")
                        
                        Text("Переходим на новую систему безопасности")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        } else {
            ProgressView("Проверка авторизации...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
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
                initialState: AppState(),
                reducer: appReducer,
                middlewares: combineAppMiddlewares()
            )
        )
}
