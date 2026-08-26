//
//  SyncIndicatorView.swift
//  RedCalendar-Female
//

import SwiftUI

/// The sync indicator of SYNC.md §9 and §12 (item 12) — `.navigationBarLeading`, paired with
/// `HomeMenuView` on the trailing side.
///
/// **Driven by `SyncState`, read once in `HomeView` and passed down.** Same reason
/// `HomeMenuView` takes `accent` the way it does: this is toolbar content, where
/// `@EnvironmentObject` is not reliably reachable — a miss there is a crash, not a wrong glyph.
struct SyncIndicatorView: View {
    let syncState: SyncState
    let accent: Color

    @State private var explanationPresented = false

    // Matches `HomeMenuView.fallbackDiameter` — the trailing side draws the same backing for the
    // same reason: the calendar runs under a transparent navigation bar, so the glyph sits on a
    // passing day rather than on a plate unless something is drawn behind it.
    private let fallbackDiameter: CGFloat = 36

    var body: some View {
        switch syncState {
        case .idle:
            // Nothing at all — not even the backing circle. There is nothing to send and
            // nothing in flight, and an empty leading slot is what keeps the inline, textless
            // title from shifting when this appears and disappears.
            EmptyView()

        case .syncing:
            badge {
                ProgressView()
                    .tint(accent)
            }
            .accessibilityLabel("Синхронизация")

        case .pending:
            badge {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundStyle(accent)
            }
            .accessibilityLabel("Есть несохранённые данные")

        case .failed:
            Button {
                explanationPresented = true
            } label: {
                badge {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .symbolRenderingMode(.multicolor)
                }
            }
            .accessibilityLabel("Не удалось синхронизировать данные")
            .accessibilityHint("Нажмите, чтобы узнать больше")
            .popover(isPresented: $explanationPresented) {
                explanation
            }
        }
    }

    // MARK: - Private Views

    // Same backing `HomeMenuView.button` draws for the same glass-over-calendar problem: from
    // iOS 26 the system draws it, below that a hand-drawn `.ultraThinMaterial` circle stands in.
    @ViewBuilder
    private func badge<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            content()
        } else {
            ZStack {
                Circle().fill(.ultraThinMaterial)
                content()
            }
            .frame(width: fallbackDiameter, height: fallbackDiameter)
        }
    }

    // A popover rather than an alert: a retry is already scheduled on its own (§5.7), so this is
    // something to look at, not something that needs answering.
    private var explanation: some View {
        Text("Не получилось синхронизировать данные. Приложение попробует ещё раз позже.")
            .padding()
            .frame(maxWidth: 260)
    }
}

#Preview {
    NavigationView {
        Color.clear
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    SyncIndicatorView(syncState: .failed, accent: .accentColor)
                }
            }
    }
}
