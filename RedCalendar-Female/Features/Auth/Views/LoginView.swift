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
                } else {
                    // Fallback content
                    VStack {
                        Text("Состояние авторизации не определено")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
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
        
        case .entry(_, _):
            EmailEntryView()
        case .checking(_, _):
            WaitingView("Проверяем email")
        case .codeEntry(_, _, _), .registration(_, _, _, _):
            UnifiedCodeEntryView()
        case .verifying(_, _):
            WaitingView("Проверяем код")
        case .registering(_, _, _):
            WaitingView("Создаём аккаунт")
        }
    }
    
    // MARK: - Phone Auth Views
    @ViewBuilder
    private func phoneAuthView(for state: PhoneAuthState) -> some View {
        switch state {
        case .entry:
            PhoneEntryView()
        case .requesting(let phoneNumber):
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                
                Text("Отправляем флеш-звонок...")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("На номер: \(phoneNumber)")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)
            .navigationTitle("Запрос звонка")
            
        case .verification(let phoneNumber, let maskedCallerNumber, let error):
            VStack(spacing: 20) {
                Text("Дождитесь звонка")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(spacing: 8) {
                    Text("Мы звоним на номер:")
                        .foregroundColor(.secondary)
                    Text(phoneNumber)
                        .font(.headline)
                    
                    Text("Номер звонящего:")
                        .foregroundColor(.secondary)
                        .padding(.top)
                    Text(maskedCallerNumber)
                        .font(.headline)
                }
                
                if let error = error {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                
                Text("Введите последние 4 цифры номера звонящего")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // TODO: Add code input field
            }
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)
            .navigationTitle("Проверка")
            
        case .verifying(let phoneNumber, let verificationCode):
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
                
                Text("Проверяем код...")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Номер: \(phoneNumber)")
                    .foregroundColor(.secondary)
                Text("Код: \(verificationCode)")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 320)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal)
            .navigationTitle("Проверка")
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.entry()))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
