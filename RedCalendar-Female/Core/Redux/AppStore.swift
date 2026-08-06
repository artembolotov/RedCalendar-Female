//
//  AppStore.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation
import Combine

typealias Reducer = (AppState, AppAction) -> AppState
typealias Dispatch = (AppAction) -> Void
typealias Middleware = (AppState, AppAction, @escaping Dispatch) async -> [AppAction]

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
