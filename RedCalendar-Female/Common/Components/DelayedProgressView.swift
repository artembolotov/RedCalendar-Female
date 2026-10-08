//
//  DelayedProgressView.swift
//  RedCalendar-Female
//

import SwiftUI

/// A spinner for one thing being waited on, with `SyncIndicatorView`'s rules for when it shows:
/// appearing waits `appearDelayNanoseconds`, so a request answered inside that window never draws
/// a frame of it; disappearing is immediate, because hiding what is already shown later than it
/// resolved would show a stale spinner rather than a smoother one.
///
/// It always occupies its frame and is hidden by `opacity` alone. A spinner put into a stack and
/// taken out again moves everything after it — which is what the consent form did when its
/// version arrived.
struct DelayedProgressView: View {
    let isActive: Bool
    let appearDelayNanoseconds: UInt64
    /// `nil` keeps the system's grey.
    let tint: Color?

    /// Written whenever the spinner shows or hides, for a toolbar item on iOS 26: the glass the
    /// system draws behind it is keyed off whether the item has content, not off its opacity, and
    /// only `.sharedBackgroundVisibility` on the item itself can hide it. See `DevicesToolbar`.
    @Binding var isVisible: Bool

    @State private var isShown = false
    @State private var appearTask: Task<Void, Never>?

    // Same duration and same reason as `SyncIndicatorView.fadeDuration`: a change made from a
    // `Task.sleep` resuming is not reliably caught by an ambient `.animation(value:)`.
    private let fadeDuration: TimeInterval = 0.2

    init(
        isActive: Bool,
        appearDelayNanoseconds: UInt64,
        tint: Color? = nil,
        isVisible: Binding<Bool> = .constant(false)
    ) {
        self.isActive = isActive
        self.appearDelayNanoseconds = appearDelayNanoseconds
        self.tint = tint
        self._isVisible = isVisible
    }

    var body: some View {
        ProgressView()
            .tint(tint)
            .opacity(isShown ? 1 : 0)
            .accessibilityHidden(!isShown)
            .onChange(of: isActive) { reconcile(isActive: $0) }
            .onAppear { reconcile(isActive: isActive) }
            .onDisappear { appearTask?.cancel() }
    }

    // MARK: - Private Methods

    private func reconcile(isActive: Bool) {
        appearTask?.cancel()
        appearTask = nil

        guard isActive, !isShown else {
            show(isActive)
            return
        }

        appearTask = Task {
            try? await Task.sleep(nanoseconds: appearDelayNanoseconds)
            guard !Task.isCancelled else { return }
            show(true)
        }
    }

    private func show(_ shown: Bool) {
        withAnimation(.easeInOut(duration: fadeDuration)) {
            isShown = shown
        }
        isVisible = shown
    }
}
