//
//  RegistrationView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct RegistrationView: View {
    @EnvironmentObject var store: AppStore
    
    let email: String
    let step: RegistrationStep
    
    init(email: String, step: RegistrationStep) {
        self.email = email
        self.step = step
    }
    
    var body: some View {
        Group {
            switch step {
            case .userDataEntry:
                UserDataEntryView(email: email)
            case .creating(_, _):
                WaitingView("Создаём аккаунт")
                
            case .emailVerification:
                // Keep existing temporary implementation
                VStack(spacing: 20) {
                    Text("Email Verification")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Подтверждение email")
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.purple)
                
            case .verifyingEmail:
                // Keep existing temporary implementation
                VStack(spacing: 20) {
                    Text("Verifying Email")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Проверяем код email")
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.purple)
            }
        }
        .navigationTitle("Регистрация")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    RegistrationView(email: "test@example.com", step: .userDataEntry)
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
