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
            Group {
                if let authState = store.state.authState,
                   case .authenticating(let method) = authState {
                    switch method {
                    case .email(let emailState):
                        emailAuthView(for: emailState)
                    case .phone(let phoneState):
                        phoneAuthView(for: phoneState)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        store.send(.auth(.set(.notAuthenticated)))
                    }
                }
            }
        }
    }
    
    // MARK: - Email Auth Views
    @ViewBuilder
    private func emailAuthView(for state: EmailAuthState) -> some View {
        switch state {
        
        case .entry(_, _):
            EmailEntryView()
        case .checking(_, _):
            WaitingView("Отправляем код")
        case .codeEntry(_, _, _, _), .registration(_, _, _, _):
            CodeEntryView()
        case .verifying(_, _, _):
            WaitingView("Проверяем код")
        case .registering(_, _, _):
            WaitingView("Создаём аккаунт")
        }
    }
    
    // MARK: - Phone Auth Views
    @ViewBuilder
    private func phoneAuthView(for state: PhoneAuthState) -> some View {
        switch state {
        case .entry(_, _):
            PhoneEntryView()
        case .requesting(_, _):
            WaitingView("Проверяем номер")
        case .verification(_, _, _, _, _):
            FlashCallCodeEntryView()
        case .verifying(_, _, _, _, _):
            WaitingView("Проверяем код")
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(
            AppStore(
                initialState: AppState(authState: .authenticating(.email(.entry()))),
                reducer: appReducer,
                middlewares: []
            )
        )
}
