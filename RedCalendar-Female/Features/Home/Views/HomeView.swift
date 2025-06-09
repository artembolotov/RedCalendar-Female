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
                
                if case .authenticated(let deviceId, _) = store.state.authState {
                    Text("Device ID: \(deviceId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                
                Button("Выйти") {
                    store.send(.logout)
                }
                .foregroundColor(.red)
            }
            .padding()
            .navigationTitle("RedCalendar")
        }
    }
}

#Preview {
    RootView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    apnsToken: nil,
                    authState: .authenticated(
                        deviceId: "B7DDU4pUigTiAhpNDWnQW83tGQ6R",
                        userDetails: nil
                    )
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
