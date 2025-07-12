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
            VStack {
                if store.state.isAuthenticated {
                    CalendarView()
                }
            }
            .navigationBarTitleDisplayMode(.inline) // Compact mode
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HomeMenuView()
                }
            }
        }
    }
}

// MARK: - HomeMenuView Component
private struct HomeMenuView: View {
    @State private var showSettings = false
    @State private var showStatistics = false
    
    var body: some View {
        Menu {
            Button(action: {
                showSettings = true
            }) {
                Label("Настройки", systemImage: "gear")
            }
            
            Button(action: {
                showStatistics = true
            }) {
                Label("Статистика", systemImage: "chart.bar")
            }
            
            if #available(iOS 16.0, *) {
                Divider()
                
                let link = URL(string: Constants.URLs.appLink)!
                
                ShareLink(item: link) {
                    Label("Поделиться приложением", systemImage: "square.and.arrow.up")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title2)
                .foregroundColor(.primary)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showStatistics) {
            StatisticsView()
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
