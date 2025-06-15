//
//  EmailCheckingView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct EmailCheckingView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
            
            Text("Email Checking")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Проверяем email адрес...")
                .foregroundColor(.white.opacity(0.8))
            
            // Temporary test buttons
            VStack(spacing: 10) {
                Button("→ Password Entry") {
                    store.send(.setAuthState(.authenticating(.email(.passwordEntry(
                        email: "test@example.com",
                        userName: "Test User",
                        error: nil
                    )))))
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.orange)
                
                Button("→ Registration") {
                    store.send(.setAuthState(.authenticating(.email(.registration(
                        email: "test@example.com",
                        step: .userDataEntry
                    )))))
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.orange)
        .navigationTitle("Проверка")
    }
}

#Preview {
    EmailCheckingView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticating(.email(.checking(email: "test@example.com")))
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
