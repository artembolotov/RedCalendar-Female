//
//  Store.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

typealias Reducer<State, Action> = (State, Action) -> State
typealias Middleware<State, Action> = (State, Action) async -> Action?

@MainActor
final class Store<State, Action>: ObservableObject {
    @Published private(set) var state: State
    private let reducer: Reducer<State, Action>
    private let middleware: Middleware<State, Action>?
    
    init(
        initialState: State,
        reducer: @escaping Reducer<State, Action>,
        middleware: Middleware<State, Action>? = nil
    ) {
        self.state = initialState
        self.reducer = reducer
        self.middleware = middleware
    }
    
    func send(_ action: Action) {
        state = reducer(state, action)
        
        Task {
            if let middleware = middleware,
               let nextAction = await middleware(state, action) {
                send(nextAction)
            }
        }
    }
}
