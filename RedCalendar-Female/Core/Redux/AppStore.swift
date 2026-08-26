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
///
/// A middleware emits actions **one way**: through `dispatch`. It used to also be able to return
/// them, and the two paths were never distinguishable at the call site — a returned action and a
/// dispatched one both ended up in the same queue. What the return path actually bought was 15
/// `return []` statements in bodies that emit nothing at all.
typealias Dispatch = @MainActor @Sendable (AppAction) -> Void
typealias Middleware = @MainActor @Sendable (AppState, AppAction, @escaping Dispatch) async -> Void

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

    /// An action paired with the state **its own** reducer produced, rather than with whatever
    /// the state has become by the time the queue reaches it. That is the only reading of
    /// "the state a middleware sees" that does not depend on how long the queue is.
    ///
    /// A nominal struct rather than the obvious `(action:state:)` tuple. Both attempts at this
    /// queue in the reverted migration used a generic type instantiated at a tuple —
    /// `AsyncStream<(action:state:)>`, then `[(action:state:)]` — and both archives died in the
    /// optimizer's generic-layout check. A struct has one concrete layout and nothing to
    /// substitute. Three lines, and the cheapest hedge available against a compiler bug nobody
    /// has isolated.
    private struct Effect {
        let action: AppAction
        let state: AppState
    }

    private var queue: [Effect] = []
    private var isDraining = false

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

    /// A dispatch is two halves, and the split is the design.
    ///
    /// The **reducer runs synchronously**, here, on the caller's turn — so state changes in the
    /// order actions were sent, and it has already changed by the time `send` returns. The
    /// **effects are queued**, and drained one at a time, so one action's middleware chain
    /// finishes before the next one's begins.
    ///
    /// Every dispatch used to be its own unstructured `Task` opening with `await Task.yield()`,
    /// which gave away both halves: two actions sent back to back diverged at that first
    /// suspension point and ran their middleware concurrently. That is the shape behind both
    /// crashes this app has shipped — a burst of `.calendarScrolledTo` during a fling restarting
    /// the same GRDB observation from two threads, and a haptic generator driven from the pool.
    /// Isolating the two middlewares that got caught fixed those two cases and never fixed the
    /// ordering; the main actor is reentrant, so an `await` inside any middleware stayed a
    /// window the next action could land in.
    func send(_ action: AppAction) {
        let newState = reducer(state, action)
        // Skip the @Published write for no-op actions — otherwise every
        // dispatch invalidates all observing views even when nothing changed.
        if newState != state {
            state = newState
        }

        queue.append(Effect(action: action, state: state))
        drain()
    }

    // MARK: - Private Implementation

    /// Reentrancy is the whole of it: `send` called from inside the loop below — always through a
    /// middleware's `dispatch` — appends and returns, because `isDraining` is already true. One
    /// drain task exists at a time and it runs until the queue is empty.
    ///
    /// What this does *not* do is make a slow middleware free: a long `await` in one delays
    /// every action behind it. That stays affordable only because the heavy middlewares return
    /// immediately and do their work in their own `Task`, dispatching the result when it lands.
    /// Keep that shape.
    private func drain() {
        guard !isDraining else { return }
        isDraining = true

        Task {
            while !queue.isEmpty {
                let effect = queue.removeFirst()

                for middleware in middlewares {
                    await middleware(effect.state, effect.action) { [weak self] followUp in
                        self?.send(followUp)
                    }
                }
            }

            isDraining = false
        }
    }
}

// MARK: - The App's Store

extension AppStore {
    /// The one store, owned by the process rather than by a scene (SYNC.md §8).
    ///
    /// It used to be a `@StateObject` initialiser expression in `RedCalendarApp`, which meant it
    /// did not exist until `WindowGroup`'s closure ran. A background push launches the app with no
    /// scene at all: the closure never ran, the autoclosure never evaluated, and the delegate's
    /// store reference stayed `nil` — so `.auth(.check)` was never dispatched and the fetch
    /// completion handler had nothing useful to report, which is what makes iOS throttle the
    /// pushes.
    ///
    /// A `lazy static let`, like `ServiceLocator`, `Configurator` and `DatabaseMiddleware`. Lazy is
    /// the load-bearing half: evaluating it calls `combineAppMiddlewares()`, and any service
    /// resolved before `Configurator.shared.setup()` has registered it is a `fatalError`. Nothing
    /// may touch this before that call — which is why `AppDelegate` makes it first.
    static let shared = AppStore(
        initialState: AppState(),
        reducer: appReducer,
        middlewares: combineAppMiddlewares()
    )
}
