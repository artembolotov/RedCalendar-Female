//
//  HomeView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Добро пожаловать!")
                    .font(.largeTitle)
                
                if let userId = store.state.userId {
                    Text("User ID: \(userId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button("Выйти") {
                    store.send(.logout)
                }
                .foregroundColor(.red)
            }
            .navigationTitle("RedCalendar")
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(
            AppStore(
                initialState: AppState(isInitialized: true, userId: "nSJXOCPF3ocA4Znn1sL7KvI1dh13"),
                reducer: appReducer,
                middlewares: createAppMiddleware()
            )
        )
}
