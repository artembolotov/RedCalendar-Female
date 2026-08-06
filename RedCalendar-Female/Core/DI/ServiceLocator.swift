//
//  ServiceLocator.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

/// Registration happens once, from `Configurator.setup()` at launch; resolution happens from
/// anywhere, at any isolation — the nonisolated services resolve each other off the main actor.
///
/// Those two have never overlapped in practice, which is how an unsynchronised dictionary
/// survived here. But that was a property of the call order rather than of this type: a single
/// service registered after launch would put a dictionary write next to concurrent reads, and a
/// `Dictionary` torn that way corrupts the heap exactly like the observation tokens in
/// `DatabaseMiddleware` did. The lock makes it a property of the type instead.
///
/// The key is the **static** type the service is registered and resolved under, which is why
/// `Configurator` registers everything as its protocol type. `ObjectIdentifier` rather than a
/// type name: it cannot collide across modules, and it costs nothing to compute, which matters
/// now that `@Injected` resolves on every read instead of caching.
///
/// It stays a lock rather than becoming an actor, and that is a decision rather than an omission.
/// An actor would make `getService` `async`, and `@Injected.wrappedValue` is a plain computed
/// property read from wherever a service is needed — every one of those call sites would grow an
/// `await` to buy back a guarantee `NSLock` already gives. (`Synchronization.Mutex` would be the
/// modern spelling of the same thing, but it needs iOS 18 and this app ships to 15.4.)
///
/// `nonisolated` because the module is main-actor by default and this must not be: registration
/// happens on the launch path and resolution happens from the nonisolated services. `T: Sendable`
/// is what makes `@unchecked Sendable` honest — the container hands values across isolation
/// boundaries, so it may only ever hold values that can be.
nonisolated final class ServiceLocator: @unchecked Sendable {
    static let shared = ServiceLocator()

    private let lock = NSLock()
    private var services = [ObjectIdentifier: any Sendable]()

    private init() {}

    func addService<T: Sendable>(service: T) {
        lock.lock()
        defer { lock.unlock() }
        services[ObjectIdentifier(T.self)] = service
    }

    func getService<T: Sendable>() -> T {
        lock.lock()
        defer { lock.unlock() }
        guard let service = services[ObjectIdentifier(T.self)] as? T else {
            fatalError("Service of type \(T.self) is not registered!")
        }
        return service
    }
}
