//
//  Injected.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

/// Resolves on every read and stores nothing.
///
/// It used to cache the service in a `lazy var` behind a `mutating get`, which made *reading* an
/// injected property a write to it. That is harmless for the locals declared inside middleware
/// closures — a fresh wrapper per invocation, shared with nobody — but as a stored property on a
/// shared object it is a data race waiting for a second thread: two concurrent reads write the
/// same existential and lose a reference count, and the process dies in the allocator some time
/// later. `DatabaseMiddleware` held its service exactly that way.
///
/// Resolution stays lazy, and has to: the store is constructed before `Configurator.setup()`
/// runs, so nothing may resolve a service at construction time. It is now lazy *per read* rather
/// than cached behind mutable state, which costs one dictionary lookup and buys the property back
/// its ordinary meaning — reading it reads.
/// **Carries no isolation attribute of its own, and cannot.** Almost every use of this wrapper is a
/// local variable declared inside a middleware closure, and a local variable inherits the isolation
/// of the wrapper it is declared with — so a `nonisolated` anywhere on this type, on `init` or on
/// `wrappedValue`, reaches those locals as `nonisolated` on a local variable, which is an error.
///
/// It therefore takes the module's main-actor default, which is where every `@Injected` in the app
/// is read from: the middlewares and `DatabaseMiddleware`. Nonisolated code resolves through
/// `ServiceLocator.shared.getService()` instead — the container is nonisolated, so it is the same
/// lookup without the wrapper. `AppLogger` is the one place that needs it.
@propertyWrapper
struct Injected<Service: Sendable> {
    init() {}

    var wrappedValue: Service {
        ServiceLocator.shared.getService()
    }
}
