//
//  LoginView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    
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
                } else {
                    // Fallback content
                    VStack {
                        Text("Состояние авторизации не определено")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button("Закрыть") {
                            store.send(.setAuthState(.notAuthenticated))
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") {
                        store.send(.setAuthState(.notAuthenticated))
                    }
                }
            }
        }
    }
    
    // MARK: - Email Auth Views
    @ViewBuilder
    private func emailAuthView(for state: EmailAuthState) -> some View {
        switch state {
        case .entry:
            EmailEntryView()
        case .checking:
            EmailCheckingView()
        case .passwordEntry:
            PasswordEntryView()
        case .passwordVerifying:
            PasswordVerifyingView()
        case .registration:
            RegistrationView()
        case .passwordRecovery:
            PasswordRecoveryView()
        }
    }
    
    // MARK: - Phone Auth Views (placeholder)
    @ViewBuilder
    private func phoneAuthView(for state: PhoneAuthState) -> some View {
        VStack {
            Text("Phone Auth")
                .font(.title2)
                .foregroundColor(.white)
            
            Text("State: \(String(describing: state))")
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.purple)
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
