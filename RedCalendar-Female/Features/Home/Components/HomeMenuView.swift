//
//  HomeMenuView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 29.07.2025.
//

import SwiftUI

// MARK: - HomeMenuView Component
struct HomeMenuView: View {
    @State private var showSettings = false
    @State private var showStatistics = false
    
    var body: some View {
        Menu("HomeMenuView.Menu", systemImage: "ellipsis") {
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
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .tint(.accent)
        }
        .sheet(isPresented: $showStatistics) {
            StatisticsView()
                .tint(.accent)
        }
    }
}
