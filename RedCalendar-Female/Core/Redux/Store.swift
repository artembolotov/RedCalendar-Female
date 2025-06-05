//
//  Store.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

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
    
    func send(_ action: Action) {
        state = reducer(state, action)
        
        Task {
            await processMiddlewares(for: action)
        }
    }
    
    private func processMiddlewares(for action: Action) async {
        for middleware in middlewares {
            let actions = await middleware(state, action) { [weak self] asyncAction in
                Task { @MainActor in
                    self?.send(asyncAction)
                }
            }
            
            for action in actions {
                await MainActor.run {
                    send(action)
                }
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
