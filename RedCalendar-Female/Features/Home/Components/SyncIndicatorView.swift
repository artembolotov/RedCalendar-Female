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
    /// Fires `.sync(.requested(.retry))`. Not called from here directly — same reason `accent`
    /// is a parameter and not a store read: this is toolbar content, where `@EnvironmentObject`
    /// is not reliably reachable.
    let onRetry: () -> Void

    @State private var explanationPresented = false
    /// Set by the retry button, consumed by the `onChange(of: explanationPresented)` below.
    /// `onRetry()` is not called from the button directly — see `displayedState`'s doc for why
    /// the retry has to wait until the popover has actually finished closing.
    @State private var retryPending = false

    /// What is actually drawn. Deliberately not `syncState` itself: `reconcile(to:)` only ever
    /// copies a new value in here once `indicatorAppearDelayNanoseconds` has passed with the real
    /// state still not `.idle`, so a run that finishes inside that window — a fast connection,
    /// almost always — never commits a value here at all, and the indicator never draws.
    ///
    /// **Frozen while the popover is open.** `syncState` keeps moving on its own schedule even
    /// then — an automatic backoff retry (`SyncMiddleware`'s, not a tap on "Повторить сейчас")
    /// flips it through `.syncing` and back every few seconds while a run keeps failing. If that
    /// reached `displayedState` live, it would swap `icon`'s `switch` out of the `.failed` case
    /// (the `Button` the popover is anchored to) and back, mid-presentation, on a timer the user
    /// never touched. UIKit answers a presentation whose anchor moves out from under it, or whose
    /// content changes shape, while its own transition is still settling with "Attempt to present
    /// … while a presentation is in progress" / "Trying to dismiss the presentation controller
    /// while transitioning already" — not a crash, but it corrupts the scene enough to drop the
    /// whole app to the Home Screen. `onChange(of: explanationPresented)` below catches
    /// `displayedState` up to whatever `syncState` became in the meantime, once the popover is
    /// safely closed and there is nothing left for a state change to collide with.
    @State private var displayedState: SyncState = .idle
    @State private var appearTask: Task<Void, Never>?

    // Matches `HomeMenuView.fallbackDiameter` — the trailing side draws the same backing for the
    // same reason: the calendar runs under a transparent navigation bar, so the glyph sits on a
    // passing day rather than on a plate unless something is drawn behind it.
    private let fallbackDiameter: CGFloat = 36

    // Same lesson as the calendar's selection disc (CLAUDE.md): a state change made from outside
    // a direct SwiftUI event — there a queued dispatch, here a `Task.sleep` resuming — is not
    // guaranteed to reach the view already wrapped in a transaction, so an *ambient*
    // `.animation(value:)` sitting on the view tree does not reliably catch it. Wrapping the
    // mutation itself in `withAnimation`, at every place `displayedState` is written, does.
    private let fadeDuration: TimeInterval = 0.2

    var body: some View {
        badge {
            icon
        }
        // Fixed regardless of state, on both sides of the `#available` branch inside `badge` —
        // that is what makes the fade above real. A `UIBarButtonItem`'s hosted content does not
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
        .onChange(of: syncState) { newValue in
            guard !explanationPresented else { return }
            reconcile(to: newValue)
        }
        // The other half of freezing `displayedState` above: once the popover closes, whatever
        // `syncState` has become in the meantime finally reaches the badge. `.popover` has no
        // `onDismiss` (unlike `.sheet`), so this doubles as that: it is also where a retry
        // requested while the popover was open actually fires — deferred to here, rather than
        // called directly from the button, so it starts *after* the dismiss has been requested
        // and this view has already reacted to it, never in the same instant as the request. See
        // `retryPending`.
        .onChange(of: explanationPresented) { presented in
            if !presented {
                reconcile(to: syncState)
                if retryPending {
                    retryPending = false
                    onRetry()
                }
            }
        }
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
            // On the `Button` itself: `displayedState` is frozen for as long as this popover is
            // presented (see its doc above), so the `.failed` case — and this `Button` with it —
            // is guaranteed not to disappear out from under the popover while it's open. That is
            // what makes anchoring here safe, and it's what buys the real arrow-pointing-at-the-
            // triangle popover `.presentationCompactAdaptation(.popover)` asks for, rather than
            // whatever a less specific anchor would fall back to.
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
            withAnimation(.easeInOut(duration: fadeDuration)) {
                displayedState = newValue
            }
            return
        }

        appearTask = Task {
            try? await Task.sleep(nanoseconds: Constants.Sync.indicatorAppearDelayNanoseconds)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: fadeDuration)) {
                displayedState = newValue
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

    // A popover rather than an alert: in neither case is there a decision to make, so this is
    // something to look at rather than something that needs answering.
    //
    // Two texts, because only one of the two failures retries by itself. A failed run has its
    // retry already scheduled by `handleFailure` (§5.7); a failed import has nothing scheduled —
    // the poll follows `running`, and the server re-claims the import at the next sign-in
    // (§10.4). Promising "later" there would promise what no one is going to do. The button
    // follows the same rule: `.syncRun` already has a retry coming, so a tap only moves it
    // earlier; `.firebaseImport` has none to move, so there is nothing to offer.
    //
    // `.presentationCompactAdaptation(.popover)` (iOS 16.4+) is what keeps this an actual
    // popover — arrow pointing at the triangle — on an iPhone's compact width. Without it,
    // SwiftUI's default compact adaptation presents this as a full sheet, which is what every
    // build below 16.4 still gets; there is no substitute available there.
    private func explanation(for origin: SyncState.FailureOrigin) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(explanationText(for: origin))
                .fixedSize(horizontal: false, vertical: true)
            if origin == .syncRun {
                // Only requests the close and marks the retry pending — never calls `onRetry()`
                // itself. See the `onChange(of: explanationPresented)` in `body` for why the two
                // are kept apart: dismissing and retrying in the same instant is the race that
                // used to drop the app to the Home Screen.
                Button("Повторить сейчас") {
                    retryPending = true
                    explanationPresented = false
                }
                .tint(accent)
            }
        }
        .padding()
        // A fixed width, not `maxWidth`: a popover sizes itself from its content's own ideal
        // size, computed before this frame's constraint is applied — `maxWidth` only clamps
        // that afterwards, by which point the `Text` has already reported its unwrapped
        // single-line width as ideal. A concrete `width` is what the wrapping is measured
        // against in the first place. `fixedSize` above is the same fix from the other side —
        // it stops the now-wrapped `Text` from reporting the popover a compressed height.
        .frame(width: 260, alignment: .leading)
        .modifier(CompactPopoverAdaptation())
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

/// Isolated in its own conformance rather than an inline `if #available` in `explanation(for:)`,
/// because a `ViewBuilder` branch on `#available` builds two branches of `some View` that must
/// still unify — annoying enough for one modifier that the standard workaround is to push the
/// branch into a `ViewModifier`, where `body`'s return type is erased already.
private struct CompactPopoverAdaptation: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationCompactAdaptation(.popover)
        } else {
            content
        }
    }
}

#Preview {
    NavigationView {
        Color.clear
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    SyncIndicatorView(syncState: .failed(.firebaseImport), accent: .accentColor, onRetry: {})
                }
            }
    }
}
