//
//  EmailEntryView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 12.06.2025.
//

import SwiftUI

struct EmailEntryView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Email Entry")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            Text("Введите email адрес")
                .foregroundColor(.white.opacity(0.8))
            
            // Temporary test button
            Button("Перейти к Checking") {
                store.send(.setAuthState(.authenticating(.email(.checking(email: "test@example.com")))))
            }
            .buttonStyle(.borderedProminent)
            
            Button("Тест миграции") {
                dismiss()
                
                Task { @MainActor in
                    store.send(.setAuthState(.migrating(
                        userId: "nSJXOCPF3ocA4Znn1sL7KvI1dh13"
                    )))
                }
                
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Вход")
    }
}

#Preview {
    EmailEntryView()
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
