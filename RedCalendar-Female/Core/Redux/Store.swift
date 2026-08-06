//
//  Store.swift
//  RedCalendar-Female
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

/// The store splits a dispatch in two, and the split is the whole design.
///
/// The **reducer runs synchronously**, inside `send`, on the caller's turn of the run loop. State
/// therefore changes in the order actions were sent, and it has changed by the time `send` returns.
/// The **side effects are queued**, onto one stream that a single task drains in order, so one
/// action's middleware chain finishes before the next one's begins.
///
/// Every dispatch used to be its own unstructured `Task`, opening with `await Task.yield()`. That
/// gave away both halves. Two actions sent back to back diverged at the first suspension point and
/// ran their middleware concurrently, which is the shape behind both crashes this project has
/// shipped — a burst of `.calendarScrolledTo` during a fling restarting the same GRDB observation
/// from two threads at once, and a haptic generator driven from the pool. Isolating the middleware
/// that got caught fixed those two; it did not fix the ordering, and the main actor is reentrant,
/// so an `await` inside a middleware is still a gap the next action could previously land in.
///
/// The synchronous reducer buys back something separate: an animation chosen at the call site now
/// survives. `withAnimation { store.send(.setSelectedDayStamp(day)) }` could not work while the
/// state change was deferred into a `Task`, because the transaction is gone by the time the `Task`
/// runs. The `Task.yield()` that used to open every dispatch — "give animations priority" — was a
/// compensation for that, not a cause of it.
///
/// What the queue does *not* do is make a slow middleware free: a long `await` inside one delays
/// every action behind it. That is affordable because the heavy middlewares already return `[]`
/// immediately and do their work inside their own `Task`, dispatching the result when it lands.
/// Keep that shape.
@MainActor
final class Store<State: Sendable, Action: Sendable>: ObservableObject {
    @Published private(set) var state: State
    private let reducer: Reducer<State, Action>
    private let middlewares: [Middleware<State, Action>]
    private let isDuplicate: ((State, State) -> Bool)?

    /// An action paired with the state its own reducer produced, rather than with whatever the
    /// state happens to be when its middleware finally runs. Middleware sees the world its action
    /// made, which is the only reading that stays the same however long the queue is.
    private typealias Effect = (action: Action, state: State)

    private let enqueue: AsyncStream<Effect>.Continuation
    private var pump: Task<Void, Never>?

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

        // The build closure runs synchronously, so `continuation` is set before it is read. This
        // spelling rather than `AsyncStream.makeStream` because it is available at every
        // deployment target this app supports.
        var continuation: AsyncStream<Effect>.Continuation!
        let effects = AsyncStream<Effect>(bufferingPolicy: .unbounded) { continuation = $0 }
        self.enqueue = continuation

        // Inherits the main actor from this initializer, which is what lets it call `@MainActor`
        // middleware directly. Held rather than discarded so the store owns it, but nothing has
        // to cancel it: the continuation is a stored property here, so releasing the store
        // finishes the stream and the loop falls out on its own.
        self.pump = Task { [weak self] in
            for await effect in effects {
                guard let self else { return }
                await self.runMiddlewares(for: effect)
            }
        }
    }

    // MARK: - Public Interface

    func send(_ action: Action) {
        let newState = reducer(state, action)
        // Skip the @Published write for no-op actions — otherwise every
        // dispatch invalidates all observing views even when nothing changed.
        if isDuplicate?(state, newState) != true {
            state = newState
        }

        enqueue.yield((action: action, state: state))
    }

    // MARK: - Private Implementation

    private func runMiddlewares(for effect: Effect) async {
        for middleware in middlewares {
            let followUps = await middleware(effect.state, effect.action) { [weak self] asyncAction in
                self?.send(asyncAction)
            }

            for action in followUps {
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
