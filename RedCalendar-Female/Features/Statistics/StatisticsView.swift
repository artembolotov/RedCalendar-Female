//
//  StatisticsView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 08.07.2025.
//

import SwiftUI

struct StatisticsView: View {
    @EnvironmentObject var store: AppStore
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Здесь будет статистика и аналитика")
                    .foregroundColor(.secondary)
            }
            .padding()
            .navigationTitle("Статистика")
            .navigationBarTitleDisplayMode(.inline)
            .closeButtonToolbar()
        }
    }
}

#Preview {
    StatisticsView()
        .environmentObject(
            AppStore(
                initialState: AppState(
                    authState: .authenticated(deviceId: "test-device-id")
                ),
                reducer: appReducer,
                middlewares: []
            )
        )
}
