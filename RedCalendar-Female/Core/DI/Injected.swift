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
/// shared object it was a data race waiting for a second thread: two concurrent reads write the
/// same existential and lose a reference count, and the process dies in the allocator some time
/// later. `DatabaseMiddleware` held its service exactly that way, back when middleware bodies ran
/// on the cooperative pool. They no longer do, and a computed read is still the right shape: a
/// property whose getter mutates is a trap regardless of who is currently allowed to call it.
///
/// Resolution stays lazy, and has to: the store is constructed before `Configurator.setup()`
/// runs, so nothing may resolve a service at construction time. It is now lazy *per read* rather
/// than cached behind mutable state, which costs one dictionary lookup and buys the property back
/// its ordinary meaning — reading it reads.
@propertyWrapper
struct Injected<Service> {
    init() {}

    var wrappedValue: Service {
        ServiceLocator.shared.getService()
    }
}
