//
//  PasswordEntryView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct PasswordEntryView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Password Entry")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Введите пароль")
                .foregroundColor(.white.opacity(0.8))
            
            // Temporary test buttons
            VStack(spacing: 10) {
                Button("→ Password Verifying") {
                    store.send(.setAuthState(.authenticating(.email(.passwordVerifying(
                        email: "test@example.com",
                        password: "password123"
                    )))))
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.green)
                
                Button("→ Password Recovery") {
                    store.send(.setAuthState(.authenticating(.email(.passwordRecovery(
                        email: "test@example.com",
                        step: .codeRequesting
                    )))))
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.green)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.green)
        .navigationTitle("Пароль")
    }
}

#Preview {
    PasswordEntryView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.passwordEntry(
                        email: "test@example.com",
                        userName: "Test User",
                        error: nil
                    )))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
