//
//  Store.swift
//  RedCalendar-Female
//
//  Simple solution with Task.yield() for smooth animations
//

import Foundation
import Combine

typealias Reducer<State, Action> = @MainActor (State, Action) -> State

/// A middleware body runs **on the main actor**, and the annotation is written out rather than
/// left to `SWIFT_DEFAULT_ACTOR_ISOLATION` because this type is the contract the whole side-effect
/// layer is built against.
///
/// It used to be unisolated, which meant awaiting it from the `@MainActor` store hopped *off* the
/// main actor — so the safe default was the one you had to opt into, one middleware at a time. The
/// bill came due twice: `TapticFeedbackService` grew a hand-rolled `Thread.isMainThread` hop
/// because a `UIFeedbackGenerator` touched from the pool kills the process, and `DatabaseMiddleware`
/// had to be isolated after two concurrent actions over-released the same GRDB observation token.
/// Neither was a bug in those files; both were this typealias.
///
/// Work that must not run on the main actor now says so, in the one place that knows: a service
/// method marked `nonisolated`, or an `await` on something that is. That is a claim the compiler
/// checks, which `Thread.isMainThread` never was.
typealias Middleware<State, Action> =
    @MainActor (State, Action, @escaping @MainActor (Action) -> Void) async -> [Action]

@MainActor
final class Store<State, Action>: ObservableObject {
    @Published private(set) var state: State
    private let reducer: Reducer<State, Action>
    private let middlewares: [Middleware<State, Action>]
    private let isDuplicate: ((State, State) -> Bool)?

    init(
        initialState: State,
        reducer: @escaping Reducer<State, Action>,
        middlewares: [Middleware<State, Action>] = [],
        isDuplicate: ((State, State) -> Bool)? = nil
    ) {
        self.state = initialState
        self.reducer = reducer
        self.middlewares = middlewares
        self.isDuplicate = isDuplicate
    }

    // MARK: - Public Interface

    func send(_ action: Action) {
        Task {
            // Yield to give animations priority
            await Task.yield()

            let newState = reducer(state, action)
            // Skip the @Published write for no-op actions — otherwise every
            // dispatch invalidates all observing views even when nothing changed.
            if isDuplicate?(state, newState) != true {
                state = newState
            }

            await processMiddlewares(for: action)
        }
    }
    
    // MARK: - Private Implementation
    
    private func processMiddlewares(for action: Action) async {
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

// MARK: - Middleware Helpers
func combineMiddleware<State, Action>(
    _ middlewares: Middleware<State, Action>...
) -> Middleware<State, Action> {
    return { state, action, dispatch in
        var allActions: [Action] = []
        for middleware in middlewares {
            let actions = await middleware(state, action, dispatch)
            allActions.append(contentsOf: actions)
        }
        return allActions
    }
}
