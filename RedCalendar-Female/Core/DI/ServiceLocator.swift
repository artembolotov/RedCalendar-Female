//
//  ServiceLocator.swift
//  RedCalendar-Female
//
//  Created by Артём Болотов on 04.06.2025.
//

import Foundation

/// Registration happens once, from `Configurator.setup()` at launch; resolution happens from
/// anywhere, on any thread.
///
/// Middleware is main-actor isolated now, so the everyday reads have converged on one thread —
/// but the lock is not there because of where middleware runs. It is there because registration
/// and resolution are not otherwise ordered by anything except the call order at launch, and a
/// single service registered later would put a dictionary write next to concurrent reads.
/// A `Dictionary` torn that way corrupts the heap exactly like the observation tokens in
/// `DatabaseMiddleware` did. The lock makes safety a property of the type rather than of the
/// sequence in which it happens to be called; that argument does not move when the callers do.
///
/// The key is the **static** type the service is registered and resolved under, which is why
/// `Configurator` registers everything as its protocol type. `ObjectIdentifier` rather than a
/// type name: it cannot collide across modules, and it costs nothing to compute, which matters
/// now that `@Injected` resolves on every read instead of caching.
final class ServiceLocator: @unchecked Sendable {
    static let shared = ServiceLocator()

    private let lock = NSLock()
    private var services = [ObjectIdentifier: Any]()

    private init() {}

    func addService<T>(service: T) {
        lock.lock()
        defer { lock.unlock() }
        services[ObjectIdentifier(T.self)] = service
    }

    func getService<T>() -> T {
        lock.lock()
        defer { lock.unlock() }
        guard let service = services[ObjectIdentifier(T.self)] as? T else {
            fatalError("Service of type \(T.self) is not registered!")
        }
        return service
    }
}
