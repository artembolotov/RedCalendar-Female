//
//  Store.swift
//  RedCalendar-Female
//
//  Simple solution with Task.yield() for smooth animations
//

import Foundation
import Combine

typealias Reducer<State, Action> = (State, Action) -> State
typealias Middleware<State, Action> = (State, Action, @escaping (Action) -> Void) async -> [Action]

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
