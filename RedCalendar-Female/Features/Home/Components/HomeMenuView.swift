//
//  HomeMenuView.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 29.07.2025.
//

import SwiftUI

// MARK: - HomeMenuView Component
struct HomeMenuView: View {
    // Passed in rather than pulled from the environment: this view is toolbar content, and an
    // `@EnvironmentObject` there is not reliably reachable — a miss would be a crash, not a
    // wrong colour.
    let accent: Color

    @State private var showSettings = false
    @State private var showStatistics = false

    // What iOS 26 gives a toolbar button on its own. Matched by eye rather than derived —
    // there is no public metric for it, and it only has to read as the same control.
    private let fallbackDiameter: CGFloat = 36

    // MARK: - Body

    var body: some View {
        button
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .tint(accent)
            }
            .sheet(isPresented: $showStatistics) {
                StatisticsView()
                    .tint(accent)
            }
    }

    // MARK: - Private Views

    // The calendar runs under the navigation bar now, so the glyph no longer sits on a plate —
    // it sits on whatever day happens to be passing beneath it. From iOS 26 the system draws
    // the button its own glass backing and nothing is needed here; below it the backing is
    // drawn by hand, same as `CloseButton` fills in the close role it does not have.
    @ViewBuilder
    private var button: some View {
        if #available(iOS 26.0, *) {
            menu
        } else {
            menu
                .frame(width: fallbackDiameter, height: fallbackDiameter)
                .background(Circle().fill(.ultraThinMaterial))
        }
    }

    private var menu: some View {
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
    }
}
