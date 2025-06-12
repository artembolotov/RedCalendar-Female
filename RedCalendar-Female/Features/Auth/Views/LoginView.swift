//
//  LoginView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Здесь будет реализован весь поток авторизации")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
                
                // Temporary migration test button
                Button("Тест миграции") {
                    store.send(.setAuthState(.migrating(
                        userId: "nSJXOCPF3ocA4Znn1sL7KvI1dh13"
                    )))
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
            .navigationTitle("Вход")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        dismissLogin()
                    }
                }
            }
        }
    }
    
    // Helper method to dismiss login screen
    private func dismissLogin() {
        store.send(.setAuthState(.notAuthenticated))
    }
}

#Preview {
    LoginView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.entry))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
