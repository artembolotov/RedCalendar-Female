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

    /// What is actually drawn. Deliberately not `syncState` itself: `reconcile(to:)` only ever
    /// copies a new value in here once `indicatorAppearDelayNanoseconds` has passed with the real
    /// state still not `.idle`, so a run that finishes inside that window — a fast connection,
    /// almost always — never commits a value here at all, and the indicator never draws.
    @State private var displayedState: SyncState = .idle
    @State private var appearTask: Task<Void, Never>?

    // Matches `HomeMenuView.fallbackDiameter` — the trailing side draws the same backing for the
    // same reason: the calendar runs under a transparent navigation bar, so the glyph sits on a
    // passing day rather than on a plate unless something is drawn behind it.
    private let fallbackDiameter: CGFloat = 36

    var body: some View {
        badge {
            icon
        }
        // Fixed regardless of state, on both sides of the `#available` branch inside `badge` —
        // that is what makes the fade below real. A `UIBarButtonItem`'s hosted content does not
        // animate a *size* change; SwiftUI's own transaction reaches it, but the bar just
        // re-lays-out in one frame. `.idle` used to be a literal `EmptyView()` at zero size next
        // to a 36pt badge, which is exactly that case. Holding the frame constant and animating
        // `.opacity` instead is the standard workaround, because that one SwiftUI *can* interpolate
        // without asking the bar to re-layout.
        .frame(width: fallbackDiameter, height: fallbackDiameter)
        .opacity(displayedState == .idle ? 0 : 1)
        .allowsHitTesting(displayedState != .idle)
        // The frame is reserved at `.idle` for the fade above to work, but there is nothing to
        // land on — VoiceOver must not stop on an empty circle.
        .accessibilityHidden(displayedState == .idle)
        .animation(.easeInOut(duration: 0.2), value: displayedState)
        .onChange(of: syncState) { newValue in reconcile(to: newValue) }
        .onAppear { reconcile(to: syncState) }
        .onDisappear { appearTask?.cancel() }
    }

    @ViewBuilder
    private var icon: some View {
        switch displayedState {
        case .idle:
            // The `.opacity` above already hides this; kept empty rather than the last real
            // glyph so nothing lingers wrongly labelled underneath a hidden frame.
            EmptyView()

        case .syncing:
            ProgressView()
                .tint(accent)
                .accessibilityLabel("Синхронизация")

        case .pending:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(accent)
                .accessibilityLabel("Есть несохранённые данные")

        case .failed(let origin):
            Button {
                explanationPresented = true
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
            }
            .accessibilityLabel("Не удалось синхронизировать данные")
            .accessibilityHint("Нажмите, чтобы узнать больше")
            .popover(isPresented: $explanationPresented) {
                explanation(for: origin)
            }
        }
    }

    // MARK: - Private Methods

    /// Gates *appearing*, never disappearing. `displayedState == .idle` is the only branch that
    /// waits: nothing is on screen yet, so there is something to lose by committing too early.
    /// Once something is already drawn, a change — including a drop back to `.idle` — is applied
    /// immediately, because hiding what is already visible more slowly than it actually resolved
    /// would show a stale badge, not a smoother one.
    private func reconcile(to newValue: SyncState) {
        appearTask?.cancel()
        appearTask = nil

        guard newValue != .idle, displayedState == .idle else {
            displayedState = newValue
            return
        }

        appearTask = Task {
            try? await Task.sleep(nanoseconds: Constants.Sync.indicatorAppearDelayNanoseconds)
            guard !Task.isCancelled else { return }
            displayedState = newValue
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

    // A popover rather than an alert: in neither case is there a decision to make, so this is
    // something to look at rather than something that needs answering.
    //
    // Two texts, because only one of the two failures retries by itself. A failed run has its
    // retry already scheduled by `handleFailure` (§5.7); a failed import has nothing scheduled —
    // the poll follows `running`, and the server re-claims the import at the next sign-in
    // (§10.4). Promising "later" there would promise what no one is going to do.
    private func explanation(for origin: SyncState.FailureOrigin) -> some View {
        Text(explanationText(for: origin))
            .padding()
            .frame(maxWidth: 260)
    }

    private func explanationText(for origin: SyncState.FailureOrigin) -> String {
        switch origin {
        case .syncRun:
            "Не получилось синхронизировать данные. Приложение попробует ещё раз позже."
        case .firebaseImport:
            "Не получилось перенести данные из старого приложения. Попытка повторится при следующем входе."
        }
    }
}

#Preview {
    NavigationView {
        Color.clear
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    SyncIndicatorView(syncState: .failed(.firebaseImport), accent: .accentColor)
                }
            }
    }
}
