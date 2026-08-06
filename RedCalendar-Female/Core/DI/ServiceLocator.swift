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
///
/// `addService` takes that type as an explicit `T.Type` argument rather than inferring `T` from
/// `service`'s own type. It used to infer it — `let x: SomeProtocol = Concrete(); addService(service:
/// x)` relied on `T` binding to `x`'s declared type, `SomeProtocol` — and that inference is not
/// stable across language modes: passing an existential-typed value to an unconstrained generic
/// parameter is exactly where the compiler is free to open the existential and bind `T` to the
/// concrete type underneath instead, which is what Swift 6 mode did to every registration in
/// `Configurator` at once. Registration and `@Injected`'s lookup keyed on different types after
/// that, and resolving anything was the fatalError below, on first launch. Making the type an
/// explicit argument removes the inference — and with it the language-mode dependency — entirely.
/// `getService`'s `T` has no such hazard: it is inferred from the *expected return type* at the
/// call site (`@Injected`'s `wrappedValue` getter, itself typed by the property's declared type),
/// which is ordinary contextual inference, not existential opening, and stayed correct under both
/// modes when this was diagnosed.
final class ServiceLocator: @unchecked Sendable {
    static let shared = ServiceLocator()

    private let lock = NSLock()
    private var services = [ObjectIdentifier: Any]()

    private init() {}

    func addService<T>(_ type: T.Type, service: T) {
        lock.lock()
        defer { lock.unlock() }
        services[ObjectIdentifier(type)] = service
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
