//
//  DayDetailsPagerView.swift
//  RedCalendar-Female
//

import SwiftUI
import Combine

// Horizontal pager around `DayDetailsView`: dragging the card sideways moves the selection
// one day at a time, dragging it down dismisses it. Both come from the same window pan
// recognizer, which decides the axis once per gesture.
//
// Cards are laid out against `anchorDay` and moved with a single continuous `pageOffset`,
// never re-based mid-flight: a commit only animates that offset one slot further. Re-basing
// (`reanchor()`) happens once the card is at rest, where swapping the anchor for a zero
// offset draws exactly the same pixels.
struct DayDetailsPagerView: View {
    @EnvironmentObject var store: AppStore

    let dayStamp: Daystamp
    let width: CGFloat

    @Binding var dragOffset: CGFloat
    @Binding var height: CGFloat

    // The visual state leads the store: `Store.send` lands a run loop later, so paging has to
    // be driven locally and let the selection catch up.
    @State private var anchorDay: Daystamp?
    @State private var shiftInFlight = 0
    @State private var pageOffset: CGFloat = 0
    @State private var cardFrame: CGRect = .zero
    @State private var isPaging = false
    @State private var isDraggingHorizontally = false
    // Fires once the last settle has landed; debounce keeps a superseded settle from
    // re-anchoring in the middle of the next one.
    @State private var settleDebouncer = PassthroughSubject<Void, Never>()
    // Day we last dispatched. Two quick swipes put two selections in flight, and the first
    // one arriving back must not drag the pager backwards.
    @State private var pendingSelection: Daystamp?

    private let velocityThreshold: CGFloat = 1200
    private let rubberBandFactor: CGFloat = 0.3
    private let bottomThreshold: CGFloat = 250
    private let maxUpwardOffset: CGFloat = 150

    private let pageCommitRatio: CGFloat = 0.25
    // How far ahead a flick is projected when deciding whether it committed a page.
    private let pageVelocityProjection: CGFloat = 0.15
    private let settleDuration: TimeInterval = 0.28
    // Re-anchoring after the settle has landed is invisible; doing it early is not, so the
    // timer deliberately trails the animation.
    private let settleMargin: TimeInterval = 0.06

    private var anchor: Daystamp {
        anchorDay ?? dayStamp
    }

    private var activeDay: Daystamp {
        anchor + shiftInFlight
    }

    // The gap between two cards equals the card's own inset from the screen edge, so the
    // next card begins exactly where the screen ends and never shows an edge at rest.
    private var pageStride: CGFloat {
        width - DayDetailsMetrics.screenInset
    }

    // Neighbours are only mounted while paging — parked at the screen edge their shadow
    // would bleed back over it.
    private var visibleDays: [Daystamp] {
        isPaging ? [anchor - 1, anchor, anchor + 1] : [activeDay]
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(visibleDays, id: \.rawValue) { day in
                DayDetailsView(
                    dayStamp: day,
                    isActive: day == activeDay,
                    dragOffset: day == activeDay ? dragOffset : 0
                )
                .offset(x: CGFloat(day - anchor) * pageStride + pageOffset)
            }
        }
        .background(
            WindowGestureHandler(gestureFrame: cardFrame) { translation, velocity, state, axis in
                handlePan(translation: translation, velocity: velocity, state: state, axis: axis)
            }
        )
        .onChange(of: dayStamp) { newValue in
            // While our own selection is still in flight the store is behind us; only a day
            // that came from somewhere else (a calendar tap) re-centers the pager.
            if let pending = pendingSelection {
                if newValue == pending {
                    pendingSelection = nil
                }
                return
            }

            guard newValue != activeDay else { return }
            anchorDay = newValue
            shiftInFlight = 0
            pageOffset = 0
            isPaging = false
        }
        .onPreferenceChange(DayCardFrameKey.self) { frame in
            guard frame != .zero else { return }
            cardFrame = frame
            height = frame.height
        }
        .onReceive(
            settleDebouncer.debounce(
                for: .seconds(settleDuration + settleMargin),
                scheduler: DispatchQueue.main
            )
        ) { _ in
            guard !isDraggingHorizontally else { return }
            reanchor()
            isPaging = false
        }
    }

    // MARK: - Gesture routing

    private func handlePan(translation: CGFloat, velocity: CGFloat, state: PanGestureState, axis: PanGestureAxis) {
        switch axis {
        case .vertical:
            handleVerticalPan(translation: translation, velocity: velocity, state: state)
        case .horizontal:
            handleHorizontalPan(translation: translation, velocity: velocity, state: state)
        }
    }

    // MARK: - Horizontal paging

    private func handleHorizontalPan(translation: CGFloat, velocity: CGFloat, state: PanGestureState) {
        switch state {
        case .began:
            break

        case .changed:
            if !isPaging {
                isPaging = true
            }
            isDraggingHorizontally = true
            // Grabbing the card mid-settle: finish the pending page first so the drag is
            // measured from the day the user is actually looking at.
            if shiftInFlight != 0 {
                reanchor()
            }
            pageOffset = translation

        case .ended:
            let projected = translation + velocity * pageVelocityProjection
            let commitDistance = pageStride * pageCommitRatio

            // Dragging left brings in the card on the right — the next day.
            if projected < -commitDistance {
                commit(shift: 1)
            } else if projected > commitDistance {
                commit(shift: -1)
            } else {
                settle(to: 0)
            }

        case .cancelled, .failed:
            settle(to: shiftInFlight == 0 ? 0 : CGFloat(-shiftInFlight) * pageStride)
        }
    }

    private func commit(shift: Int) {
        shiftInFlight = shift
        settle(to: CGFloat(-shift) * pageStride)

        let newSelection = anchor + shift
        pendingSelection = newSelection
        store.send(.setSelectedDayStamp(newSelection))
    }

    private func settle(to target: CGFloat) {
        isDraggingHorizontally = false

        withAnimation(.easeOut(duration: settleDuration)) {
            pageOffset = target
        }

        settleDebouncer.send(())
    }

    // Swaps the slot the offsets are measured from for an offset of zero — the same picture,
    // so it must only ever run while the card is at rest.
    private func reanchor() {
        guard shiftInFlight != 0 || pageOffset != 0 else { return }

        let newAnchor = activeDay

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            anchorDay = newAnchor
            shiftInFlight = 0
            pageOffset = 0
        }
    }

    // MARK: - Vertical dismiss

    private func handleVerticalPan(translation: CGFloat, velocity: CGFloat, state: PanGestureState) {
        switch state {
        case .began:
            break
        case .changed:
            handleDragChanged(translation: translation)
        case .ended:
            handleDragEnded(velocity: velocity)
        case .cancelled, .failed:
            withAnimation(.bouncy) {
                dragOffset = 0
            }
        }
    }

    private func handleDragChanged(translation: CGFloat) {
        if translation < 0 {
            let absTranslation = abs(translation)
            let initialVisualThreshold = maxUpwardOffset / 3
            let initialTranslationThreshold = initialVisualThreshold / rubberBandFactor

            if absTranslation <= initialTranslationThreshold {
                dragOffset = translation * rubberBandFactor
            } else {
                let baseOffset = initialVisualThreshold
                let excessTranslation = absTranslation - initialTranslationThreshold

                let remainingDistance = maxUpwardOffset - initialVisualThreshold
                let resistanceFactor = 1.0 / (1.0 + excessTranslation / (remainingDistance * 2.0))
                let excessOffset = excessTranslation * rubberBandFactor * resistanceFactor

                let totalOffset = baseOffset + excessOffset
                dragOffset = -min(totalOffset, maxUpwardOffset)
            }
        } else {
            dragOffset = translation
        }
    }

    private func handleDragEnded(velocity: CGFloat) {
        guard cardFrame.height > 0 else {
            withAnimation(.bouncy) { dragOffset = 0 }
            return
        }

        if (cardFrame.height < bottomThreshold) && velocity >= -150 || velocity > velocityThreshold {
            store.send(.setSelectedDayStamp(nil))
        } else {
            withAnimation(.bouncy) {
                dragOffset = 0
            }
        }
    }
}
