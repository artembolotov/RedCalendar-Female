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
            ZStack(alignment: .bottomLeading) {
                if store.state.isAuthenticated {
                    // Calendar takes full screen
                    CalendarView()
                        .ignoresSafeArea(edges: .bottom)
                    
                    // Floating Add Button
                    FloatingAddButton()
                        .ignoresSafeArea(edges: .bottom)
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

// MARK: - FloatingAddButton Component
private struct FloatingAddButton: View {
    var body: some View {
        HStack {
            VStack {
                Spacer()
                
                Button(action: {
                    // Action for adding new event/record
                    print("Add button tapped")
                }) {
                    Image(systemName: "plus")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.accentColor.opacity(0.8),
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.9)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
                }
                .padding(.bottom, 20) // Safe distance from bottom edge
            }
            .padding(.leading, 20) // Safe distance from left edge
            
            Spacer()
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
            Image(systemName: "ellipsis.rectangle.fill")
                .font(.title2)
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
