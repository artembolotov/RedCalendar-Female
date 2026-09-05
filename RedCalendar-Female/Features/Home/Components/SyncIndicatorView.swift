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
///
/// **Nothing here may change *shape* while the failure popover is open — only attributes.**
/// `syncState` moves on `SyncMiddleware`'s schedule rather than the user's: while a run keeps
/// failing, a backoff retry flips it through `.syncing` and back every few seconds whether or not
/// anything is open. If that flips a `ViewBuilder` branch anywhere inside this view — the badge's
/// glyph or the popover's content — SwiftUI rebuilds the content the toolbar item hosts, the
/// presentation attached to it is torn down and re-made under UIKit, and UIKit answers with
/// "Attempt to present … while a presentation is in progress" / "Trying to dismiss the
/// presentation controller while transitioning already". That is not a crash; it corrupts the
/// scene badly enough to drop the whole app to the Home Screen.
///
/// Moving the `.popover` to a node that is never itself removed does **not** fix it — that was
/// tried, and one tap still took the app down, because the rebuild is of the *hosted content*,
/// not of the node the presentation hangs off. So the fix is upstream of the presentation
/// entirely: `icon` below is one `ZStack` whose children always all exist, and the popover's
/// content is pinned to a value captured when it opened. Both switch on `opacity` and `disabled`,
/// which cost no rebuild, and `displayedState` is then free to track `syncState` live — spinner
/// while a retry is in flight, gone the moment a run finally succeeds.
struct SyncIndicatorView: View {
    let syncState: SyncState
    let accent: Color
    /// Fires `.sync(.requested(.retry))`. Not called from here directly — same reason `accent`
    /// is a parameter and not a store read: this is toolbar content, where `@EnvironmentObject`
    /// is not reliably reachable.
    let onRetry: () -> Void
    /// Mirrors `displayedState != .idle`, written back to `HomeView` so it can drive
    /// `.sharedBackgroundVisibility` on the *toolbar item*, not on any view in here.
    /// `sharedBackgroundVisibility` is a `ToolbarContent` modifier (iOS 26+), not a `View` one —
    /// it cannot be applied from inside this type at all. It exists because `.opacity(0)` alone
    /// does not hide this badge at `.idle` on iOS 26: the automatic "Liquid Glass" background the
    /// system draws behind toolbar content is keyed off whether the item *has content*, not off
    /// what that content currently renders as, so it stays visible — an empty glass circle —
    /// however transparent everything inside is made. A `Binding` rather than a callback because
    /// `HomeView` needs the value to build its `.toolbar {}`, not just to react to a change in it.
    @Binding var isVisible: Bool

    /// The open explanation, or `nil`. An `item` rather than an `isPresented` flag because the
    /// origin has to be *captured* when the badge is tapped: read live from `syncState` instead,
    /// the popover's content collapses to an empty branch every time a backoff retry passes
    /// through `.syncing`, which is the content-shaped half of the failure described above.
    @State private var explanation: FailureExplanation?

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
        .popover(item: $explanation) { open in
            explanationBody(for: open.origin)
        }
        .onChange(of: syncState) { newValue in
            reconcile(to: newValue)
            dismissExplanationIfResolved(by: newValue)
        }
        .onAppear { reconcile(to: syncState) }
        .onDisappear { appearTask?.cancel() }
    }

    /// One `ZStack`, never a `switch`: every glyph is always in the tree and only `opacity`
    /// selects between them. See the type's doc for why a branch here is what used to take the
    /// app down. The hidden `ProgressView` is the price — it goes on animating behind
    /// `opacity(0)` — and it is one small layer that measured at 10 ms of process CPU over a 20 s
    /// idle window, against a `switch` whose cost is a scene this view cannot repair.
    private var icon: some View {
        ZStack {
            ProgressView()
                .tint(accent)
                .accessibilityLabel("Sync.Syncing.A11y")
                .opacity(displayedState == .syncing ? 1 : 0)
                .accessibilityHidden(displayedState != .syncing)

            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(accent)
                .accessibilityLabel("Sync.Pending.A11y")
                .opacity(displayedState == .pending ? 1 : 0)
                .accessibilityHidden(displayedState != .pending)

            Button {
                if case .failed(let origin) = displayedState {
                    explanation = FailureExplanation(origin: origin)
                }
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
            }
            .accessibilityLabel("Sync.Failed.A11y")
            .accessibilityHint("Sync.Failed.Hint")
            .opacity(hasFailed ? 1 : 0)
            .allowsHitTesting(hasFailed)
            .accessibilityHidden(!hasFailed)
        }
    }

    private var hasFailed: Bool {
        if case .failed = displayedState { return true }
        return false
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
            isVisible = newValue != .idle
            return
        }

        appearTask = Task {
            try? await Task.sleep(nanoseconds: Constants.Sync.indicatorAppearDelayNanoseconds)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: fadeDuration)) {
                displayedState = newValue
            }
            isVisible = newValue != .idle
        }
    }

    /// An open explanation outlives a retry and closes on an outcome. `.syncing` is the state
    /// every retry passes through — `SyncMiddleware`'s own backoff one every few seconds, or the
    /// user's from the button below — and closing on it would snap the popover shut on a timer
    /// nobody touched. Anything else means the failure this was opened for is over, and an
    /// explanation of a failure that no longer exists is worse than no explanation. This is what
    /// `.popover` has instead of an `onDismiss`, and the reason the retry button needs none.
    private func dismissExplanationIfResolved(by newValue: SyncState) {
        guard let open = explanation else { return }

        switch newValue {
        case .syncing:
            break
        case .failed(let origin) where origin == open.origin:
            break
        case .idle, .pending, .failed:
            explanation = nil
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
    // popover — anchored to the triangle — on an iPhone's compact width. Without it, SwiftUI's
    // default compact adaptation presents this as a full sheet, which is what every build below
    // 16.4 still gets; there is no substitute available there.
    private func explanationBody(for origin: SyncState.FailureOrigin) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(explanationText(for: origin))
                .fixedSize(horizontal: false, vertical: true)
            if origin == .syncRun {
                // Does not dismiss. The run it starts is what closes this, by resolving —
                // `dismissExplanationIfResolved` above — so the popover stays up and greys the
                // button for as long as the attempt is in flight, which is the only progress
                // the user can see while the popover covers the badge. Dismissing here as well
                // would put a dismissal transition and the `.syncing` the retry produces in the
                // same instant, and racing those two is a way this used to take the app down.
                //
                // `origin` is captured for the life of the presentation, so this branch is a
                // constant while the popover is open — the *shape* of the content never changes
                // under an in-flight presentation, only `disabled`.
                Button("Sync.Retry.Button", action: onRetry)
                    .disabled(syncState == .syncing)
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

    private func explanationText(for origin: SyncState.FailureOrigin) -> LocalizedStringKey {
        switch origin {
        case .syncRun:
            "Sync.Failure.SyncRun.Message"
        case .firebaseImport:
            "Sync.Failure.FirebaseImport.Message"
        }
    }
}

/// The identity is the *opening*, not the origin: a popover closed and opened again has to read
/// as a new presentation rather than a reuse of the one that just went away.
private struct FailureExplanation: Identifiable {
    let id = UUID()
    let origin: SyncState.FailureOrigin
}

/// Isolated in its own conformance rather than an inline `if #available` in `explanationBody(for:)`,
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

private struct SyncIndicatorPreview: View {
    @State private var isVisible = false

    var body: some View {
        NavigationView {
            Color.clear
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        SyncIndicatorView(
                            syncState: .failed(.firebaseImport),
                            accent: .accentColor,
                            onRetry: {},
                            isVisible: $isVisible
                        )
                    }
                }
        }
    }
}

#Preview {
    SyncIndicatorPreview()
}
