//
//  PasswordRecoveryView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct PasswordRecoveryView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Password Recovery")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Восстановление пароля")
                .foregroundColor(.white.opacity(0.8))
            
            // Temporary test buttons for recovery steps
            VStack(spacing: 10) {
                Button("→ Code Verification") {
                    store.send(.setAuthState(.authenticating(.email(.passwordRecovery(
                        email: "test@example.com",
                        step: .codeVerification(error: nil)
                    )))))
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.indigo)
                
                Button("→ Password Reset") {
                    store.send(.setAuthState(.authenticating(.email(.passwordRecovery(
                        email: "test@example.com",
                        step: .passwordReset
                    )))))
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.indigo)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.indigo)
        .navigationTitle("Восстановление")
    }
}

#Preview {
    PasswordRecoveryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.passwordRecovery(
                        email: "test@example.com",
                        step: .codeRequesting
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
