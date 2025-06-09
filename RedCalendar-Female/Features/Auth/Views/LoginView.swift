//
//  LoginView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Войдите в аккаунт")
                    .font(.largeTitle)
                
                Button("Войти (тест)") {
                    store.send(.setAuthState(.migrating(
                        userId: "nSJXOCPF3ocA4Znn1sL7KvI1dh13"))
                    )
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
                initialState: AppState(
                    apnsToken: nil,
                    authState: .notAuthenticated
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
