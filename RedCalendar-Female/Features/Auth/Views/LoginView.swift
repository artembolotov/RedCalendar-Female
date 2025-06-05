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
                initialState: AppState(
                    isInitialized: true,
                    userId: nil
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
