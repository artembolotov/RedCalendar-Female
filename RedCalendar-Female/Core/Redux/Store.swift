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
    
    init(
        initialState: State,
        reducer: @escaping Reducer<State, Action>,
        middlewares: [Middleware<State, Action>] = []
    ) {
        self.state = initialState
        self.reducer = reducer
        self.middlewares = middlewares
    }
    
    // MARK: - Public Interface
    
    func send(_ action: Action) {
        Task {
            // Yield to give animations priority
            await Task.yield()
            
            state = reducer(state, action)
            
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
