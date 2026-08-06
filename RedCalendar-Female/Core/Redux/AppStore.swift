//
//  AppStore.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation
import Combine

typealias Reducer = (AppState, AppAction) -> AppState

/// Both are `@MainActor`, and that is the boundary the whole app's thread-safety rests on.
///
/// `Middleware` used to be an unisolated `async` closure type, so awaiting it from the
/// `@MainActor` store hopped *off* the main actor and every middleware body ran on the
/// cooperative pool. Two things followed. The `dispatch` closure below is formed in a
/// main-actor context, so handing it to an unisolated parameter type erased its isolation
/// and all 17 `dispatch(…)` calls invoked a main-actor closure from a pool thread — legal
/// only because nothing was checking. And anything main-thread-only that a middleware
/// touched had to catch itself: `TapticFeedbackService` carried a hand-rolled
/// `Thread.isMainThread` hop for exactly that reason, after a `UIFeedbackGenerator` driven
/// from the pool killed the process.
///
/// Isolating the two typealiases costs two words and replaces both workarounds. Nothing that
/// *should* leave the main actor is affected: every such call in this app is already `async`
/// on an unisolated protocol (`APIService`, `PushPermissionService`, `DatabaseService`'s
/// CRUD), and a `nonisolated async` function runs on the generic executor no matter which
/// actor called it.
///
/// `@Sendable` is free here — all seven global middlewares are closure literals capturing
/// nothing — and it is what lets them stay global `let`s.
typealias Dispatch = @MainActor @Sendable (AppAction) -> Void
typealias Middleware = @MainActor @Sendable (AppState, AppAction, @escaping Dispatch) async -> [AppAction]

/// Concrete over `AppState`/`AppAction` rather than generic, and that is deliberate twice over.
///
/// It was `Store<State, Action>` with exactly one instantiation — a seam for a second store that
/// never arrived and has no test target to consume it. The genericity also had a cost nobody could
/// see from a debug build: `swift-frontend` crashed archiving this app, in `EarlyPerfInliner`'s
/// `isCallerAndCalleeLayoutConstraintsCompatible`, on this class's *implicit deinit*, and the
/// reported source location was the `final class Store<…>` line itself. That pass runs only under
/// `-O`, so six PRs merged green and shipped nothing to TestFlight before it was found. A
/// non-generic class's deinit has an empty generic signature, so the check that recursed has
/// nothing left to walk.
///
/// If a second store is ever genuinely wanted, re-introducing the generic parameters is the
/// mechanical inverse of this — but archive the result before merging it.
@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var state: AppState
    private let reducer: Reducer
    private let middlewares: [Middleware]

    init(
        initialState: AppState,
        reducer: @escaping Reducer,
        middlewares: [Middleware] = []
    ) {
        self.state = initialState
        self.reducer = reducer
        self.middlewares = middlewares
    }

    // MARK: - Public Interface

    func send(_ action: AppAction) {
        Task {
            // Yield to give animations priority
            await Task.yield()

            let newState = reducer(state, action)
            // Skip the @Published write for no-op actions — otherwise every
            // dispatch invalidates all observing views even when nothing changed.
            if newState != state {
                state = newState
            }

            await processMiddlewares(for: action)
        }
    }

    // MARK: - Private Implementation

    private func processMiddlewares(for action: AppAction) async {
        for middleware in middlewares {
            let actions = await middleware(state, action) { [weak self] asyncAction in
                self?.send(asyncAction)
            }

            for action in actions {
                send(action)
            }
        }
    }
}
