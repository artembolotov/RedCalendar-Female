//
//  RegistrationView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Registration")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Регистрация нового пользователя")
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            
            // Temporary test buttons for registration steps
            VStack(spacing: 10) {
                Button("→ Creating Account") {
                    store.send(.setAuthState(.authenticating(.email(.registration(
                        email: "test@example.com",
                        step: .creating(name: "Test User", password: "password123")
                    )))))
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.purple)
                
                Button("→ Email Verification") {
                    store.send(.setAuthState(.authenticating(.email(.registration(
                        email: "test@example.com",
                        step: .emailVerification(verificationCode: nil)
                    )))))
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.purple)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.purple)
        .navigationTitle("Регистрация")
    }
}

#Preview {
    RegistrationView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.registration(
                        email: "test@example.com",
                        step: .userDataEntry
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
